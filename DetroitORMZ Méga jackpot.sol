
 // SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract DetroitORMZMegaJackpot is VRFConsumerBaseV2Plus {
    using SafeERC20 for IERC20;

    IERC20 public immutable ormz;
    address public immutable owner;

    uint256 public constant ENTRY_FEE = 100000 ether;
    uint256 public constant PROJECT_FEE_BPS = 500;
    uint256 public constant BPS = 10000;

    uint256 public immutable subscriptionId;
    bytes32 public constant KEY_HASH =
        0x00b81b5a830cb0a4009fbd8904de511e28631e62ce5ad231373d3cdad373ccab;

    uint16 public constant REQUEST_CONFIRMATIONS = 3;
    uint32 public constant CALLBACK_GAS_LIMIT = 200000;

    uint256 public roundId = 1;
    uint256 public jackpot;
    uint256 public projectFees;
    uint256 public currentRequestId;

    address[] public players;
    mapping(address => uint256) public lastJoinedRound;
    mapping(uint256 => uint256) public requestRound;

    bool public drawing;
    bool public paused;

    event PlayerJoined(address indexed player);
    event PointsAwarded(address indexed player, uint256 amount);
    event DrawRequested(uint256 indexed requestId, uint256 indexed round);
    event WinnerSelected(
        uint256 indexed round,
        address indexed winner,
        uint256 prize
    );
    event FeesWithdrawn(address indexed recipient, uint256 amount);
    event PauseChanged(bool paused);

    modifier onlyOwner() {
        require(msg.sender == owner, "Owner only");
        _;
    }

    constructor(uint256 _subscriptionId)
        VRFConsumerBaseV2Plus(
            0xd5D517aBE5cF79B7e95eC98dB0f0277788aFF634
        )
    {
        owner = msg.sender;
        ormz = IERC20(
            0xe1e3B49c656896c61383Fc8b0B7c33cCc101B11E
        );
        subscriptionId = _subscriptionId;
    }

    function join() external {
        require(!paused, "Jackpot paused");
        require(!drawing, "Draw in progress");
        require(
            lastJoinedRound[msg.sender] != roundId,
            "Already joined"
        );

        uint256 fee = (ENTRY_FEE * PROJECT_FEE_BPS) / BPS;
        uint256 prizeContribution = ENTRY_FEE - fee;

        ormz.safeTransferFrom(
            msg.sender,
            address(this),
            ENTRY_FEE
        );

        projectFees += fee;
        jackpot += prizeContribution;
        lastJoinedRound[msg.sender] = roundId;
        players.push(msg.sender);

        emit PlayerJoined(msg.sender);
        emit PointsAwarded(msg.sender, ENTRY_FEE);
    }

    function requestDraw() external onlyOwner {
        require(!paused, "Jackpot paused");
        require(!drawing, "Draw already in progress");
        require(players.length >= 2, "Need at least 2 players");
        require(jackpot > 0, "Empty jackpot");

        drawing = true;

        uint256 requestId = s_vrfCoordinator
            .requestRandomWords(
                VRFV2PlusClient.RandomWordsRequest({
                    keyHash: KEY_HASH,
                    subId: subscriptionId,
                    requestConfirmations: REQUEST_CONFIRMATIONS,
                    callbackGasLimit: CALLBACK_GAS_LIMIT,
                    numWords: 1,
                    extraArgs: VRFV2PlusClient._argsToBytes(
                        VRFV2PlusClient.ExtraArgsV1({
                            nativePayment: true
                        })
                    )
                })
            );

        currentRequestId = requestId;
        requestRound[requestId] = roundId;

        emit DrawRequested(requestId, roundId);
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        if (
            !drawing ||
            requestId != currentRequestId ||
            requestRound[requestId] != roundId ||
            players.length < 2 ||
            randomWords.length == 0
        ) {
            return;
        }

        uint256 winningRound = roundId;
        uint256 winnerIndex = randomWords[0] % players.length;
        address winner = players[winnerIndex];
        uint256 prize = jackpot;

        // Update state before transferring tokens.
        delete players;
        jackpot = 0;
        drawing = false;
        currentRequestId = 0;
        roundId++;

        ormz.safeTransfer(winner, prize);

        emit WinnerSelected(winningRound, winner, prize);
    }

    function withdrawProjectFees(
        address recipient,
        uint256 amount
    ) external onlyOwner {
        require(recipient != address(0), "Zero recipient");
        require(!drawing, "Draw in progress");
        require(amount <= projectFees, "Exceeds fees");

        projectFees -= amount;
        ormz.safeTransfer(recipient, amount);

        emit FeesWithdrawn(recipient, amount);
    }

    function setPaused(bool value) external onlyOwner {
        require(!drawing || value, "Draw in progress");
        paused = value;
        emit PauseChanged(value);
    }

    function getPlayers()
        external
        view
        returns (address[] memory)
    {
        return players;
    }

    function playerCount() external view returns (uint256) {
        return players.length;
    }
}
