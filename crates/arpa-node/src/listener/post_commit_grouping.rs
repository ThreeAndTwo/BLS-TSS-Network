use super::Listener;
use crate::{
    context::ChainIdentityHandlerType,
    error::NodeResult,
    event::dkg_success::DKGSuccess,
    queue::{event_queue::EventQueue, EventPublisher},
};
use arpa_contract_client::controller::ControllerViews;
use arpa_core::DKGStatus;
use arpa_dal::GroupInfoHandler;
use async_trait::async_trait;
use ethers::providers::Middleware;
use std::{marker::PhantomData, sync::Arc};
use threshold_bls::group::Curve;
use tokio::sync::RwLock;

pub struct PostCommitGroupingListener<PC: Curve> {
    chain_identity: Arc<RwLock<ChainIdentityHandlerType<PC>>>,
    group_cache: Arc<RwLock<Box<dyn GroupInfoHandler<PC>>>>,
    eq: Arc<RwLock<EventQueue>>,
    pc: PhantomData<PC>,
}

impl<PC: Curve> std::fmt::Display for PostCommitGroupingListener<PC> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "PostCommitGroupingListener")
    }
}

impl<PC: Curve> PostCommitGroupingListener<PC> {
    pub fn new(
        chain_identity: Arc<RwLock<ChainIdentityHandlerType<PC>>>,
        group_cache: Arc<RwLock<Box<dyn GroupInfoHandler<PC>>>>,
        eq: Arc<RwLock<EventQueue>>,
    ) -> Self {
        PostCommitGroupingListener {
            chain_identity,
            group_cache,
            eq,
            pc: PhantomData,
        }
    }
}

#[async_trait]
impl<PC: Curve + Send + Sync + 'static> EventPublisher<DKGSuccess<PC>>
    for PostCommitGroupingListener<PC>
{
    async fn publish(&self, event: DKGSuccess<PC>) {
        self.eq.read().await.publish(event).await;
    }
}

#[async_trait]
impl<PC: Curve + Sync + Send + 'static> Listener for PostCommitGroupingListener<PC> {
    async fn listen(&self) -> NodeResult<()> {
        let dkg_status = self.group_cache.read().await.get_dkg_status();

        if let Ok(DKGStatus::CommitSuccess) = dkg_status {
            let chain_id = self.chain_id().await;

            let group_index = self.group_cache.read().await.get_index()?;

            let client = self.chain_identity.read().await.build_controller_client();

            let id_address = self.chain_identity.read().await.get_id_address();

            if let Ok(group) = client.get_group(group_index).await {
                if group.state {
                    self.publish(DKGSuccess {
                        chain_id,
                        id_address,
                        group,
                    })
                    .await;
                }
            }
        }

        Ok(())
    }

    async fn handle_interruption(&self) -> NodeResult<()> {
        self.chain_identity
            .read()
            .await
            .get_provider()
            .get_net_version()
            .await?;

        Ok(())
    }

    async fn chain_id(&self) -> usize {
        self.chain_identity.read().await.get_chain_id()
    }
}
