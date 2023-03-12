// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

pragma experimental ABIEncoderV2;

import {Coordinator} from "src/Coordinator.sol";
import {Controller} from "src/Controller.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "src/interfaces/ICoordinator.sol";
import "./MockArpaEthOracle.sol";
import "./RandcastTestHelper.sol";

// Suggested usage: forge test --match-contract Controller -vv

contract DKGScenarioTest is RandcastTestHelper {
    uint256 nodeStakingAmount = 50000;
    uint256 disqualifiedNodePenaltyAmount = 1000;
    uint256 defaultNumberOfCommitters = 3;
    uint256 defaultDkgPhaseDuration = 10;
    uint256 groupMaxCapacity = 10;
    uint256 idealNumberOfGroups = 5;
    uint256 pendingBlockAfterQuit = 100;
    uint256 dkgPostProcessReward = 100;

    address public owner = address(0xC0FF33);

    function setUp() public {
        // deal nodes
        vm.deal(node1, 1 * 10 ** 18);
        vm.deal(node2, 1 * 10 ** 18);
        vm.deal(node3, 1 * 10 ** 18);
        vm.deal(node4, 1 * 10 ** 18);
        vm.deal(node5, 1 * 10 ** 18);

        // deal owner and create controller
        vm.deal(owner, 1 * 10 ** 18);
        vm.prank(owner);

        arpa = new ERC20("arpa token", "ARPA");
        MockArpaEthOracle oracle = new MockArpaEthOracle();
        controller = new Controller(address(arpa), address(oracle));

        controller.setControllerConfig(
            nodeStakingAmount,
            disqualifiedNodePenaltyAmount,
            defaultNumberOfCommitters,
            defaultDkgPhaseDuration,
            groupMaxCapacity,
            idealNumberOfGroups,
            pendingBlockAfterQuit,
            dkgPostProcessReward
        );

        // Register Nodes
        vm.prank(node1);
        controller.nodeRegister(DKGPubkey1);
        vm.prank(node2);
        controller.nodeRegister(DKGPubkey2);
        vm.prank(node3);
        controller.nodeRegister(DKGPubkey3);
        vm.prank(node4);
        controller.nodeRegister(DKGPubkey4);
        vm.prank(node5);
        controller.nodeRegister(DKGPubkey5);
    }

    struct Params {
        address nodeIdAddress;
        uint256 groupIndex;
        uint256 groupEpoch;
        bytes publicKey;
        bytes partialPublicKey;
        address[] disqualifiedNodes;
    }

    function dkgHelper(Params[] memory params) public {
        for (uint256 i = 0; i < params.length; i++) {
            vm.prank(params[i].nodeIdAddress);
            controller.commitDkg(
                Controller.CommitDkgParams(
                    params[i].groupIndex,
                    params[i].groupEpoch,
                    params[i].publicKey,
                    params[i].partialPublicKey,
                    params[i].disqualifiedNodes
                )
            );
        }
    }

    function testDkgScenarios() public {
        // DKG Scenario 1
        Params[] memory params1 = new Params[](5);
        params1[0] = Params(node1, 0, 3, publicKey, partialPublicKey1, new address[](0));
        params1[1] = Params(node2, 0, 3, publicKey, partialPublicKey2, new address[](0));
        params1[2] = Params(node3, 0, 3, publicKey, partialPublicKey3, new address[](0));
        params1[3] = Params(node4, 0, 3, publicKey, partialPublicKey4, new address[](0));
        params1[4] = Params(node5, 0, 3, publicKey, partialPublicKey5, new address[](0));
        dkgHelper(params1);
        printGroupInfo(0);
    }
}
