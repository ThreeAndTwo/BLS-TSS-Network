// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {
    RandcastTestHelper,
    INodeRegistry,
    NodeRegistry,
    ServiceManager,
    INodeRegistryOwner
} from "./RandcastTestHelper.sol";
import {IServiceManager} from "../src/interfaces/IServiceManager.sol";
import {INodeStaking} from "Staking-v0.1/interfaces/INodeStaking.sol";
import {BLS} from "../src/libraries/BLS.sol";

contract NodeRegistryTest is RandcastTestHelper {
    address[] internal _tempAddresses;

    event NodeQuit(address indexed nodeAddress);
    event DkgPublicKeyChanged(address indexed nodeAddress, bytes dkgPublicKey);
    event NodeRewarded(address indexed nodeAddress, uint256 ethAmount, uint256 arpaAmount);
    event NodeSlashed(address indexed nodeIdAddress, uint256 stakingRewardPenalty, uint256 pendingBlock);

    function setUp() public {
        _prepareRandcastContracts();
        _tempAddresses = new address[](1);
        _tempAddresses[0] = _node2;
    }

    function testNodeRegister() public {
        // Fail on bad dkg public key
        vm.expectRevert(abi.encodeWithSelector(BLS.InvalidPublicKey.selector));
        vm.prank(_node1);
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_badKey, false, _node1, _emptyOperatorSignature);

        // Register _node1
        vm.prank(_node1);
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_dkgPubkey1, false, _node1, _emptyOperatorSignature);

        // Assert _node1 state is correct
        INodeRegistry.Node memory n = INodeRegistry(address(_nodeRegistry)).getNode(_node1);
        assertEq(n.idAddress, _node1);
        assertEq(n.dkgPublicKey, _dkgPubkey1);
        assertEq(n.state, true);
        assertEq(n.pendingUntilBlock, 0);

        // fail on already registered node
        vm.expectRevert(abi.encodeWithSelector(NodeRegistry.NodeAlreadyRegistered.selector));
        vm.prank(_node1);
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_dkgPubkey1, false, _node1, _emptyOperatorSignature);

        // If is EigenLayer node, and share amount insufficient, error and revert
        vm.prank(_node3);
        vm.expectRevert(abi.encodeWithSelector(NodeRegistry.OperatorUnderStaking.selector));
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_dkgPubkey1, true, _node3, _emptyOperatorSignature);

        // If is EigenLayer node, and share amount sufficient
        _tempAddresses[0] = _node3;
        vm.prank(_admin);
        ServiceManager(address(_serviceManager)).addToWhitelist(_tempAddresses);
        assertTrue(ServiceManager(address(_serviceManager)).whitelist(_node3));

        vm.prank(_admin);
        uint256[] memory tempWeights = new uint256[](1);
        tempWeights[0] = 100;
        ServiceManager(address(_serviceManager)).setStrategyAndWeights(_tempAddresses, tempWeights);

        vm.prank(_node3);
        vm.expectCall(
            address(_serviceManager),
            abi.encodeWithSelector(IServiceManager.registerOperator.selector, _node3, _emptyOperatorSignature)
        );
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_dkgPubkey1, true, _node3, _emptyOperatorSignature);

        // If not Eigenlayer node, call lock of NodeStaking
        vm.prank(_node4);
        vm.expectCall(address(_staking), abi.encodeWithSelector(INodeStaking.lock.selector, _node4, 500_00 * 1e18));
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_dkgPubkey4, false, _node4, _emptyOperatorSignature);
    }

    function testNodeActivate() public {
        // When call nodeActivate,
        // If not registered (_nodes doesn't contain record), error and revert
        vm.prank(_node1);
        vm.expectRevert(abi.encodeWithSelector(NodeRegistry.NodeNotRegistered.selector));
        INodeRegistry(address(_nodeRegistry)).nodeActivate(_emptyOperatorSignature);

        // Register a node
        vm.prank(_node1);
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_dkgPubkey1, false, _node1, _emptyOperatorSignature);

        // If already activated (node.state), error and revert
        vm.prank(_node1);
        vm.expectRevert(abi.encodeWithSelector(NodeRegistry.NodeAlreadyActive.selector));
        INodeRegistry(address(_nodeRegistry)).nodeActivate(_emptyOperatorSignature);

        // If still pending (node.pendingUntilBlock larger than block number), error and revert
        vm.roll(block.number + _pendingBlockAfterQuit + 1);
        vm.prank(_node1);
        INodeRegistry(address(_nodeRegistry)).nodeQuit();
        vm.prank(_node1);
        vm.expectRevert(
            abi.encodeWithSelector(NodeRegistry.NodeStillPending.selector, block.number + _pendingBlockAfterQuit)
        );
        INodeRegistry(address(_nodeRegistry)).nodeActivate(_emptyOperatorSignature);

        // If is EigenLayer node, and share amount insufficient, error and revert
        vm.prank(_node2);
        vm.expectRevert(abi.encodeWithSelector(NodeRegistry.OperatorUnderStaking.selector));
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_dkgPubkey2, true, _node2, _emptyOperatorSignature);
    }

    function testDismissNodeAndNodeQuit() public {
        // Register a node
        vm.prank(_node1);
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_dkgPubkey1, false, _node1, _emptyOperatorSignature);

        // When call nodeQuit,
        // If not registered (_nodes address doesn't match), error and revert
        vm.prank(_admin);
        vm.expectRevert(abi.encodeWithSelector(NodeRegistry.NodeNotRegistered.selector));
        INodeRegistry(address(_nodeRegistry)).nodeQuit();

        vm.prank(_node2);
        vm.expectRevert(abi.encodeWithSelector(NodeRegistry.NodeNotRegistered.selector));
        INodeRegistry(address(_nodeRegistry)).nodeQuit();

        // Expect to emit event NodeQuit
        vm.prank(_node1);
        vm.expectEmit(true, true, false, true);
        emit NodeQuit(_node1);
        INodeRegistry(address(_nodeRegistry)).nodeQuit();
    }

    function testChangeDkgPublicKey() public {
        // Register a node
        vm.prank(_node1);
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_dkgPubkey1, false, _node1, _emptyOperatorSignature);

        // When not registered (_nodes address doesn't match), error and revert
        vm.prank(_node2);
        vm.expectRevert(NodeRegistry.NodeNotRegistered.selector);
        INodeRegistry(address(_nodeRegistry)).changeDkgPublicKey(_dkgPubkey2);

        // When already activated (node.state), error and reverts
        vm.prank(_node1);
        vm.expectRevert(NodeRegistry.NodeAlreadyActive.selector);
        INodeRegistry(address(_nodeRegistry)).changeDkgPublicKey(_dkgPubkey2);

        // When already activated (node.state), quit first then we can change DkgKey
        vm.prank(_node1);
        INodeRegistry(address(_nodeRegistry)).nodeQuit();
        vm.prank(_node1);
        INodeRegistry(address(_nodeRegistry)).changeDkgPublicKey(_dkgPubkey2);
    }

    function testNodeWithdraw() public {
        // Register a node
        vm.prank(_node1);
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_dkgPubkey1, false, _node1, _emptyOperatorSignature);

        // When call nodeWithdraw, if address is zero, error and revert
        vm.prank(_node1);
        vm.expectRevert(NodeRegistry.InvalidZeroAddress.selector);
        INodeRegistry(address(_nodeRegistry)).nodeWithdraw(address(0));
    }

    function testAddReward() public {
        // Register some nodes
        vm.prank(_node1);
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_dkgPubkey1, false, _node1, _emptyOperatorSignature);
        vm.prank(_node2);
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_dkgPubkey2, false, _node2, _emptyOperatorSignature);

        // When call addReward,
        // If sender not controller address, error and revert
        uint256 ethAmount = 100;
        uint256 arpaAmount = 50;
        address[] memory nodes = new address[](2);
        nodes[0] = _node1;
        nodes[1] = _node2;

        vm.prank(_node1);
        vm.expectRevert(NodeRegistry.SenderNotController.selector);
        INodeRegistry(address(_nodeRegistry)).addReward(nodes, ethAmount, arpaAmount);

        // Expect to update node values (_withdrawableEths and _arpaRewards) and emit NodeRewarded event for each node
        vm.prank(address(_controller));
        vm.expectEmit(true, true, false, true);
        emit NodeRewarded(_node1, ethAmount, arpaAmount);
        vm.expectEmit(true, true, false, true);
        emit NodeRewarded(_node2, ethAmount, arpaAmount);
        INodeRegistry(address(_nodeRegistry)).addReward(nodes, ethAmount, arpaAmount);

        (uint256 node1EthAmount, uint256 node1ArpaAmount) =
            INodeRegistry(address(_nodeRegistry)).getNodeWithdrawableTokens(_node1);
        (uint256 node2EthAmount, uint256 node2ArpaAmount) =
            INodeRegistry(address(_nodeRegistry)).getNodeWithdrawableTokens(_node2);

        assertEq(node1EthAmount, ethAmount);
        assertEq(node1ArpaAmount, arpaAmount);
        assertEq(node2EthAmount, ethAmount);
        assertEq(node2ArpaAmount, arpaAmount);
    }

    function testRegistrySlashNode() public {
        // Register a node
        vm.prank(_node1);
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_dkgPubkey1, false, _node1, _emptyOperatorSignature);

        // When sender is not the controller address, error and revert
        vm.prank(_node2);
        vm.expectRevert(NodeRegistry.SenderNotController.selector);
        INodeRegistry(address(_nodeRegistry)).slashNode(_node1, 100, 10);

        uint256 stakingRewardPenalty = 100;
        uint256 pendingBlock = 10;

        // If is not EigenLayer node, call slashDelegationReward of NodeStaking
        vm.prank(address(_controller));
        vm.expectCall(
            address(_staking),
            abi.encodeWithSelector(INodeStaking.slashDelegationReward.selector, _node1, stakingRewardPenalty)
        );

        // Expect to emit NodeSlashed event
        vm.expectEmit(true, true, true, true);
        emit NodeSlashed(_node1, stakingRewardPenalty, pendingBlock);
        INodeRegistry(address(_nodeRegistry)).slashNode(_node1, stakingRewardPenalty, pendingBlock);

        // Update state to false and pendingUntilBlock
        INodeRegistry.Node memory node = INodeRegistry(address(_nodeRegistry)).getNode(_node1);
        assertFalse(node.state);
        assertEq(node.pendingUntilBlock, block.number + pendingBlock);
    }

    function testSetNodeRegistryConfig() public {
        // Get the initial node registry configuration
        (
            address initialControllerContractAddress,
            address initialStakingContractAddress,
            address initialServiceManagerContractAddress,
            uint256 initialNativeNodeStakingAmount,
            uint256 initialEigenlayerNodeStakingAmount,
            uint256 initialPendingBlockAfterQuit
        ) = INodeRegistry(address(_nodeRegistry)).getNodeRegistryConfig();

        // Verify the initial configuration
        assertEq(initialControllerContractAddress, address(_controller));
        assertEq(initialStakingContractAddress, address(_staking));
        assertEq(initialServiceManagerContractAddress, address(_serviceManager));
        assertEq(initialNativeNodeStakingAmount, _operatorStakeAmount);
        assertEq(initialEigenlayerNodeStakingAmount, _eigenlayerOperatorStakeAmount);
        assertEq(initialPendingBlockAfterQuit, _pendingBlockAfterQuit);

        // Update the node registry configuration
        address newControllerContractAddress = address(0x1234);
        address newStakingContractAddress = address(0x5678);
        address newServiceManagerContractAddress = address(0x9012);
        uint256 newNativeNodeStakingAmount = 1000;
        uint256 newEigenlayerNodeStakingAmount = 2000;
        uint256 newPendingBlockAfterQuit = 200;

        vm.prank(_admin);
        INodeRegistryOwner(address(_nodeRegistry)).setNodeRegistryConfig(
            newControllerContractAddress,
            newStakingContractAddress,
            newServiceManagerContractAddress,
            newNativeNodeStakingAmount,
            newEigenlayerNodeStakingAmount,
            newPendingBlockAfterQuit
        );

        // Verify the updated configuration
        (
            address updatedControllerContractAddress,
            address updatedStakingContractAddress,
            address updatedServiceManagerContractAddress,
            uint256 updatedNativeNodeStakingAmount,
            uint256 updatedEigenlayerNodeStakingAmount,
            uint256 updatedPendingBlockAfterQuit
        ) = INodeRegistry(address(_nodeRegistry)).getNodeRegistryConfig();

        assertEq(updatedControllerContractAddress, newControllerContractAddress);
        assertEq(updatedStakingContractAddress, newStakingContractAddress);
        assertEq(updatedServiceManagerContractAddress, newServiceManagerContractAddress);
        assertEq(updatedNativeNodeStakingAmount, newNativeNodeStakingAmount);
        assertEq(updatedEigenlayerNodeStakingAmount, newEigenlayerNodeStakingAmount);
        assertEq(updatedPendingBlockAfterQuit, newPendingBlockAfterQuit);
    }
}
