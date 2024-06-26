// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

pragma experimental ABIEncoderV2;

import {
    RandcastTestHelper,
    ERC20,
    ControllerForTest,
    IController,
    IControllerOwner,
    INodeRegistry,
    NodeRegistry,
    ServiceManager,
    ERC1967Proxy,
    INodeRegistryOwner
} from "./RandcastTestHelper.sol";
import {IControllerForTest} from "./IControllerForTest.sol";
import {BLS} from "../src/libraries/BLS.sol";

contract ExtendedDKGScenarioTest is RandcastTestHelper {
    address internal _owner = _admin;

    // * Setup
    function setUp() public {
        _groupMaxCapacity = 6; // ! Set to 6 for extended rebalancing tests.
        _lastOutput = 0x2222222222222222;

        // add 31 test nodes
        addTestNode(1, _node1, _dkgPubkey1, _partialPublicKey1);
        addTestNode(2, _node2, _dkgPubkey2, _partialPublicKey2);
        addTestNode(3, _node3, _dkgPubkey3, _partialPublicKey3);
        addTestNode(4, _node4, _dkgPubkey4, _partialPublicKey4);
        addTestNode(5, _node5, _dkgPubkey5, _partialPublicKey5);
        addTestNode(6, _node6, _dkgPubkey6, _partialPublicKey6);
        addTestNode(7, _node7, _dkgPubkey7, _partialPublicKey7);
        addTestNode(8, _node8, _dkgPubkey8, _partialPublicKey8);
        addTestNode(9, _node9, _dkgPubkey9, _partialPublicKey9);
        addTestNode(10, _node10, _dkgPubkey10, _partialPublicKey10);
        addTestNode(11, _node11, _dkgPubkey11, _partialPublicKey11);
        addTestNode(12, _node12, _dkgPubkey12, _partialPublicKey12);
        addTestNode(13, _node13, _dkgPubkey13, _partialPublicKey13);
        addTestNode(14, _node14, _dkgPubkey14, _partialPublicKey14);
        addTestNode(15, _node15, _dkgPubkey15, _partialPublicKey15);
        addTestNode(16, _node16, _dkgPubkey16, _partialPublicKey16);
        addTestNode(17, _node17, _dkgPubkey17, _partialPublicKey17);
        addTestNode(18, _node18, _dkgPubkey18, _partialPublicKey18);
        addTestNode(19, _node19, _dkgPubkey19, _partialPublicKey19);
        addTestNode(20, _node20, _dkgPubkey20, _partialPublicKey20);
        addTestNode(21, _node21, _dkgPubkey21, _partialPublicKey21);
        addTestNode(22, _node22, _dkgPubkey22, _partialPublicKey22);
        addTestNode(23, _node23, _dkgPubkey23, _partialPublicKey23);
        addTestNode(24, _node24, _dkgPubkey24, _partialPublicKey24);
        addTestNode(25, _node25, _dkgPubkey25, _partialPublicKey25);
        addTestNode(26, _node26, _dkgPubkey26, _partialPublicKey26);
        addTestNode(27, _node27, _dkgPubkey27, _partialPublicKey27);
        addTestNode(28, _node28, _dkgPubkey28, _partialPublicKey28);
        addTestNode(29, _node29, _dkgPubkey29, _partialPublicKey29);
        addTestNode(30, _node30, _dkgPubkey30, _partialPublicKey30);
        addTestNode(31, _node31, _dkgPubkey31, _partialPublicKey31);

        // deal _owner and create _controller
        vm.deal(_owner, 1 * 10 ** 18);
        vm.deal(_stakingDeployer, 1 * 10 ** 18);

        vm.prank(_owner);
        _arpa = new ERC20("arpa token", "ARPA");

        // prepare operators for staking
        address[] memory operators = new address[](31);
        for (uint256 i = 1; i <= 31; i++) {
            operators[i - 1] = _testNodes[i].nodeAddress;
        }

        // deploy staking contract and add operators
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
    }

    // * Test Node Setup
    function testNodeSetup() public {
        bytes memory dkgPublicKey;
        address nodeIdAddress;
        uint256[4] memory _publicKey;
        uint256[4] memory partialPublicKey;

        for (uint256 i = 1; i <= 31; i++) {
            nodeIdAddress = _testNodes[i].nodeAddress;
            dkgPublicKey = _testNodes[i]._publicKey;
            _publicKey = BLS.fromBytesPublicKey(dkgPublicKey);
            partialPublicKey = BLS.fromBytesPublicKey(_testNodes[i].partialPublicKey);
            assertEq(BLS.isValidPublicKey(_publicKey), true);
            assertEq(BLS.isValidPublicKey(partialPublicKey), true);
        }
    }

    // * Node Register Helper Testing
    mapping(uint256 => TestNode) internal _testNodes;

    struct TestNode {
        address nodeAddress;
        bytes _publicKey;
        bytes partialPublicKey;
    }

    // Add a test node to the _testNodes mapping and deal eth: Used for setup
    function addTestNode(uint256 index, address nodeAddress, bytes memory _publicKey, bytes memory partialPublicKey)
        public
    {
        TestNode memory newNode =
            TestNode({nodeAddress: nodeAddress, _publicKey: _publicKey, partialPublicKey: partialPublicKey});

        _testNodes[index] = newNode;
        vm.deal(nodeAddress, 1 * 10 ** 18);
    }

    // Take in a uint256 specifying node index, call node register using info from _testNodes mapping
    function registerIndex(uint256 nodeIndex) public {
        vm.prank(_testNodes[nodeIndex].nodeAddress);
        INodeRegistry(address(_nodeRegistry)).nodeRegister(
            _testNodes[nodeIndex]._publicKey, false, _testNodes[nodeIndex].nodeAddress, _emptyOperatorSignature
        );
    }

    // * Commit DKG Helper Functions
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

    function successDKGHelper(uint256[] memory nodeIndices, uint256 groupIndex, uint256 groupEpoch) public {
        for (uint256 i = 0; i < nodeIndices.length; i++) {
            vm.prank(_testNodes[nodeIndices[i]].nodeAddress);
            IControllerForTest(address(_controller)).commitDkg(
                IController.CommitDkgParams(
                    groupIndex, groupEpoch, _publicKey, _testNodes[nodeIndices[i]].partialPublicKey, new address[](0)
                )
            );
        }
    }

    // * ////////////////////////////////////////////////////////////////////////////////
    // * Extended Scenario Tests Begin (Rebalancing, Regrouping, Various Edgecases etc..)
    // * ////////////////////////////////////////////////////////////////////////////////

    //  Regroup remaining nodes after nodeQuit: (5 -> 4)
    function test5NodeQuit() public {
        /*
        group_0: 5 members
        1 member of group_0 wants to exit the network
        Then, _controller will let 4 members left in group_0 do dkg as 4 > 3 which is the threshold
        i.e. the group still meet the grouping condition
        after that, in happy path group_0 will be functional with 4 members.
        */

        // register nodes 1-5 using registerHelper()
        assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 0);
        registerIndex(1);
        registerIndex(2);
        registerIndex(3); // _controller emits event here
        assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 1); // g.epoch++
        registerIndex(4); // here
        assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 2); // g.epoch++
        registerIndex(5); // and here
        assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 3); // g.epoch++

        // group the 5 nodes using commitdkg.
        Params[] memory params = new Params[](5);
        bytes memory err;
        params[0] = Params(_node1, false, err, 0, 3, _publicKey, _partialPublicKey1, new address[](0));
        params[1] = Params(_node2, false, err, 0, 3, _publicKey, _partialPublicKey2, new address[](0));
        params[2] = Params(_node3, false, err, 0, 3, _publicKey, _partialPublicKey3, new address[](0));
        params[3] = Params(_node4, false, err, 0, 3, _publicKey, _partialPublicKey4, new address[](0));
        params[4] = Params(_node5, false, err, 0, 3, _publicKey, _partialPublicKey5, new address[](0));
        dkgHelper(params);

        // assert group info
        assertEq(checkIsStrictlyMajorityConsensusReached(0), true);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).members.length, 5);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 5);

        vm.roll(block.number + 41);
        vm.prank(_node1);
        IControllerForTest(address(_controller)).postProcessDkg(0, 3);

        // node 1 calls nodeQuit
        vm.prank(_node1);
        INodeRegistry(address(_nodeRegistry)).nodeQuit(); // _controller emits event to start dkg proccess
        assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 4); // g.epoch++

        // node 2-4 call commitdkg
        params = new Params[](4);
        params[0] = Params(_node2, false, err, 0, 4, _publicKey, _partialPublicKey2, new address[](0));
        params[1] = Params(_node3, false, err, 0, 4, _publicKey, _partialPublicKey3, new address[](0));
        params[2] = Params(_node4, false, err, 0, 4, _publicKey, _partialPublicKey4, new address[](0));
        params[3] = Params(_node5, false, err, 0, 4, _publicKey, _partialPublicKey5, new address[](0));
        dkgHelper(params);

        // check group info
        assertEq(checkIsStrictlyMajorityConsensusReached(0), true);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).members.length, 4);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 4);
        // printGroupInfo(0);
    }

    //  Rebalance two groups after nodeQuit results in group falling below threshold (5,3) -> (3,4)
    function test53NodeQuit() public {
        /*
        group_0: 5 members
        group_1: 3 members
        1 member of group_1 wants to exist the network.
        Then, _controller will let group_1 which has 2 remaining members rebalance with group_0.
        Result: group_0 (3 members), group_1 (4 members) are both functional.
        */

        // * Register and group 5 nodes to group_0
        assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 0);
        registerIndex(1);
        registerIndex(2);
        registerIndex(3); // _controller emits event here (1-3 call commitDkg)
        assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 1); // g.epoch++
        registerIndex(4); // here (1-4 call commitDkg)
        assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 2); // g.epoch++
        registerIndex(5); // here
        assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 3); // g.epoch++

        // group the 5 nodes using commitdkg.
        Params[] memory params = new Params[](5);
        bytes memory err;
        params[0] = Params(_node1, false, err, 0, 3, _publicKey, _partialPublicKey1, new address[](0));
        params[1] = Params(_node2, false, err, 0, 3, _publicKey, _partialPublicKey2, new address[](0));
        params[2] = Params(_node3, false, err, 0, 3, _publicKey, _partialPublicKey3, new address[](0));
        params[3] = Params(_node4, false, err, 0, 3, _publicKey, _partialPublicKey4, new address[](0));
        params[4] = Params(_node5, false, err, 0, 3, _publicKey, _partialPublicKey5, new address[](0));
        dkgHelper(params);

        // assert group info
        assertEq(checkIsStrictlyMajorityConsensusReached(0), true);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).members.length, 5);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 5);

        // * Register and group 5 new nodes
        assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 3); // initial state
        assertEq(IControllerForTest(address(_controller)).getGroup(1).epoch, 0); // initial state

        registerIndex(6); // Groups are rebalanced to (3,3) group_0 and group_1 epoch's are incremented here.
        // assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 4); // g.epoch++
        assertEq(IControllerForTest(address(_controller)).getGroup(1).epoch, 1); // g.epoch++
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 3);
        assertEq(IControllerForTest(address(_controller)).getGroup(1).size, 3);
        assertEq(checkIsStrictlyMajorityConsensusReached(0), false);
        assertEq(checkIsStrictlyMajorityConsensusReached(1), false);

        registerIndex(7); // added to group_0, only group_0 epoch is incremented
        assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 5); // g.epoch++
        assertEq(IControllerForTest(address(_controller)).getGroup(1).epoch, 1); // no change
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 4); // g.size++
        assertEq(IControllerForTest(address(_controller)).getGroup(1).size, 3);
        assertEq(checkIsStrictlyMajorityConsensusReached(0), false);
        assertEq(checkIsStrictlyMajorityConsensusReached(1), false);

        registerIndex(8); // added to group_1, only group_1 epoch is incremented
        assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 5); // no change
        assertEq(IControllerForTest(address(_controller)).getGroup(1).epoch, 2); // g.epoch++
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 4);
        assertEq(IControllerForTest(address(_controller)).getGroup(1).size, 4); // g.size++
        assertEq(checkIsStrictlyMajorityConsensusReached(0), false);
        assertEq(checkIsStrictlyMajorityConsensusReached(1), false);

        registerIndex(9); // added to group_0, only group_0 epoch is incremented
        assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 6); // g.epoch++
        assertEq(IControllerForTest(address(_controller)).getGroup(1).epoch, 2); // no change
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 5); // g.size++
        assertEq(IControllerForTest(address(_controller)).getGroup(1).size, 4);
        assertEq(checkIsStrictlyMajorityConsensusReached(0), false);
        assertEq(checkIsStrictlyMajorityConsensusReached(1), false);

        registerIndex(10); // added to group_1, only group_1 epoch is incremented
        assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 6); // no change
        assertEq(IControllerForTest(address(_controller)).getGroup(1).epoch, 3); // g.epoch++
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 5);
        assertEq(IControllerForTest(address(_controller)).getGroup(1).size, 5); // g.size++
        assertEq(checkIsStrictlyMajorityConsensusReached(0), false);
        assertEq(checkIsStrictlyMajorityConsensusReached(1), false);
        // groups have been reshuffled, current indexes are as follows:
        // group_0 (1,2,3,7,9), group_1 (6,5,4,8,10)

        // finish dkg for group_0 and group_1
        params = new Params[](5);
        params[0] = Params(_node1, false, err, 0, 6, _publicKey, _partialPublicKey5, new address[](0));
        params[1] = Params(_node2, false, err, 0, 6, _publicKey, _partialPublicKey4, new address[](0));
        params[2] = Params(_node3, false, err, 0, 6, _publicKey, _partialPublicKey3, new address[](0));
        params[3] = Params(_node7, false, err, 0, 6, _publicKey, _partialPublicKey7, new address[](0));
        params[4] = Params(_node9, false, err, 0, 6, _publicKey, _partialPublicKey9, new address[](0));
        dkgHelper(params);

        uint256[] memory nodeIndices2 = new uint256[](5);
        nodeIndices2[0] = 6;
        nodeIndices2[1] = 5;
        nodeIndices2[2] = 4;
        nodeIndices2[3] = 8;
        nodeIndices2[4] = 10;
        successDKGHelper(nodeIndices2, 1, 3);

        vm.roll(block.number + 41);
        vm.prank(_node8);
        IControllerForTest(address(_controller)).postProcessDkg(1, 3);

        // * Remove two nodes from group_1 (node8, node10) so that group_1 size == 3
        vm.prank(_node8);
        INodeRegistry(address(_nodeRegistry)).nodeQuit(); // group_1 epoch is incremented here
        assertEq(IControllerForTest(address(_controller)).getGroup(1).epoch, 4); // g.epoch++
        assertEq(IControllerForTest(address(_controller)).getGroup(1).size, 4); // g.size--

        uint256[] memory nodeIndices3 = new uint256[](4);
        nodeIndices3[0] = 6;
        nodeIndices3[1] = 5;
        nodeIndices3[2] = 4;
        nodeIndices3[3] = 10;
        successDKGHelper(nodeIndices3, 1, 4);

        vm.roll(block.number + 41);
        vm.prank(_node10);
        IControllerForTest(address(_controller)).postProcessDkg(1, 4);

        vm.prank(_node10);
        INodeRegistry(address(_nodeRegistry)).nodeQuit(); // group_1 epoch is incremented here
        assertEq(IControllerForTest(address(_controller)).getGroup(1).epoch, 5); // g.epoch++
        assertEq(IControllerForTest(address(_controller)).getGroup(1).size, 3); // g.size--

        // * (5,3) configuration reached: group_0 (1,2,3,7,9) / group_1 (6,5,4)
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 5);
        assertEq(IControllerForTest(address(_controller)).getGroup(1).size, 3);
        assertEq(checkIsStrictlyMajorityConsensusReached(1), false);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 6);
        assertEq(IControllerForTest(address(_controller)).getGroup(1).epoch, 5);

        // * group group_1 with commitDKG
        params = new Params[](3);
        params[0] = Params(_node6, false, err, 1, 5, _publicKey, _partialPublicKey6, new address[](0));
        params[1] = Params(_node5, false, err, 1, 5, _publicKey, _partialPublicKey1, new address[](0));
        params[2] = Params(_node4, false, err, 1, 5, _publicKey, _partialPublicKey2, new address[](0));
        dkgHelper(params);

        assertEq(checkIsStrictlyMajorityConsensusReached(0), true);
        assertEq(checkIsStrictlyMajorityConsensusReached(1), true);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 6); // g.epoch++
        assertEq(IControllerForTest(address(_controller)).getGroup(1).epoch, 5); // g.epoch++

        vm.roll(block.number + 41);
        vm.prank(_node6);
        IControllerForTest(address(_controller)).postProcessDkg(1, 5);

        // * node in group_1 quits (node6)
        vm.prank(_node6);
        INodeRegistry(address(_nodeRegistry)).nodeQuit();
        // group_1 falls below threshold, rebalancing occurs to (3,4), event emitted for both groups
        assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 7); // g.epoch++
        assertEq(IControllerForTest(address(_controller)).getGroup(1).epoch, 6); // g.epoch++
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 3);
        assertEq(IControllerForTest(address(_controller)).getGroup(1).size, 4);
        assertEq(checkIsStrictlyMajorityConsensusReached(0), false);
        assertEq(checkIsStrictlyMajorityConsensusReached(1), false);

        // * group group_0 (1,2,3) and group_1 (4,5,9,7) with commitDKG
        params = new Params[](3);
        params[0] = Params(_node1, false, err, 0, 7, _publicKey, _partialPublicKey9, new address[](0));
        params[1] = Params(_node2, false, err, 0, 7, _publicKey, _partialPublicKey7, new address[](0));
        params[2] = Params(_node3, false, err, 0, 7, _publicKey, _partialPublicKey3, new address[](0));
        dkgHelper(params);

        params = new Params[](4);
        params[0] = Params(_node4, false, err, 1, 6, _publicKey, _partialPublicKey2, new address[](0));
        params[1] = Params(_node5, false, err, 1, 6, _publicKey, _partialPublicKey1, new address[](0));
        params[2] = Params(_node9, false, err, 1, 6, _publicKey, _partialPublicKey5, new address[](0));
        params[3] = Params(_node7, false, err, 1, 6, _publicKey, _partialPublicKey4, new address[](0));
        dkgHelper(params);

        assertEq(checkIsStrictlyMajorityConsensusReached(0), true);
        assertEq(checkIsStrictlyMajorityConsensusReached(1), true);

        // printGroupInfo(0);
        // printGroupInfo(1);
    }

    // * For the following tests we focus on Rebalancing logic rather than CommitDKG() details

    // [6,6] -> nodeRegister -> [3,6,4]
    function test66NodeRegister() public {
        /*
        group_0: 6 members
        group_1: 6 members
        A new node calls nodeRegister.
        _Controller should create a new group (group_2), add the new node into group_2, and then rebalance between group_0 and group_2.
        Final network status should be [3,6,4]
        */

        // Setup group_0 and group_1 so that they have 6 grouped nodes each
        registerIndex(1);
        registerIndex(2);
        registerIndex(3);
        registerIndex(4);
        registerIndex(5);
        registerIndex(6);
        registerIndex(7);
        registerIndex(8);
        registerIndex(9);
        registerIndex(10);
        registerIndex(11);
        registerIndex(12);

        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 6);
        assertEq(IControllerForTest(address(_controller)).getGroup(1).size, 6);

        assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 8);
        assertEq(IControllerForTest(address(_controller)).getGroup(1).epoch, 3);
        // Current state: group_0 (1,6,3,8,9,11), group_1 (7,2,5,4,10,12)

        // New node calls node register.
        registerIndex(13);

        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 3);
        assertEq(IControllerForTest(address(_controller)).getGroup(1).size, 6);
        assertEq(IControllerForTest(address(_controller)).getGroup(2).size, 4);

        assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 9); // g.epoch++
        assertEq(IControllerForTest(address(_controller)).getGroup(1).epoch, 3); // no change
        assertEq(IControllerForTest(address(_controller)).getGroup(2).epoch, 1); // g.epoch++

        // Final State: group_0 (1,11,3), group_1 (7,2,5,4,10,12), group_2 (13,6,9,8)

        // printGroupInfo(0);
        // printGroupInfo(1);
        // printGroupInfo(2);
    }

    // [3,3] -> nodeRegister -> [3,3,1]
    function test33NodeRegister() public {
        /*
        group_0: 3 members
        group_1: 3 members
        A new node calls nodeRegister
        _Controller should create a new group_2, add the new node into group_2, then try to rebalance.
        Final network status should be (3,3,1) with group_2 not yet functional.
        */

        // Setup group_0 and group_1 so that they have 3 grouped nodes each.
        // register and group 3 nodes (1,2,3)
        registerIndex(1);
        registerIndex(2);
        registerIndex(3);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 1);

        bytes memory err;
        Params[] memory params = new Params[](3);
        params[0] = Params(_node1, false, err, 0, 1, _publicKey, _partialPublicKey1, new address[](0));
        params[1] = Params(_node2, false, err, 0, 1, _publicKey, _partialPublicKey2, new address[](0));
        params[2] = Params(_node3, false, err, 0, 1, _publicKey, _partialPublicKey3, new address[](0));
        dkgHelper(params);

        // register and group 3 nodes (4,5,6)
        registerIndex(4);
        registerIndex(5);
        registerIndex(6);
        assertEq(IControllerForTest(address(_controller)).getGroup(1).epoch, 1);

        params = new Params[](3);
        params[0] = Params(_node4, false, err, 1, 1, _publicKey, _partialPublicKey4, new address[](0));
        params[1] = Params(_node5, false, err, 1, 1, _publicKey, _partialPublicKey5, new address[](0));
        params[2] = Params(_node6, false, err, 1, 1, _publicKey, _partialPublicKey6, new address[](0));
        dkgHelper(params);

        // current state: group_0 (1,2,3), group_1 (4,5,6)

        // New node calls node register.
        registerIndex(7);

        // node added to new group 2. Group 0 and 1 remain functional, group 2 not yet funcional
        assertEq(IControllerForTest(address(_controller)).getGroup(2).size, 1);
        assertEq(checkIsStrictlyMajorityConsensusReached(0), true);
        assertEq(checkIsStrictlyMajorityConsensusReached(1), true);
        assertEq(checkIsStrictlyMajorityConsensusReached(2), false);

        // Final State: group_0 (1,2,3), group_1 (4,5,6), group_2 (7)
        // Group 2 is not yet functional, but it is created. Group 0 and 1 are functional.

        // printGroupInfo(0);
        // printGroupInfo(1);
        // printGroupInfo(2);
    }

    // Ideal number of groups of size 3 -> new nodeRegister()
    // [3,3,3,3,3] -> nodeRegister -> [4,3,3,3,3]
    function test33333NodeRegister() public {
        /*
        (5 groups) group 0-4 have 3 members each [3,3,3,3,3]
        A new node calls nodeRegister
        _Controller should add new node into group_0 resulting in network state [4,3,3,3,3].
        */

        // Setup groups 0,1,2,3,4 so that they have 3 grouped nodes each.
        // group_0: register and group 3 nodes (1,2,3)
        registerIndex(1);
        registerIndex(2);
        registerIndex(3);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 1);
        bytes memory err;
        Params[] memory params = new Params[](3);
        params[0] = Params(_node1, false, err, 0, 1, _publicKey, _partialPublicKey1, new address[](0));
        params[1] = Params(_node2, false, err, 0, 1, _publicKey, _partialPublicKey2, new address[](0));
        params[2] = Params(_node3, false, err, 0, 1, _publicKey, _partialPublicKey3, new address[](0));
        dkgHelper(params);

        // group_1: register and group 3 nodes (4,5,6)
        registerIndex(4);
        registerIndex(5);
        registerIndex(6);
        assertEq(IControllerForTest(address(_controller)).getGroup(1).epoch, 1);
        params = new Params[](3);
        params[0] = Params(_node4, false, err, 1, 1, _publicKey, _partialPublicKey4, new address[](0));
        params[1] = Params(_node5, false, err, 1, 1, _publicKey, _partialPublicKey5, new address[](0));
        params[2] = Params(_node6, false, err, 1, 1, _publicKey, _partialPublicKey6, new address[](0));
        dkgHelper(params);

        // group_2: register and group 3 nodes (7,8,9)
        registerIndex(7);
        registerIndex(8);
        registerIndex(9);
        assertEq(IControllerForTest(address(_controller)).getGroup(2).epoch, 1);
        params = new Params[](3);
        params[0] = Params(_node7, false, err, 2, 1, _publicKey, _partialPublicKey7, new address[](0));
        params[1] = Params(_node8, false, err, 2, 1, _publicKey, _partialPublicKey8, new address[](0));
        params[2] = Params(_node9, false, err, 2, 1, _publicKey, _partialPublicKey9, new address[](0));
        dkgHelper(params);

        // group_3: register and group 3 nodes (10,11,12)
        registerIndex(10);
        registerIndex(11);
        registerIndex(12);
        assertEq(IControllerForTest(address(_controller)).getGroup(3).epoch, 1);
        params = new Params[](3);
        params[0] = Params(_node10, false, err, 3, 1, _publicKey, _partialPublicKey10, new address[](0));
        params[1] = Params(_node11, false, err, 3, 1, _publicKey, _partialPublicKey11, new address[](0));
        params[2] = Params(_node12, false, err, 3, 1, _publicKey, _partialPublicKey12, new address[](0));
        dkgHelper(params);

        // group_4: register and group 3 nodes (13,14,15)
        registerIndex(13);
        registerIndex(14);
        registerIndex(15);
        assertEq(IControllerForTest(address(_controller)).getGroup(4).epoch, 1);
        params = new Params[](3);
        params[0] = Params(_node13, false, err, 4, 1, _publicKey, _partialPublicKey13, new address[](0));
        params[1] = Params(_node14, false, err, 4, 1, _publicKey, _partialPublicKey14, new address[](0));
        params[2] = Params(_node15, false, err, 4, 1, _publicKey, _partialPublicKey15, new address[](0));
        dkgHelper(params);

        // current state: group_0 (1,2,3), group_1 (4,5,6), group_2 (7,8,9), group_3 (10,11,12), group_4 (13,14,15)
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 3);
        assertEq(IControllerForTest(address(_controller)).getGroup(1).size, 3);
        assertEq(IControllerForTest(address(_controller)).getGroup(2).size, 3);
        assertEq(IControllerForTest(address(_controller)).getGroup(3).size, 3);
        assertEq(IControllerForTest(address(_controller)).getGroup(4).size, 3);
        assertEq(checkIsStrictlyMajorityConsensusReached(0), true);
        assertEq(checkIsStrictlyMajorityConsensusReached(1), true);
        assertEq(checkIsStrictlyMajorityConsensusReached(2), true);
        assertEq(checkIsStrictlyMajorityConsensusReached(3), true);
        assertEq(checkIsStrictlyMajorityConsensusReached(4), true);

        // New node calls node register: It gets added to group_0, new event is emitted
        registerIndex(16);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 4);
        assertEq(checkIsStrictlyMajorityConsensusReached(0), false);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 2);

        // Final State: [4,3,3,3,3]
        // group_0 (1,2,3,16), group_1 (4,5,6), group_2 (7,8,9), group_3 (10,11,12), group_4 (13,14,15)
        // group_0 nonfunctiona, waiting to be grouped by commitDKG. Remaining groups are functional

        // printGroupInfo(0);
        // printGroupInfo(1);
        // printGroupInfo(2);
        // printGroupInfo(3);
        // printGroupInfo(4);
    }

    // ideal number of groups at max capacity -> nodeQuit()
    // [6,6,6,6,6] -> nodeRegister -> [3,6,6,6,6,4]]
    function test66666NodeRegister() public {
        /*
        (5 groups) group 0-4 have 6 members each [6,6,6,6,6]
        A new node calls node register.
        _Controller should create a new group (group_5), add the new node to group_5, and then rebalance between group_0 and group_5.
        Resulting network state should be [3,6,6,6,6,4]
        */

        // setup groups 0,1,2,3,4,5 so that they have 6 nodes each
        registerIndex(1);
        registerIndex(2);
        registerIndex(3);
        registerIndex(4);
        registerIndex(5);
        registerIndex(6);
        registerIndex(7);
        registerIndex(8);
        registerIndex(9);
        registerIndex(10);
        registerIndex(11);
        registerIndex(12);
        registerIndex(13);
        registerIndex(14);
        registerIndex(15);
        registerIndex(16);
        registerIndex(17);
        registerIndex(18);
        registerIndex(19);
        registerIndex(20);
        registerIndex(21);
        registerIndex(22);
        registerIndex(23);
        registerIndex(24);
        registerIndex(25);
        registerIndex(26);
        registerIndex(27);
        registerIndex(28);
        registerIndex(29);
        registerIndex(30);

        // Epochs after registering 30 nodes
        assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 20);
        assertEq(IControllerForTest(address(_controller)).getGroup(1).epoch, 3);
        assertEq(IControllerForTest(address(_controller)).getGroup(2).epoch, 3);
        assertEq(IControllerForTest(address(_controller)).getGroup(3).epoch, 3);
        assertEq(IControllerForTest(address(_controller)).getGroup(4).epoch, 3);

        // All groups of size 6
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 6);
        assertEq(IControllerForTest(address(_controller)).getGroup(1).size, 6);
        assertEq(IControllerForTest(address(_controller)).getGroup(2).size, 6);
        assertEq(IControllerForTest(address(_controller)).getGroup(3).size, 6);
        assertEq(IControllerForTest(address(_controller)).getGroup(4).size, 6);

        // A new node calls node register
        // _Controller creates new group_5, adds the new node to it,
        // and then rebalances between group_0 and group_5 (3,6,6,6,6,4)
        registerIndex(31);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 3);
        assertEq(IControllerForTest(address(_controller)).getGroup(1).size, 6);
        assertEq(IControllerForTest(address(_controller)).getGroup(2).size, 6);
        assertEq(IControllerForTest(address(_controller)).getGroup(3).size, 6);
        assertEq(IControllerForTest(address(_controller)).getGroup(4).size, 6);
        assertEq(IControllerForTest(address(_controller)).getGroup(5).size, 4);

        // grouping events emitted for group_0 and group_5
        assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 21); //g.epoch++
        assertEq(IControllerForTest(address(_controller)).getGroup(5).epoch, 1); //g.epoch++

        // final state: [3,6,6,6,6,4]

        // printGroupInfo(0);
        // printGroupInfo(1);
        // printGroupInfo(2);
        // printGroupInfo(3);
        // printGroupInfo(4);
        // printGroupInfo(5);
    }

    // [6,3] -> group_1 nodeQuit -> [4,4]
    function test63Group1NodeQuit() public {
        /*
        (2 groups) group 0 has 6 members, group 1 has 3 members [6,3]
        group_1 calls nodeQuit
        _Controller should remove the node from group_1, and then rebalance between group_0 and group_1.'
        Resulting network state should be [4,4]
        */

        // Register 12 nodes
        registerIndex(1);
        registerIndex(2);
        registerIndex(3);
        registerIndex(4);
        registerIndex(5);
        registerIndex(6);
        registerIndex(7);
        registerIndex(8);
        registerIndex(9);
        registerIndex(10);
        registerIndex(11);
        registerIndex(12);

        printGroupInfo(0);
        printGroupInfo(1);

        // Current state: group_0 (1,6,3,8,9,11), group_1 (7,2,5,4,10,12)

        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 6);
        assertEq(IControllerForTest(address(_controller)).getGroup(1).size, 6);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 8);
        assertEq(IControllerForTest(address(_controller)).getGroup(1).epoch, 3);

        uint256[] memory nodeIndices = new uint256[](6);
        nodeIndices[0] = 7;
        nodeIndices[1] = 2;
        nodeIndices[2] = 5;
        nodeIndices[3] = 4;
        nodeIndices[4] = 10;
        nodeIndices[5] = 12;
        successDKGHelper(nodeIndices, 1, 3);

        vm.roll(block.number + 41);
        vm.prank(_node12);
        IControllerForTest(address(_controller)).postProcessDkg(1, 3);

        // Reduce group_1 size to 3
        vm.prank(_node12);
        INodeRegistry(address(_nodeRegistry)).nodeQuit();
        assertEq(IControllerForTest(address(_controller)).getGroup(1).epoch, 4); //g.epoch++

        uint256[] memory nodeIndices1 = new uint256[](5);
        nodeIndices1[0] = 7;
        nodeIndices1[1] = 2;
        nodeIndices1[2] = 5;
        nodeIndices1[3] = 4;
        nodeIndices1[4] = 10;
        successDKGHelper(nodeIndices1, 1, 4);

        vm.roll(block.number + 41);
        vm.prank(_node10);
        IControllerForTest(address(_controller)).postProcessDkg(1, 4);

        vm.prank(_node10);
        INodeRegistry(address(_nodeRegistry)).nodeQuit();
        assertEq(IControllerForTest(address(_controller)).getGroup(1).epoch, 5); //g.epoch++

        uint256[] memory nodeIndices2 = new uint256[](4);
        nodeIndices2[0] = 7;
        nodeIndices2[1] = 2;
        nodeIndices2[2] = 5;
        nodeIndices2[3] = 4;
        successDKGHelper(nodeIndices2, 1, 5);

        vm.roll(block.number + 41);
        vm.prank(_node2);
        IControllerForTest(address(_controller)).postProcessDkg(1, 5);

        vm.prank(_node2);
        INodeRegistry(address(_nodeRegistry)).nodeQuit();
        assertEq(IControllerForTest(address(_controller)).getGroup(1).epoch, 6); //g.epoch++

        uint256[] memory nodeIndices3 = new uint256[](3);
        nodeIndices3[0] = 7;
        nodeIndices3[1] = 4;
        nodeIndices3[2] = 5;
        successDKGHelper(nodeIndices3, 1, 6);

        vm.roll(block.number + 41);
        vm.prank(_node7);
        IControllerForTest(address(_controller)).postProcessDkg(1, 6);
        // size [6,3] reached
        // Current state: group_0 (1,6,3,8,9,11), group_1 (7,4,5)

        // node7 from group_1 calls nodeQuit
        // _controller rebalances between group_0 and group_1 resulting in [4,4]
        vm.prank(_node7);
        INodeRegistry(address(_nodeRegistry)).nodeQuit();
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 4);
        assertEq(IControllerForTest(address(_controller)).getGroup(1).size, 4);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 9); //g.epoch++
        assertEq(IControllerForTest(address(_controller)).getGroup(1).epoch, 7); //g.epoch++

        // final state: [4,4]
        // group_0 (1,11,3,8), group_1 (5,4,6,9)

        // printGroupInfo(0);
        // printGroupInfo(1);
    }

    function test63Group0NodeQuit() public {
        /*
        group_0: 6 members
        group_1: 3 members
        member in group_0 calls nodeQuit.
        Then, the _controller should emitDkgEvent for group_0 with the 5 remaining remmbers.
        Resulting network state should be [5,3]
        */

        // Register 12 nodes
        registerIndex(1);
        registerIndex(2);
        registerIndex(3);
        registerIndex(4);
        registerIndex(5);
        registerIndex(6);
        registerIndex(7);
        registerIndex(8);
        registerIndex(9);
        registerIndex(10);
        registerIndex(11);
        registerIndex(12);

        // Current state: group_0 (1,6,3,8,9,11), group_1 (7,2,5,4,10,12)
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 6);
        assertEq(IControllerForTest(address(_controller)).getGroup(1).size, 6);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 8);
        assertEq(IControllerForTest(address(_controller)).getGroup(1).epoch, 3);

        uint256[] memory nodeIndices1 = new uint256[](6);
        nodeIndices1[0] = 1;
        nodeIndices1[1] = 6;
        nodeIndices1[2] = 3;
        nodeIndices1[3] = 8;
        nodeIndices1[4] = 9;
        nodeIndices1[5] = 11;
        successDKGHelper(nodeIndices1, 0, 8);

        uint256[] memory nodeIndices2 = new uint256[](6);
        nodeIndices2[0] = 7;
        nodeIndices2[1] = 2;
        nodeIndices2[2] = 5;
        nodeIndices2[3] = 4;
        nodeIndices2[4] = 10;
        nodeIndices2[5] = 12;
        successDKGHelper(nodeIndices2, 1, 3);

        vm.roll(block.number + 41);
        vm.prank(_node1);
        IControllerForTest(address(_controller)).postProcessDkg(0, 8);
        vm.prank(_node12);
        IControllerForTest(address(_controller)).postProcessDkg(1, 3);

        // Reduce group_1 size to 3
        vm.prank(_node12);
        INodeRegistry(address(_nodeRegistry)).nodeQuit();
        assertEq(IControllerForTest(address(_controller)).getGroup(1).epoch, 4); //g.epoch++

        uint256[] memory nodeIndices3 = new uint256[](5);
        nodeIndices3[0] = 7;
        nodeIndices3[1] = 2;
        nodeIndices3[2] = 5;
        nodeIndices3[3] = 4;
        nodeIndices3[4] = 10;
        successDKGHelper(nodeIndices3, 1, 4);

        vm.roll(block.number + 41);
        vm.prank(_node10);
        IControllerForTest(address(_controller)).postProcessDkg(1, 4);

        vm.prank(_node10);
        INodeRegistry(address(_nodeRegistry)).nodeQuit();
        assertEq(IControllerForTest(address(_controller)).getGroup(1).epoch, 5); //g.epoch++

        uint256[] memory nodeIndices4 = new uint256[](4);
        nodeIndices4[0] = 7;
        nodeIndices4[1] = 2;
        nodeIndices4[2] = 5;
        nodeIndices4[3] = 4;
        successDKGHelper(nodeIndices4, 1, 5);

        vm.roll(block.number + 41);
        vm.prank(_node2);
        IControllerForTest(address(_controller)).postProcessDkg(1, 5);

        vm.prank(_node2);
        INodeRegistry(address(_nodeRegistry)).nodeQuit();
        assertEq(IControllerForTest(address(_controller)).getGroup(1).epoch, 6); //g.epoch++
        // size [6,3] reached
        // current state: group_0 (1,6,3,8,9,11), group_1 (7,4,5)

        // node11 from group_0 calls nodeQuit
        vm.prank(_node11);
        INodeRegistry(address(_nodeRegistry)).nodeQuit();
        assertEq(IControllerForTest(address(_controller)).getGroup(0).size, 5);
        assertEq(IControllerForTest(address(_controller)).getGroup(1).size, 3);
        assertEq(IControllerForTest(address(_controller)).getGroup(0).epoch, 9); // g.epoch++
        assertEq(IControllerForTest(address(_controller)).getGroup(1).epoch, 6); // no change

        // final state: [5,3]
        // group_0 (1,6,3,8,9), group_1 (7,4,5)

        // printGroupInfo(0);
        // printGroupInfo(1);
    }
}
