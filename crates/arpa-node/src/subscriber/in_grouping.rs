use super::{DebuggableEvent, DebuggableSubscriber, Subscriber};
use crate::{
    algorithm::dkg::{AllPhasesDKGCore, DKGCore},
    context::ChainIdentityHandlerType,
    error::NodeResult,
    event::{run_dkg::RunDKG, types::Topic},
    queue::{event_queue::EventQueue, EventSubscriber},
    scheduler::{dynamic::SimpleDynamicTaskScheduler, DynamicTaskScheduler},
};
use arpa_contract_client::{controller::ControllerTransactions, error::ContractClientError};
use arpa_core::{
    log::{build_group_related_payload, build_group_related_transaction_receipt_payload, LogType},
    DKGStatus, DKGTask,
};
use arpa_dal::{GroupInfoHandler, NodeInfoHandler};
use async_trait::async_trait;
use core::fmt::Debug;
use ethers::types::U256;
use log::{debug, error, info};
use rand::{prelude::ThreadRng, RngCore};
use std::{marker::PhantomData, sync::Arc};
use threshold_bls::group::Curve;
use tokio::sync::RwLock;

#[derive(Debug)]
pub struct InGroupingSubscriber<PC: Curve> {
    chain_identity: Arc<RwLock<ChainIdentityHandlerType<PC>>>,
    node_cache: Arc<RwLock<Box<dyn NodeInfoHandler<PC>>>>,
    group_cache: Arc<RwLock<Box<dyn GroupInfoHandler<PC>>>>,
    eq: Arc<RwLock<EventQueue>>,
    ts: Arc<RwLock<SimpleDynamicTaskScheduler>>,
    c: PhantomData<PC>,
    dkg_wait_for_phase_interval_millis: u64,
}

impl<PC: Curve> InGroupingSubscriber<PC> {
    pub fn new(
        chain_identity: Arc<RwLock<ChainIdentityHandlerType<PC>>>,
        node_cache: Arc<RwLock<Box<dyn NodeInfoHandler<PC>>>>,
        group_cache: Arc<RwLock<Box<dyn GroupInfoHandler<PC>>>>,
        eq: Arc<RwLock<EventQueue>>,
        ts: Arc<RwLock<SimpleDynamicTaskScheduler>>,
        dkg_wait_for_phase_interval_millis: u64,
    ) -> Self {
        InGroupingSubscriber {
            chain_identity,
            node_cache,
            group_cache,
            eq,
            ts,
            c: PhantomData,
            dkg_wait_for_phase_interval_millis,
        }
    }
}

pub struct AllInOneDKGHandler<F: Fn() -> R, R: RngCore, PC: Curve> {
    rng: F,
    chain_identity: Arc<RwLock<ChainIdentityHandlerType<PC>>>,
    node_cache: Arc<RwLock<Box<dyn NodeInfoHandler<PC>>>>,
    group_cache: Arc<RwLock<Box<dyn GroupInfoHandler<PC>>>>,
    c: PhantomData<PC>,
    dkg_wait_for_phase_interval_millis: u64,
}

impl<F: Fn() -> R, R: RngCore, PC: Curve> AllInOneDKGHandler<F, R, PC> {
    pub fn new(
        rng: F,
        chain_identity: Arc<RwLock<ChainIdentityHandlerType<PC>>>,
        node_cache: Arc<RwLock<Box<dyn NodeInfoHandler<PC>>>>,
        group_cache: Arc<RwLock<Box<dyn GroupInfoHandler<PC>>>>,
        dkg_wait_for_phase_interval_millis: u64,
    ) -> Self {
        AllInOneDKGHandler {
            rng,
            chain_identity,
            node_cache,
            group_cache,
            c: PhantomData,
            dkg_wait_for_phase_interval_millis,
        }
    }
}

#[async_trait]
pub trait DKGHandler<F, R> {
    async fn handle(&mut self, task: DKGTask) -> NodeResult<()>
    where
        R: RngCore,
        F: Fn() -> R + 'static;
}

