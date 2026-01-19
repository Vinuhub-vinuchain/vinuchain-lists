// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// OpenZeppelin Context
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// OpenZeppelin IERC20
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// OpenZeppelin IERC20Metadata
interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

// OpenZeppelin Ownable
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        _transferOwnership(initialOwner);
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

// StakingPool Contract
contract StakingPool is Ownable {
    IERC20 public stakeToken;
    uint256 public apr;
    uint256 public lockDays;
    uint256 public minStake;
    uint256 public totalStaked;
    uint256 public totalStakers;
    bool public paused;
    
    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public stakeTimestamp;
    mapping(address => uint256) public rewards;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event Paused(bool status);

    constructor(address _stakeToken, uint256 _apr, uint256 _lockDays, uint256 _minStake, address _creator) Ownable(_creator) {
        require(_stakeToken != address(0), "Invalid token address");
        require(_apr > 0, "APR must be positive");
        require(_lockDays > 0, "Lock days must be positive");
        require(_minStake > 0, "Minimum stake must be positive");
        stakeToken = IERC20(_stakeToken);
        apr = _apr;
        lockDays = _lockDays;
        minStake = _minStake;
    }

    modifier whenNotPaused() {
        require(!paused, "Pool is paused");
        _;
    }

    function pause(bool _status) external onlyOwner {
        paused = _status;
        emit Paused(_status);
    }

    function depositRewards(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be positive");
        stakeToken.transferFrom(msg.sender, address(this), amount);
    }

    function stake(uint256 amount) external whenNotPaused {
        require(amount >= minStake, "Amount below minimum stake");
        stakeToken.transferFrom(msg.sender, address(this), amount);
        if (stakedBalance[msg.sender] == 0) totalStakers++;
        stakedBalance[msg.sender] += amount;
        stakeTimestamp[msg.sender] = block.timestamp;
        totalStaked += amount;
        emit Staked(msg.sender, amount);
    }

    function unstake() external whenNotPaused {
        uint256 staked = stakedBalance[msg.sender];
        require(staked > 0, "No stake");
        require(block.timestamp >= stakeTimestamp[msg.sender] + (lockDays * 1 days), "Lock period not over");
        
        uint256 durationDays = (block.timestamp - stakeTimestamp[msg.sender]) / 1 days;
        uint256 reward = (staked * apr * durationDays) / (365 * 100);
        rewards[msg.sender] += reward;
        
        stakeToken.transfer(msg.sender, staked);
        stakedBalance[msg.sender] = 0;
        totalStaked -= staked;
        totalStakers--;
        emit Unstaked(msg.sender, staked);
    }

    function claimRewards() external whenNotPaused {
        uint256 reward = rewards[msg.sender];
        require(reward > 0, "No rewards");
        require(stakeToken.balanceOf(address(this)) >= reward, "Insufficient rewards");
        rewards[msg.sender] = 0;
        stakeToken.transfer(msg.sender, reward);
        emit RewardsClaimed(msg.sender, reward);
    }

    function getPendingRewards(address user) external view returns (uint256) {
        uint256 staked = stakedBalance[user];
        if (staked == 0) return rewards[user];
        uint256 durationDays = (block.timestamp - stakeTimestamp[user]) / 1 days;
        return rewards[user] + (staked * apr * durationDays) / (365 * 100);
    }
}

// StakingFactory Contract
contract StakingFactory {
    address[] public pools;
    mapping(address => address[]) public userPools;
    address public feeWallet;
    uint256 public constant CREATE_FEE = 5000 * 10**18; // 5000 VC in Wei (assuming 18 decimals)

    struct PoolInfo {
        address poolAddress;
        address stakeToken;
        uint256 apr;
        uint256 lockDays;
        uint256 minStake;
        string name;
        string description;
    }

    mapping(address => PoolInfo) public poolInfo;

    event PoolCreated(address indexed poolAddress, address creator, address token, uint256 apr, uint256 lockDays, uint256 minStake, string name, string description);

    constructor(address _feeWallet) {
        require(_feeWallet != address(0), "Invalid fee wallet");
        feeWallet = _feeWallet;
    }

    function createPool(
        address stakeToken,
        uint256 apr,
        uint256 lockDays,
        uint256 minStake,
        string calldata name,
        string calldata description
    ) external payable {
        require(apr > 0 && lockDays > 0 && minStake > 0, "Invalid parameters");
        require(msg.value == CREATE_FEE, "Must send 5000 VC");
        require(bytes(name).length <= 50, "Name too long");
        require(bytes(description).length <= 200, "Description too long");
        (bool sent, ) = feeWallet.call{value: msg.value}("");
        require(sent, "Fee transfer failed");
        StakingPool newPool = new StakingPool(stakeToken, apr, lockDays, minStake, msg.sender);
        address poolAddress = address(newPool);
        pools.push(poolAddress);
        userPools[msg.sender].push(poolAddress);
        poolInfo[poolAddress] = PoolInfo(poolAddress, stakeToken, apr, lockDays, minStake, name, description);
        emit PoolCreated(poolAddress, msg.sender, stakeToken, apr, lockDays, minStake, name, description);
    }

    function getAllPools() external view returns (address[] memory) {
        return pools;
    }

    function getUserPools(address user) external view returns (address[] memory) {
        return userPools[user];
    }

    function getPoolInfo(address poolAddress) external view returns (PoolInfo memory) {
        return poolInfo[poolAddress];
    }
}
