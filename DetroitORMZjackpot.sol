// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract DetroitORMZJackpot {
    string public name = "Detroit ORMZ Jackpot";
    string public symbol = "ORMZJ";
    address public owner;

    uint256 public totalPlayers;
    uint256 public totalRewards;

    mapping(address => uint256) public points;

    event PlayerJoined(address indexed player);
    event PointsAwarded(address indexed player, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Owner only");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function joinGame() external {
        require(points[msg.sender] == 0, "Already joined");
        points[msg.sender] = 1;
        totalPlayers++;
        emit PlayerJoined(msg.sender);
    }

    function awardPoints(
        address player,
        uint256 amount
    ) external onlyOwner {
        require(player != address(0), "Invalid address");
        require(amount > 0, "Amount must be positive");

        points[player] += amount;
        totalRewards += amount;

        emit PointsAwarded(player, amount);
    }

    function getPoints(
        address player
    ) external view returns (uint256) {
        return points[player];
    }
}