#[async_trait]
impl<
        F: Fn() -> R + Debug + Send + Sync + Copy + 'static,
        R: RngCore + 'static,
        PC: Curve + Sync + Send + 'static,
    > DKGHandler<F, R> for AllInOneDKGHandler<F, R, PC>
{
    async fn handle(&mut self, task: DKGTask) -> NodeResult<()>
    where
        R: RngCore,
        F: Fn() -> R + Send + Debug + 'async_trait,
    {
        let node_rpc_endpoint = self
            .node_cache
            .read()
            .await
            .get_node_rpc_endpoint()?
            .to_string();

        let chain_id = self.chain_identity.read().await.get_chain_id();

        let controller_client = self.chain_identity.read().await.build_controller_client();

        let dkg_private_key = self.node_cache.read().await.get_dkg_private_key()?.clone();

        let task_group_index = task.group_index;

        let task_epoch = task.epoch;

        let coordinator_client = self
            .chain_identity
            .read()
            .await
            .build_coordinator_client(task.coordinator_address);

        let mut dkg_core =
            AllPhasesDKGCore::new(coordinator_client, self.dkg_wait_for_phase_interval_millis);

        match dkg_core
            .run_dkg(dkg_private_key, node_rpc_endpoint, self.rng)
            .await
        {
            Ok(output) => match output.disqualified_node_indices.len() {
                0 => {
                    let (public_key, partial_public_key, disqualified_nodes) = self
                        .group_cache
                        .write()
                        .await
                        .save_successful_output(task_group_index, task_epoch, output)
                        .await?;

                    info!(
                        "{}",
                        build_group_related_payload(
                            LogType::DKGGroupingFinished,
                            "DKG grouping finished.",
                            chain_id,
                            self.group_cache.read().await.get_group()?
                        )
                    );

                    match controller_client
                        .commit_dkg(
                            task_group_index,
                            task_epoch,
                            bincode::serialize(&public_key).unwrap(),
                            bincode::serialize(&partial_public_key).unwrap(),
                            disqualified_nodes,
                        )
                        .await
                    {
                        Ok(receipt) => {
                            info!(
                                "{}",
                                build_group_related_transaction_receipt_payload(
                                    LogType::DKGGroupingCommitted,
                                    "DKG grouping result committed.",
                                    chain_id,
                                    self.group_cache.read().await.get_group()?,
                                    None,
                                    receipt.transaction_hash,
                                    receipt.gas_used.unwrap_or(U256::zero()),
                                    receipt.effective_gas_price.unwrap_or(U256::zero())
                                )
                            );
                        }
                        Err(e) => match e {
                            ContractClientError::TransactionFailed(receipt) => {
                                error!(
                                    "{}",
                                    build_group_related_transaction_receipt_payload(
                                        LogType::DKGGroupingCommitFailed,
                                        "DKG grouping commit failed.",
                                        chain_id,
                                        self.group_cache.read().await.get_group()?,
                                        None,
                                        receipt.transaction_hash,
                                        receipt.gas_used.unwrap_or(U256::zero()),
                                        receipt.effective_gas_price.unwrap_or(U256::zero())
                                    )
                                );
                            }
                            _ => {
                                error!(
                                    "{}",
                                    build_group_related_payload(
                                        LogType::DKGGroupingCommitFailed,
                                        &format!("DKG grouping commit failed with error: {:?}", e),
                                        chain_id,
                                        self.group_cache.read().await.get_group()?
                                    )
                                );
                            }
                        },
                    }
                }
                _ => {
                    info!(
                        "Disqualified node indices: {:?}",
                        output.disqualified_node_indices
                    );

                    let disqualified_nodes = self
                        .group_cache
                        .write()
                        .await
                        .save_failed_output(
                            task_group_index,
                            task_epoch,
                            output.disqualified_node_indices,
                        )
                        .await?;

                    info!("Disqualified node addresses: {:?}", disqualified_nodes);

                    info!(
                        "{}",
                        build_group_related_payload(
                            LogType::DKGGroupingAborted,
                            "DKG grouping aborted due to disqualified nodes.",
                            chain_id,
                            self.group_cache.read().await.get_group()?
                        )
                    );

                    let g_public_key = PC::point();
                    let g_partial_public_key = PC::point();

                    match controller_client
                        .commit_dkg(
                            task_group_index,
                            task_epoch,
                            bincode::serialize(&g_public_key).unwrap(),
                            bincode::serialize(&g_partial_public_key).unwrap(),
                            disqualified_nodes,
                        )
                        .await
                    {
                        Ok(receipt) => {
                            info!(
                                "{}",
                                build_group_related_transaction_receipt_payload(
                                    LogType::DKGGroupingCommitted,
                                    "DKG grouping result committed.",
                                    chain_id,
                                    self.group_cache.read().await.get_group()?,
                                    None,
                                    receipt.transaction_hash,
                                    receipt.gas_used.unwrap_or(U256::zero()),
                                    receipt.effective_gas_price.unwrap_or(U256::zero())
                                )
                            );
                        }
                        Err(e) => match e {
                            ContractClientError::TransactionFailed(receipt) => {
                                error!(
                                    "{}",
                                    build_group_related_transaction_receipt_payload(
                                        LogType::DKGGroupingCommitFailed,
                                        "DKG grouping commit failed.",
                                        chain_id,
                                        self.group_cache.read().await.get_group()?,
                                        None,
                                        receipt.transaction_hash,
                                        receipt.gas_used.unwrap_or(U256::zero()),
                                        receipt.effective_gas_price.unwrap_or(U256::zero())
                                    )
                                );
                            }
                            _ => {
                                error!(
                                    "{}",
                                    build_group_related_payload(
                                        LogType::DKGGroupingCommitFailed,
                                        &format!("DKG grouping commit failed with error: {:?}", e),
                                        chain_id,
                                        self.group_cache.read().await.get_group()?
                                    )
                                );
                            }
                        },
                    }
                }
            },
            Err(e) => {
                error!(
                    "{}",
                    build_group_related_payload(
                        LogType::DKGGroupingFailed,
                        &format!("DKG grouping failed with error: {:?}", e),
                        chain_id,
                        self.group_cache.read().await.get_group()?
                    )
                );
            }
        }

        Ok(())
    }
}

