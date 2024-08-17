// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Raffle} from "../../src/Raffle.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import {console} from "lib/forge-std/src/console.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {Vm} from "lib/forge-std/src/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    /* Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;

    //creating a user for tests
    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_BALANCE = 10 ether;
    uint256 public constant LINK_BALANCE = 100 ether;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;

        vm.deal(PLAYER, STARTING_BALANCE);
    }

    /* MODIFIER */
    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.open);
    }

    function testRaffleRevertsWhenYouDontSendEnoughEth() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__SendMoreEthToEnterRaffle.selector);

        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        vm.prank(PLAYER);

        raffle.enterRaffle{value: entranceFee}();
        assert(raffle.getPlayer(0) == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        vm.prank(PLAYER);

        vm.expectEmit(true, false, false, false);
        emit RaffleEntered(PLAYER);

        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhileCalculating()
        public
        raffleEntered
    {
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleIsClosed.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    /* CHECKUPKEEP TESTS */

    function testCheckUpKeepReturnsFalseIfItHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpKeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfRaffleIsNotOpen()
        public
        raffleEntered
    {
        raffle.performUpkeep("");

        (bool upkeepNeeded, ) = raffle.checkUpKeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfEnoughTimeHasNotPassed() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval - 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded, ) = raffle.checkUpKeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenConditionsMet() public {
    // Arrange: Enter a player and move time forward
    vm.prank(PLAYER);
    raffle.enterRaffle{value: entranceFee}();
    vm.warp(block.timestamp + interval + 1);
    vm.roll(block.number + 1);

    // Act
    (bool upkeepNeeded, ) = raffle.checkUpKeep("");

    // Assert
    assertTrue(upkeepNeeded, "Upkeep should be needed when all conditions are met");
}

    /* PERFORMUPKEEP TESTS */

    function testPerformUpKeepCanOnlyRunIfCheckUpKeepReturnsTrue()
        public
        raffleEntered
    {
        raffle.performUpkeep("");
    }

    function testPerformUpKeepRevertsIfCheckUpIsFalse() public {
        uint256 balance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        balance = balance + entranceFee;
        numPlayers = numPlayers + 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__upKeepNotNeeded.selector,
                balance,
                numPlayers,
                rState
            )
        );

        raffle.performUpkeep("");
    }

    function testPerformUpKeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEntered
    {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        assert(uint256(raffle.getRaffleState()) == 1);
        assert(uint256(requestId) > 0);
    }

    /* FULFULLRANDOMWORDS TESTS */

    function testfulFillRandomWordsCanOnlyBeCalledAfterPerformUpKeep(
        uint256 randomRequestId
    ) public raffleEntered {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testfulfillrandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEntered
    {
        // Arrange
        uint256 additionalEntrants = 3; // total 4 players will be in the raffle
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 10 ether);
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 startingTimeStamp = raffle.getlastTimestamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // console.log("VRF Coordinator address:", address(vrfCoordinator));
        // console.log("Raffle address:", address(raffle));
        // console.log("Request ID:", requestId);
        // console.log(
        //     "VRF Coordinator LINK balance:",
        //     LINK.balanceOf(address(vrfCoordinator))
        // );
        // console.log("Raffle LINK balance:", LINK.balanceOf(address(raffle)));

        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getlastTimestamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
