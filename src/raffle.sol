// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title Raffle
 * @author Hussain Shafique
 * @notice A smart contract for raffle
 * @dev It uses the chainlink VRF to generate random numbers
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle__SendMoreEthToEnterRaffle();
    error Raffle__TransactionFailed();
    error Raffle__RaffleIsClosed();
    error Raffle__upKeepNotNeeded(
        uint256 contractBalance,
        uint256 playersLength,
        uint256 raffleState
    );

    /* Type Declarations */
    enum RaffleState {
        open, //0
        calculating //1
    }

    /* State Variables */
    uint16 private constant REQUESTCONFIRMATIONS = 3;
    uint32 private constant NUMWORDS = 1;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_keyHash;
    uint32 private immutable i_callbackGasLimit;
    uint256 private immutable i_interval; // @dev The duration of the lottery in seconds
    address payable[] private s_players;
    address private s_recentWinner;
    uint256 private s_lastTimestamp;
    RaffleState private s_raffleState;

    /* Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestIdForWinner(uint256 indexed requestId);

    /* Constructor */
    constructor(
        uint256 _entranceFee,
        uint256 _interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = _entranceFee;
        i_interval = _interval;
        i_subscriptionId = subId;
        i_keyHash = gasLane;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimestamp = block.timestamp;
        s_raffleState = RaffleState.open;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreEthToEnterRaffle();
        }
        if (s_raffleState != RaffleState.open) {
            revert Raffle__RaffleIsClosed();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    /**
     * @dev This is the function that the Chainlink nodes will call to see
     * if the lottery is ready to have a winner picked
     * The following should be true in order for upKeepNeeded to be true:
     * 1. The time interval has passed between the raffle runs
     * 2. The lottery is open
     * 3. The contract has ETH(the contract has players)
     * 4. Implicitly, your subscription has LINK
     */
    function checkUpKeep(
        bytes memory /* data */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = ((block.timestamp - s_lastTimestamp) >=
            i_interval);
        bool isOpen = (s_raffleState == RaffleState.open);
        bool hasPlayers = (s_players.length > 0);
        bool hasBalance = (address(this).balance > 0);
        upkeepNeeded = timeHasPassed && isOpen && hasPlayers && hasBalance; // True if its time to restart the lottery
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata /* performData */) external {
        //check to see if upKeepNeeded is true
        (bool upKeepNeeded, ) = checkUpKeep("");
        if (!upKeepNeeded) {
            revert Raffle__upKeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.calculating;
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUESTCONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUMWORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit RequestIdForWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] calldata randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;

        s_raffleState = RaffleState.open;
        s_players = new address payable[](0);
        s_lastTimestamp = block.timestamp;

        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransactionFailed();
        }
        emit WinnerPicked(s_recentWinner);
    }

    /* Getter Functions */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getlastTimestamp() public view returns (uint256) {
        return s_lastTimestamp;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }
}
