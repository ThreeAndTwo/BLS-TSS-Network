// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

pragma experimental ABIEncoderV2;

import {
    Strings,
    RandcastTestHelper,
    ERC20,
    ControllerForTest,
    IController,
    IControllerOwner,
    NodeRegistry,
    INodeRegistry,
    INodeRegistryOwner,
    ServiceManager,
    ERC1967Proxy
} from "./RandcastTestHelper.sol";
import {ControllerOracle, IControllerOracle} from "../src/ControllerOracle.sol";
import {IControllerForTest} from "./IControllerForTest.sol";
import {MockL2CrossDomainMessenger} from "./MockL2CrossDomainMessenger.sol";

contract ControllerOracleTest is RandcastTestHelper {
    function setUp() public {
        // deal nodes
        vm.deal(_node1, 1 * 10 ** 18);
        vm.deal(_node2, 1 * 10 ** 18);
        vm.deal(_node3, 1 * 10 ** 18);
        vm.deal(_node4, 1 * 10 ** 18);
        vm.deal(_node5, 1 * 10 ** 18);
        vm.deal(_node6, 1 * 10 ** 18);
        vm.deal(_node7, 1 * 10 ** 18);
        vm.deal(_node8, 1 * 10 ** 18);
        vm.deal(_node9, 1 * 10 ** 18);
        vm.deal(_node10, 1 * 10 ** 18);

        // deal _admin and create _controller
        vm.deal(_admin, 1 * 10 ** 18);

        vm.prank(_admin);
        _arpa = new ERC20("arpa token", "ARPA");

        address[] memory operators = new address[](10);
        operators[0] = _node1;
        operators[1] = _node2;
        operators[2] = _node3;
        operators[3] = _node4;
        operators[4] = _node5;
        operators[5] = _node6;
        operators[6] = _node7;
        operators[7] = _node8;
        operators[8] = _node9;
        operators[9] = _node10;
        _prepareStakingContract(_stakingDeployer, address(_arpa), operators);

        vm.prank(_admin);
        _controllerImpl = new ControllerForTest();

        vm.prank(_admin);
        _controller =
            new ERC1967Proxy(address(_controllerImpl), abi.encodeWithSignature("initialize(uint256)", _lastOutput));

        vm.prank(_admin);
        _nodeRegistryImpl = new NodeRegistry();

        vm.prank(_admin);
        _nodeRegistry =
            new ERC1967Proxy(address(_nodeRegistryImpl), abi.encodeWithSignature("initialize(address)", address(_arpa)));

        vm.prank(_admin);
        _serviceManagerImpl = new ServiceManager();

        vm.prank(_admin);
        _serviceManager = new ERC1967Proxy(
            address(_serviceManagerImpl),
            abi.encodeWithSignature(
                "initialize(address,address,address)", address(_nodeRegistry), address(0), address(0)
            )
        );

        vm.prank(_admin);
        INodeRegistryOwner(address(_nodeRegistry)).setNodeRegistryConfig(
            address(_controller),
            address(_staking),
            address(_serviceManager),
            _operatorStakeAmount,
            _eigenlayerOperatorStakeAmount,
            _pendingBlockAfterQuit
        );

        vm.prank(_admin);
        IControllerOwner(address(_controller)).setControllerConfig(
            address(_nodeRegistry),
            address(0),
            _disqualifiedNodePenaltyAmount,
            _defaultNumberOfCommitters,
            _defaultDkgPhaseDuration,
            _groupMaxCapacity,
            _idealNumberOfGroups,
            _dkgPostProcessReward
        );

        vm.prank(_stakingDeployer);
        _staking.setController(address(_nodeRegistry));

        // Register Nodes to max capacity of one group
        vm.prank(_node1);
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_dkgPubkey1, false, _node1, _emptyOperatorSignature);
        vm.prank(_node2);
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_dkgPubkey2, false, _node2, _emptyOperatorSignature);
        vm.prank(_node3);
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_dkgPubkey3, false, _node3, _emptyOperatorSignature);
        vm.prank(_node4);
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_dkgPubkey4, false, _node4, _emptyOperatorSignature);
        vm.prank(_node5);
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_dkgPubkey5, false, _node5, _emptyOperatorSignature);
        vm.prank(_node6);
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_dkgPubkey6, false, _node6, _emptyOperatorSignature);
        vm.prank(_node7);
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_dkgPubkey7, false, _node7, _emptyOperatorSignature);
        vm.prank(_node8);
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_dkgPubkey8, false, _node8, _emptyOperatorSignature);
        vm.prank(_node9);
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_dkgPubkey9, false, _node9, _emptyOperatorSignature);
        vm.prank(_node10);
        INodeRegistry(address(_nodeRegistry)).nodeRegister(_dkgPubkey10, false, _node10, _emptyOperatorSignature);
    }

    struct Params {
        address nodeIdAddress;
        bool shouldRevert;
        bytes revertMessage;
        uint256 groupIndex;
        uint256 groupEpoch;
        bytes _publicKey;
        bytes partialPublicKey;
        address[] disqualifiedNodes;
    }

    function dkgHelper(Params[] memory params) public {
        for (uint256 i = 0; i < params.length; i++) {
            vm.prank(params[i].nodeIdAddress);
            if (params[i].shouldRevert) {
                vm.expectRevert(params[i].revertMessage);
            }
            IControllerForTest(address(_controller)).commitDkg(
                IController.CommitDkgParams(
                    params[i].groupIndex,
                    params[i].groupEpoch,
                    params[i]._publicKey,
                    params[i].partialPublicKey,
                    params[i].disqualifiedNodes
                )
            );
        }
    }

    event GroupUpdated(
        uint256 epoch, uint256 indexed groupIndex, uint256 indexed groupEpoch, address indexed committer
    );

    function testUpdateGroupByUnAuthorized() public {
        Params[] memory params = new Params[](10);
        bytes memory err;
        params[0] = Params(_node1, false, err, 0, 8, _publicKey, _partialPublicKey1, new address[](0));
        params[1] = Params(_node2, false, err, 0, 8, _publicKey, _partialPublicKey2, new address[](0));
        params[2] = Params(_node3, false, err, 0, 8, _publicKey, _partialPublicKey3, new address[](0));
        params[3] = Params(_node4, false, err, 0, 8, _publicKey, _partialPublicKey4, new address[](0));
        params[4] = Params(_node5, false, err, 0, 8, _publicKey, _partialPublicKey5, new address[](0));
        params[5] = Params(_node6, false, err, 0, 8, _publicKey, _partialPublicKey6, new address[](0));
        params[6] = Params(_node7, false, err, 0, 8, _publicKey, _partialPublicKey7, new address[](0));
        params[7] = Params(_node8, false, err, 0, 8, _publicKey, _partialPublicKey8, new address[](0));
        params[8] = Params(_node9, false, err, 0, 8, _publicKey, _partialPublicKey9, new address[](0));
        params[9] = Params(_node10, false, err, 0, 8, _publicKey, _partialPublicKey10, new address[](0));

        dkgHelper(params);

        assertEq(checkIsStrictlyMajorityConsensusReached(0), true);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).members.length, 10);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 10);

        bytes memory group = abi.encode(IControllerForTest(address(_controller)).getGroup(0));

        address chainMessenger = address(0x90001);
        MockL2CrossDomainMessenger l2CrossDomainMessenger = new MockL2CrossDomainMessenger(chainMessenger);
        address adapterContractAddress = address(0x90102);

        vm.prank(_admin);
        ControllerOracle controllerOracleImpl = new ControllerOracle();

        vm.prank(_admin);
        ERC1967Proxy controllerOracle = new ERC1967Proxy(
            address(controllerOracleImpl),
            abi.encodeWithSignature(
                "initialize(address,address,uint256)", address(_arpa), address(l2CrossDomainMessenger), 42
            )
        );
        vm.prank(_admin);
        ControllerOracle(address(controllerOracle)).setChainMessenger(chainMessenger);
        vm.prank(_admin);
        ControllerOracle(address(controllerOracle)).setAdapterContractAddress(adapterContractAddress);

        vm.prank(_node1);
        vm.expectRevert(ControllerOracle.SenderNotChainMessenger.selector);
        ControllerOracle(address(controllerOracle)).updateGroup(_node1, abi.decode(group, (IControllerOracle.Group)));
    }

    function testUpdateGroupByOwner() public {
        Params[] memory params = new Params[](10);
        bytes memory err;
        params[0] = Params(_node1, false, err, 0, 8, _publicKey, _partialPublicKey1, new address[](0));
        params[1] = Params(_node2, false, err, 0, 8, _publicKey, _partialPublicKey2, new address[](0));
        params[2] = Params(_node3, false, err, 0, 8, _publicKey, _partialPublicKey3, new address[](0));
        params[3] = Params(_node4, false, err, 0, 8, _publicKey, _partialPublicKey4, new address[](0));
        params[4] = Params(_node5, false, err, 0, 8, _publicKey, _partialPublicKey5, new address[](0));
        params[5] = Params(_node6, false, err, 0, 8, _publicKey, _partialPublicKey6, new address[](0));
        params[6] = Params(_node7, false, err, 0, 8, _publicKey, _partialPublicKey7, new address[](0));
        params[7] = Params(_node8, false, err, 0, 8, _publicKey, _partialPublicKey8, new address[](0));
        params[8] = Params(_node9, false, err, 0, 8, _publicKey, _partialPublicKey9, new address[](0));
        params[9] = Params(_node10, false, err, 0, 8, _publicKey, _partialPublicKey10, new address[](0));

        dkgHelper(params);

        assertEq(checkIsStrictlyMajorityConsensusReached(0), true);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).members.length, 10);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 10);

        bytes memory group = abi.encode(IControllerForTest(address(_controller)).getGroup(0));

        address chainMessenger = address(0x90001);
        address l2CrossDomainMessenger = address(0x90002);
        address adapterContractAddress = address(0x90102);

        vm.prank(_admin);
        ControllerOracle controllerOracleImpl = new ControllerOracle();

        vm.prank(_admin);
        ERC1967Proxy controllerOracle = new ERC1967Proxy(
            address(controllerOracleImpl),
            abi.encodeWithSignature(
                "initialize(address,address,uint256)", address(_arpa), address(l2CrossDomainMessenger), 42
            )
        );
        vm.prank(_admin);
        ControllerOracle(address(controllerOracle)).setChainMessenger(chainMessenger);
        vm.prank(_admin);
        ControllerOracle(address(controllerOracle)).setAdapterContractAddress(adapterContractAddress);

        vm.expectEmit(true, true, true, true);
        emit GroupUpdated(1, 0, 8, _admin);

        vm.prank(_admin);
        ControllerOracle(address(controllerOracle)).updateGroup(_admin, abi.decode(group, (IControllerOracle.Group)));

        printGroupInfo(ControllerOracle(address(controllerOracle)).getGroup(0));
    }

    function testUpdateGroupByL2CrossDomainMessenger() public {
        Params[] memory params = new Params[](10);
        bytes memory err;
        params[0] = Params(_node1, false, err, 0, 8, _publicKey, _partialPublicKey1, new address[](0));
        params[1] = Params(_node2, false, err, 0, 8, _publicKey, _partialPublicKey2, new address[](0));
        params[2] = Params(_node3, false, err, 0, 8, _publicKey, _partialPublicKey3, new address[](0));
        params[3] = Params(_node4, false, err, 0, 8, _publicKey, _partialPublicKey4, new address[](0));
        params[4] = Params(_node5, false, err, 0, 8, _publicKey, _partialPublicKey5, new address[](0));
        params[5] = Params(_node6, false, err, 0, 8, _publicKey, _partialPublicKey6, new address[](0));
        params[6] = Params(_node7, false, err, 0, 8, _publicKey, _partialPublicKey7, new address[](0));
        params[7] = Params(_node8, false, err, 0, 8, _publicKey, _partialPublicKey8, new address[](0));
        params[8] = Params(_node9, false, err, 0, 8, _publicKey, _partialPublicKey9, new address[](0));
        params[9] = Params(_node10, false, err, 0, 8, _publicKey, _partialPublicKey10, new address[](0));

        dkgHelper(params);

        assertEq(checkIsStrictlyMajorityConsensusReached(0), true);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).members.length, 10);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 10);

        bytes memory group = abi.encode(IControllerForTest(address(_controller)).getGroup(0));

        address chainMessenger = address(0x90001);
        MockL2CrossDomainMessenger l2CrossDomainMessenger = new MockL2CrossDomainMessenger(chainMessenger);
        address adapterContractAddress = address(0x90102);

        vm.prank(_admin);
        ControllerOracle controllerOracleImpl = new ControllerOracle();

        vm.prank(_admin);
        ERC1967Proxy controllerOracle = new ERC1967Proxy(
            address(controllerOracleImpl),
            abi.encodeWithSignature(
                "initialize(address,address,uint256)", address(_arpa), address(l2CrossDomainMessenger), 42
            )
        );
        vm.prank(_admin);
        ControllerOracle(address(controllerOracle)).setChainMessenger(chainMessenger);
        vm.prank(_admin);
        ControllerOracle(address(controllerOracle)).setAdapterContractAddress(adapterContractAddress);

        vm.expectEmit(true, true, true, true);
        emit GroupUpdated(1, 0, 8, _node1);

        vm.prank(address(l2CrossDomainMessenger));
        ControllerOracle(address(controllerOracle)).updateGroup(_node1, abi.decode(group, (IControllerOracle.Group)));

        printGroupInfo(ControllerOracle(address(controllerOracle)).getGroup(0));
    }

    function printGroupInfo(IControllerOracle.Group memory g) public {
        uint256 groupCount = IControllerForTest(address(_controller)).getGroupCount();
        emit log("----------------------------------------");
        emit log_named_uint("printing group info for: groupIndex", g.index);
        emit log("----------------------------------------");
        emit log_named_uint("Total groupCount", groupCount);
        emit log_named_uint("g.index", g.index);
        emit log_named_uint("g.epoch", g.epoch);
        emit log_named_uint("g.size", g.size);
        emit log_named_uint("g.threshold", g.threshold);
        emit log_named_uint("g.members.length", g.members.length);
        emit log_named_uint("g.isStrictlyMajorityConsensusReached", g.isStrictlyMajorityConsensusReached ? 1 : 0);
        for (uint256 i = 0; i < g.members.length; i++) {
            emit log_named_address(
                string.concat("g.members[", Strings.toString(i), "].nodeIdAddress"), g.members[i].nodeIdAddress
            );
            for (uint256 j = 0; j < g.members[i].partialPublicKey.length; j++) {
                emit log_named_uint(
                    string.concat(
                        "g.members[", Strings.toString(i), "].internal _partialPublicKey[", Strings.toString(j), "]"
                    ),
                    g.members[i].partialPublicKey[j]
                );
            }
        }
        // print committers
        emit log_named_uint("g.committers.length", g.committers.length);
        for (uint256 i = 0; i < g.committers.length; i++) {
            emit log_named_address(string.concat("g.committers[", Strings.toString(i), "]"), g.committers[i]);
        }
        // print commit cache info
        emit log_named_uint("g.commitCacheList.length", g.commitCacheList.length);
        for (uint256 i = 0; i < g.commitCacheList.length; i++) {
            // print commit result public key
            for (uint256 j = 0; j < g.commitCacheList[i].commitResult.publicKey.length; j++) {
                emit log_named_uint(
                    string.concat(
                        "g.commitCacheList[", Strings.toString(i), "].commitResult.publicKey[", Strings.toString(j), "]"
                    ),
                    g.commitCacheList[i].commitResult.publicKey[j]
                );
            }
            // print commit result disqualified nodes
            uint256 disqualifiedNodesLength = g.commitCacheList[i].commitResult.disqualifiedNodes.length;
            for (uint256 j = 0; j < disqualifiedNodesLength; j++) {
                emit log_named_address(
                    string.concat(
                        "g.commitCacheList[",
                        Strings.toString(i),
                        "].commitResult.disqualifiedNodes[",
                        Strings.toString(j),
                        "].nodeIdAddress"
                    ),
                    g.commitCacheList[i].commitResult.disqualifiedNodes[j]
                );
            }

            for (uint256 j = 0; j < g.commitCacheList[i].nodeIdAddress.length; j++) {
                emit log_named_address(
                    string.concat(
                        "g.commitCacheList[",
                        Strings.toString(i),
                        "].nodeIdAddress[",
                        Strings.toString(j),
                        "].nodeIdAddress"
                    ),
                    g.commitCacheList[i].nodeIdAddress[j]
                );
            }
        }

        // print publicKey
        emit log_named_uint("g.publicKey.length", g.publicKey.length);
        for (uint256 i = 0; i < g.publicKey.length; i++) {
            emit log_named_uint(string.concat("g.publicKey[", Strings.toString(i), "]"), g.publicKey[i]);
        }
    }
}
