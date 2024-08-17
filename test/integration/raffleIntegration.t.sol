// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "lib/forge-std/src/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleIntegrationTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;
    
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    uint256 subscriptionId;
    
    address[] public players;
    uint8 public constant PLAYERS_COUNT = 3;
    
    event RequestIdForWinner(uint256 indexed requestId);
    
    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();
        
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        subscriptionId = config.subscriptionId;
        
        // Create test players
        for (uint8 i = 0; i < PLAYERS_COUNT; i++) {
            address player = address(uint160(i + 1));
            players.push(player);
            vm.deal(player, 10 ether);
        }
    }
    
    function testFullRaffleLifecycle() public {
        // 1. Multiple players enter the raffle
        for (uint8 i = 0; i < PLAYERS_COUNT; i++) {
            vm.prank(players[i]);
            raffle.enterRaffle{value: entranceFee}();
        }
        
        // 2. Time passes
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        
        // 3. Perform upkeep (which should trigger the request for random words)
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId;
        for (uint i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("RequestIdForWinner(uint256)")) {
                requestId = entries[i].topics[1];
                break;
            }
        }
        assertTrue(uint256(requestId) > 0, "Request ID should be emitted");
        
        // 4. Simulate callback from VRF Coordinator
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));
        
        // 5. Check the results
        address winner = raffle.getRecentWinner();
        assertTrue(winner != address(0), "Winner should be selected");
        assertTrue(raffle.getRaffleState() == Raffle.RaffleState.open, "Raffle should be open again");
        assertEq(raffle.getlastTimestamp(), block.timestamp, "Timestamp should be updated");
        assertEq(address(raffle).balance, 0, "Contract balance should be 0 after paying out");
    }
    
    function testRaffleResetAfterWinnerSelected() public {
        // Enter players and complete a raffle round
        testFullRaffleLifecycle();
        
        // Check that the raffle has been reset
        vm.expectRevert(); // Expect revert when trying to access player at index 0
        raffle.getPlayer(0);
        assertTrue(raffle.getRaffleState() == Raffle.RaffleState.open, "Raffle should be open");
    }
    
    function testMultipleRaffleRounds() public {
        for (uint8 round = 0; round < 3; round++) {
            // Enter players
            for (uint8 i = 0; i < PLAYERS_COUNT; i++) {
                vm.prank(players[i]);
                raffle.enterRaffle{value: entranceFee}();
            }
            
            // Time passes
            vm.warp(block.timestamp + interval + 1);
            vm.roll(block.number + 1);
            
            // Perform upkeep and fulfill random words
            vm.recordLogs();
            raffle.performUpkeep("");
            Vm.Log[] memory entries = vm.getRecordedLogs();
            bytes32 requestId;
            for (uint i = 0; i < entries.length; i++) {
                if (entries[i].topics[0] == keccak256("RequestIdForWinner(uint256)")) {
                    requestId = entries[i].topics[1];
                    break;
                }
            }
            assertTrue(uint256(requestId) > 0, "Request ID should be emitted");
            
            VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));
            
            // Check results
            assertTrue(raffle.getRecentWinner() != address(0), "Winner should be selected");
            assertTrue(raffle.getRaffleState() == Raffle.RaffleState.open, "Raffle should be open again");
            assertEq(address(raffle).balance, 0, "Contract balance should be 0 after paying out");
        }
    }
}