#[async_trait]
impl<PC: Curve + std::fmt::Debug + Sync + Send + 'static> Subscriber for InGroupingSubscriber<PC> {
    async fn notify(&self, topic: Topic, payload: &(dyn DebuggableEvent)) -> NodeResult<()> {
        debug!("{:?}", topic);

        let RunDKG { dkg_task: task, .. } =
            payload.as_any().downcast_ref::<RunDKG>().unwrap().clone();

        static RNG_FN: fn() -> ThreadRng = rand::thread_rng;

        let chain_identity = self.chain_identity.clone();

        let group_cache_for_handler = self.group_cache.clone();

        let group_cache_for_handler_shutdown_signal = self.group_cache.clone();

        let task_group_index = task.group_index;

        let task_epoch = task.epoch;

        let mut handler = AllInOneDKGHandler::new(
            RNG_FN,
            chain_identity,
            self.node_cache.clone(),
            self.group_cache.clone(),
            self.dkg_wait_for_phase_interval_millis,
        );

        self.ts.write().await.add_task_with_shutdown_signal(
            async move {
                if let Err(e) = handler.handle(task).await {
                    error!("{:?}", e);
                } else if let Err(e) = group_cache_for_handler
                    .write()
                    .await
                    .update_dkg_status(task_group_index, task_epoch, DKGStatus::CommitSuccess)
                    .await
                {
                    error!("{:?}", e);
                }
            },
            move || {
                let group_cache = group_cache_for_handler_shutdown_signal.clone();
                async move {
                    let cache_index = group_cache.clone().read().await.get_index().unwrap_or(0);

                    let cache_epoch = group_cache.clone().read().await.get_epoch().unwrap_or(0);

                    cache_index != task_group_index || cache_epoch != task_epoch
                    //NodeError::GroupIndexObsolete(cache_index)
                    //NodeError::GroupEpochObsolete(cache_epoch)
                }
            },
            2000,
        );

        Ok(())
    }

    async fn subscribe(self) {
        let eq = self.eq.clone();

        let subscriber = Box::new(self);

        eq.write().await.subscribe(Topic::RunDKG, subscriber);
    }
}

impl<PC: Curve + std::fmt::Debug + Sync + Send + 'static> DebuggableSubscriber
    for InGroupingSubscriber<PC>
{
}
