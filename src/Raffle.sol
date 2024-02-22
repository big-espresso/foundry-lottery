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
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

// forge install smartcontractkit/chainlink-brownie-contracts@0.6.1 --no-commit
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title Raffle
 * @author João Guerra
 * @notice This contract is part of my first lottery project.
 * @dev Implements Chainlink VRFv2 to generate random numbers.
 */

contract Raffle is VRFConsumerBaseV2 {
    // custom errors have better gas efficiency than using regular require statements
    // The way to use them is by calling the error function with the message you want to display in
    // case a certain condition is met.
    // and then using the revert function to revert the transaction
    error Raffle__NotEnoughEtherSent();
    error Raffle__TransferFailed();
    error Raffle__NotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );

    /**Type Declarations */
    enum RaffleState {
        OPEN, //0
        CALCULATING //1
    }

    uint32 private constant NUM_WORDS = 1;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    uint256 private immutable i_entranceFee;
    // @dev duration of the raffle in seconds
    uint256 private immutable i_interval;
    // SEPOLIA COORDINATOR 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callBackGasLimit;

    RaffleState s_raffleState;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;

    /** Events */

    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);

    // Because we extend VRFConsumerBaseV2 we need to pass the constructor arguments to the parent constructor
    constructor(
        uint64 subscriptionId,
        bytes32 gasLane, // keyHash
        uint256 interval,
        uint256 entranceFee,
        uint32 callbackGasLimit,
        address vrfCoordinatorV2
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_interval = interval;
        i_subscriptionId = subscriptionId;
        i_entranceFee = entranceFee;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_callbackGasLimit = callbackGasLimit;
        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(msg.sender).transfer(balance);
        }
    }

    function enterRaffle() external payable {
        // require(msg.value == i_entranceFee, "Not enough ether sent"); Less gas efficient
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEtherSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    /**
     * @dev This is the function that the ChainLink Automation nodes
     * call to see if it's time to upkeep.
     * To return true, the following should be verified:
     * 1. The time interval has passed between raffle runs
     * 2. The raffle is in the OPEN state
     * 3. The contract has ETH(players)
     * 4. The subscription is funded with LINK
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0");
    }

    //1. Get a random number from Chainlink VRF
    //2. Pick a winner
    //3. Be automatically called
    function performUpkeep(bytes calldata /* performData*/) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert("Raffle is still ongoing");
        }
        s_raffleState = RaffleState.CALCULATING;
        // Chainlink VRF
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, // gas lane
            i_subscriptionId, // subscription id
            REQUEST_CONFIRMATIONS,
            i_callBackGasLimit,
            NUM_WORDS
        );

        s_lastTimeStamp = block.timestamp;
    }

    // CEI -> Check, Effects, Interactions
    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;

        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit PickedWinner(winner);

        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /** Getter function */

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }
}
