// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// OpenZeppelin Contracts (last updated v4.9.0) (utils/Context.sol)
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(_msgSender());
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract VinuHubStaking is Ownable {
    IERC20 public vinToken; // VIN token address
    uint256 public minStake = 10 * 10**18; // 10 VIN, assuming 18 decimals
    uint256 public minLockPeriod = 7 days; // 7-day lock
    uint256 public rewardRate = 100; // 0.1% per day (100/10000 = 0.01)
    uint256 public penaltyRate = 1000; // 10% penalty for early unstake

    struct Stake {
        uint256 amount;
        uint256 timestamp;
        uint256 rewards;
    }

    struct LeaderboardEntry {
        address user;
        uint256 amount;
    }

    mapping(address => Stake) public stakes;
    LeaderboardEntry[] public leaderboard; // Array to store top stakers
    uint256 public constant MAX_LEADERBOARD_SIZE = 5; // Top 5 stakers

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 rewards);
    event EmergencyUnstaked(address indexed user, uint256 amount, uint256 penalty);

    constructor(address _vinToken) {
        vinToken = IERC20(_vinToken);
    }

    function stake(uint256 _amount) external {
        require(_amount >= minStake, "Below minimum stake");
        vinToken.transferFrom(msg.sender, address(this), _amount);
        Stake storage s = stakes[msg.sender];
        if (s.amount > 0) {
            s.rewards += calculateRewards(msg.sender);
        }
        s.amount += _amount;
        s.timestamp = block.timestamp;
        updateLeaderboard(msg.sender, s.amount);
        emit Staked(msg.sender, _amount);
    }

    function unstake() external {
        Stake storage s = stakes[msg.sender];
        require(s.amount > 0, "No stake");
        require(block.timestamp >= s.timestamp + minLockPeriod, "Lock period not over");
        uint256 rewards = calculateRewards(msg.sender) + s.rewards;
        uint256 total = s.amount + rewards;
        s.amount = 0;
        s.rewards = 0;
        s.timestamp = 0;
        updateLeaderboard(msg.sender, 0);
        vinToken.transfer(msg.sender, total);
        emit Unstaked(msg.sender, s.amount, rewards);
    }

    function emergencyUnstake() external {
        Stake storage s = stakes[msg.sender];
        require(s.amount > 0, "No stake");
        uint256 rewards = calculateRewards(msg.sender) + s.rewards;
        uint256 penalty = (s.amount * penaltyRate) / 10000;
        uint256 total = s.amount + rewards - penalty;
        s.amount = 0;
        s.rewards = 0;
        s.timestamp = 0;
        updateLeaderboard(msg.sender, 0);
        vinToken.transfer(msg.sender, total);
        emit EmergencyUnstaked(msg.sender, s.amount, penalty);
    }

    function calculateRewards(address _user) public view returns (uint256) {
        Stake memory s = stakes[_user];
        if (s.amount == 0) return 0;
        uint256 timeStaked = block.timestamp - s.timestamp;
        return (s.amount * rewardRate * timeStaked) / (10000 * 1 days);
    }

    function getStakeInfo(address _user) external view returns (uint256 amount, uint256 lockTimeLeft, uint256 rewards) {
        Stake memory s = stakes[_user];
        amount = s.amount;
        lockTimeLeft = s.timestamp + minLockPeriod > block.timestamp ? (s.timestamp + minLockPeriod - block.timestamp) : 0;
        rewards = calculateRewards(_user) + s.rewards;
    }

    function updateLeaderboard(address _user, uint256 _amount) internal {
        // Remove existing entry for user
        for (uint256 i = 0; i < leaderboard.length; i++) {
            if (leaderboard[i].user == _user) {
                leaderboard[i] = leaderboard[leaderboard.length - 1];
                leaderboard.pop();
                break;
            }
        }
        // Add new entry if amount > 0
        if (_amount > 0) {
            leaderboard.push(LeaderboardEntry(_user, _amount));
        }
        // Sort leaderboard (bubble sort for simplicity, small array)
        for (uint256 i = 0; i < leaderboard.length; i++) {
            for (uint256 j = 0; j < leaderboard.length - i - 1; j++) {
                if (leaderboard[j].amount < leaderboard[j + 1].amount) {
                    LeaderboardEntry memory temp = leaderboard[j];
                    leaderboard[j] = leaderboard[j + 1];
                    leaderboard[j + 1] = temp;
                }
            }
        }
        // Trim to MAX_LEADERBOARD_SIZE
        while (leaderboard.length > MAX_LEADERBOARD_SIZE) {
            leaderboard.pop();
        }
    }

    function getLeaderboard() external view returns (address[] memory users, uint256[] memory amounts) {
        users = new address[](leaderboard.length);
        amounts = new uint256[](leaderboard.length);
        for (uint256 i = 0; i < leaderboard.length; i++) {
            users[i] = leaderboard[i].user;
            amounts[i] = leaderboard[i].amount;
        }
        return (users, amounts);
    }
}

