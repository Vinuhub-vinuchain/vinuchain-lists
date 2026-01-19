// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Context provides information about the current execution context
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// Ownable provides basic access control, with an owner that can transfer ownership
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

// IERC20 defines the standard ERC20 interface
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// SafeERC20 provides safe operations for ERC20 tokens
library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require((value == 0) || (token.allowance(address(this), spender) == 0), "SafeERC20: approve from non-zero to non-zero allowance");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

contract VinuHubCoinFlip is Ownable {
    IERC20 public vinToken = IERC20(0x6109835364EdA2c43CaA8981681e75782C13566C); // VIN token address on VinuChain
    uint256 public houseEdge = 1; // 1% skim
    uint256 public minBet = 0.1 ether; // 0.1 VIN (18 decimals)
    uint256 public maxBet = 100000 ether; // 100000 VIN
    uint256 public constant MULTIPLIER = 198; // 99x payout (after 1% edge)
    mapping(address => uint256) public playerBalances;
    mapping(address => uint256) public nonces;

    event FlipResult(address indexed player, bool heads, bool won, uint256 bet, uint256 payout);
    event Withdrawal(address indexed player, uint256 amount);

    constructor() payable {}

    // Simple randomness using blockhash, timestamp, and nonce
    function getRandomBool(address player) internal returns (bool) {
        nonces[player]++;
        bytes32 hash = keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp, player, nonces[player]));
        return uint256(hash) % 2 == 0; // 0 = heads, 1 = tails
    }

    // Player flips coin (requires prior approval of VIN)
    function flip(bool _heads, uint256 _amount) external {
        require(_amount >= minBet, "Bet too low");
        require(_amount <= maxBet, "Bet too high");
        require(_amount <= vinToken.balanceOf(msg.sender), "Insufficient VIN balance");
        require(vinToken.allowance(msg.sender, address(this)) >= _amount, "Approve VIN first");

        bool heads = getRandomBool(msg.sender);
        bool won = (heads == _heads);
        uint256 payout = won ? (_amount * MULTIPLIER) / 100 : 0;

        SafeERC20.safeTransferFrom(vinToken, msg.sender, address(this), _amount);
        if (won) {
            playerBalances[msg.sender] += payout;
        }

        emit FlipResult(msg.sender, heads, won, _amount, payout);
    }

    // Withdraw winnings (in VIN)
    function withdraw() external {
        uint256 amount = playerBalances[msg.sender];
        require(amount > 0, "No balance");
        playerBalances[msg.sender] = 0;
        SafeERC20.safeTransfer(vinToken, msg.sender, amount);
        emit Withdrawal(msg.sender, amount);
    }

    // Owner functions
    function fund(uint256 _amount) external onlyOwner {
        SafeERC20.safeTransferFrom(vinToken, msg.sender, address(this), _amount);
    }
    function setMinBet(uint256 _minBet) external onlyOwner { minBet = _minBet; }
    function setMaxBet(uint256 _maxBet) external onlyOwner { maxBet = _maxBet; }
}
