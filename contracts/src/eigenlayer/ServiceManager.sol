// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {ISignatureUtils, IAVSDirectory} from "../interfaces/IAVSDirectory.sol";
import {IDelegationManager} from "../interfaces/IDelegationManager.sol";
import {IServiceManager} from "../interfaces/IServiceManager.sol";

contract ServiceManager is UUPSUpgradeable, IServiceManager, OwnableUpgradeable {
    // *Constants*

    // *NodeRegistry Config*
    address public nodeRegistryAddress;
    IAVSDirectory public avsDirectory;
    IDelegationManager public delegationManager;
    address[] public strategy;

    // *Node State Variables*

    /// @notice when applied to a function, only allows the RegistryCoordinator to call it
    modifier onlyNodeRegistry() {
        if (msg.sender != nodeRegistryAddress) {
            revert SenderNotNodeRegistry();
        }
        _;
    }

    // *Events*
    event OperatorSlashed(address indexed operator, uint256 stakingPenalty);

    // *Errors*
    error SenderNotNodeRegistry();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _nodeRegistryAddress,
        address _strategyAddress,
        address _avsDirectory,
        address _delegationManager
    ) public initializer {
        nodeRegistryAddress = _nodeRegistryAddress;
        avsDirectory = IAVSDirectory(_avsDirectory);
        delegationManager = IDelegationManager(_delegationManager);
        strategy.push(_strategyAddress);

        __Ownable_init();
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function updateAVSMetadataURI(string memory _metadataURI) public virtual onlyOwner {
        avsDirectory.updateAVSMetadataURI(_metadataURI);
    }

    // =============
    // IEigenlayerCoordinator
    // =============
    function registerOperator(address operator, ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature)
        external
        onlyNodeRegistry
    {
        avsDirectory.registerOperatorToAVS(operator, operatorSignature);
    }

    function deregisterOperator(address operator) external onlyNodeRegistry {
        avsDirectory.deregisterOperatorFromAVS(operator);
    }

    function slashDelegationStaking(address operator, uint256 amount) external onlyNodeRegistry {
        // TODO - implement slashing logic according to the eigenlayer slasher
        emit OperatorSlashed(operator, amount);
    }

    // =============
    // View
    // =============

    function getOperatorShare(address operator) external view returns (uint256) {
        return delegationManager.operatorShares(operator, strategy[0]);
    }

    /**
     * @notice Returns the list of strategies that the AVS supports for restaking
     * @dev This function is intended to be called off-chain
     * @dev No guarantee is made on uniqueness of each element in the returned array.
     *    The off-chain service should do that validation separately
     */
    function getRestakeableStrategies() external view returns (address[] memory) {
        return strategy;
    }

    /**
     * @notice Returns the list of strategies that the operator has potentially restaked on the AVS
     * @param operator The address of the operator to get restaked strategies for
     * @dev This function is intended to be called off-chain
     * @dev No guarantee is made on whether the operator has shares for a strategy in a quorum or uniqueness
     *      of each element in the returned array. The off-chain service should do that validation separately
     */
    function getOperatorRestakedStrategies(address operator) external view returns (address[] memory) {
        address[] memory restakedStrategies = new address[](strategy.length);
        uint256 index = 0;
        for (uint256 i = 0; i < strategy.length; i++) {
            if (IDelegationManager(delegationManager).operatorShares(operator, strategy[i]) > 0) {
                restakedStrategies[index] = strategy[i];
                index++;
            }
        }
        return restakedStrategies;
    }

    // =============
    // Internal
    // =============
}
