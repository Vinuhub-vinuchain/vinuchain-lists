// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract VinuPredictionMarketGlobal {
    IERC20 public immutable vinToken = IERC20(0x6109835364EdA2c43CaA8981681e75782C13566C);
    address public admin;
    uint256 public globalPool;

    struct Market {
        string question;
        string description;
        uint256 endTime;
        uint256 oddsYes;        // e.g. 185 = 1.85x
        uint256 oddsNo;         // e.g. 210 = 2.10x
        uint256 totalYes;
        uint256 totalNo;
        uint256 betCount;
        bool resolved;
        bool outcome;           // true = Yes won
    }

    Market[] public markets;

    mapping(uint256 => mapping(address => uint256)) public betsYes;
    mapping(uint256 => mapping(address => uint256)) public betsNo;

    event MarketCreated(uint256 indexed marketId, string question);
    event BetPlaced(uint256 indexed marketId, address indexed user, bool yes, uint256 amount);
    event MarketResolved(uint256 indexed marketId, bool outcome);
    event Claimed(uint256 indexed marketId, address indexed user, uint256 payout);
    event PoolFunded(uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    // Admin funds the global pool
    function fundPool(uint256 amount) external onlyAdmin {
        require(vinToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        globalPool += amount;
        emit PoolFunded(amount);
    }

    function createMarket(
        string memory question,
        string memory description,
        uint256 endTime,
        uint256 oddsYes,
        uint256 oddsNo
    ) external onlyAdmin {
        require(endTime > block.timestamp, "End time must be future");
        require(oddsYes > 100 && oddsNo > 100, "Odds > 1.0x");

        markets.push(Market({
            question: question,
            description: description,
            endTime: endTime,
            oddsYes: oddsYes,
            oddsNo: oddsNo,
            totalYes: 0,
            totalNo: 0,
            betCount: 0,
            resolved: false,
            outcome: false
        }));

        emit MarketCreated(markets.length - 1, question);
    }

    function placeBet(uint256 marketId, bool yes, uint256 amount) external {
        Market storage m = markets[marketId];
        require(block.timestamp < m.endTime, "Market ended");
        require(!m.resolved, "Already resolved");
        require(amount > 0, "Amount > 0");

        require(vinToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        if (yes) {
            m.totalYes += amount;
            betsYes[marketId][msg.sender] += amount;
        } else {
            m.totalNo += amount;
            betsNo[marketId][msg.sender] += amount;
        }
        m.betCount++;

        emit BetPlaced(marketId, msg.sender, yes, amount);
    }

    function resolveMarket(uint256 marketId, bool outcome) external onlyAdmin {
        Market storage m = markets[marketId];
        require(block.timestamp >= m.endTime, "Not ended");
        require(!m.resolved, "Already resolved");

        m.resolved = true;
        m.outcome = outcome;
        emit MarketResolved(marketId, outcome);
    }

    function claim(uint256 marketId) external {
        Market storage m = markets[marketId];
        require(m.resolved, "Not resolved");

        uint256 userBet = m.outcome ? betsYes[marketId][msg.sender] : betsNo[marketId][msg.sender];
        require(userBet > 0, "No winning bet");

        uint256 totalWinning = m.outcome ? m.totalYes : m.totalNo;
        require(totalWinning > 0, "No winners");

        // Proportional payout from global pool
        uint256 payoutFromPool = (userBet * globalPool) / totalWinning;
        uint256 totalPayout = userBet + payoutFromPool;

        globalPool -= payoutFromPool;

        // Reset user bet
        if (m.outcome) betsYes[marketId][msg.sender] = 0;
        else betsNo[marketId][msg.sender] = 0;

        require(vinToken.transfer(msg.sender, totalPayout), "Transfer failed");
        emit Claimed(marketId, msg.sender, totalPayout);
    }

    // View functions
    function getMarketsCount() external view returns (uint256) {
        return markets.length;
    }

    function getUserVINBalance(address user) external view returns (uint256) {
        return vinToken.balanceOf(user);
    }

    function getContractVINBalance() external view returns (uint256) {
        return vinToken.balanceOf(address(this));
    }
}
