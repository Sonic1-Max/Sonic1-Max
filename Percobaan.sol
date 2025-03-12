// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/security/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/security/Pausable.sol";

/// @title otakudump Token Contract
/// @notice An ERC-20 token with burn, anti-whale, and owner LP auto-unlocking features
/// @dev Built for BSC with enhanced security and liquidity locking
contract otakudump is ERC20, Ownable, ReentrancyGuard, Pausable {
    
    /// @notice Maximum supply of otakudump tokens (121 trillion)
    uint256 public constant MAX_SUPPLY = 121_000_000_000_000 * 10**18;
    bool public isMinted = false;

    /// @notice Burn rate (0.5% per transaction)
    uint256 public constant BURN_RATE = 50; // 0.5%
    /// @notice Maximum tokens that can be burned (50 trillion)
    uint256 public constant MAX_BURN_AMOUNT = 50_000_000_000_000 * 10**18;
    uint256 public totalBurned = 0;
    bool public burnEnabled = true;
    bool public burnPermanentlyDisabled = false;

    /// @notice Maximum transaction amount (7% of remaining supply)
    function getMaxTxAmount() public view returns (uint256) {
        return (MAX_SUPPLY - totalBurned) * 7 / 100;
    }

    /// @notice Liquidity locking structure
    struct LiquidityLock {
        uint256 amount;
        uint256 lockTime;  // Changed from unlockTime to lockTime
        bool isOwnerLocked;
    }

    /// @notice Mapping for locked liquidity
    mapping(address => LiquidityLock[]) public lockedLiquidity;
    uint256 public totalLockedLiquidity;

    /// @notice Duration for owner LP lock (365 days in seconds)
    uint256 public constant OWNER_LOCK_DURATION = 365 days;

    /// @notice Events
    event TokensBurned(address indexed burner, uint256 amount);
    event BurnToggled(bool enabled);
    event BurnPermanentlyDisabled();
    event LiquidityLocked(address indexed locker, uint256 amount, uint256 lockTime);
    event LiquidityWithdrawn(address indexed withdrawer, uint256 amount);

    constructor() ERC20("otakudump", "OTD") {
        require(!isMinted, "Tokens already minted");
        _mint(msg.sender, MAX_SUPPLY);
        isMinted = true;
    }

    /// @notice Transfers tokens with burn logic for non-transfer transactions
    function transfer(address to, uint256 amount) public virtual override nonReentrant whenNotPaused returns (bool) {
        require(to != address(0), "Cannot transfer to zero address");
        require(amount <= getMaxTxAmount(), "Amount exceeds max tx limit");

        // No burn on regular transfers
        return super.transfer(to, amount);
    }

    /// @notice Transfers tokens from one address to another with burn logic
    function transferFrom(address from, address to, uint256 amount) public virtual override nonReentrant whenNotPaused returns (bool) {
        require(amount <= getMaxTxAmount(), "Amount exceeds max tx limit");

        if (burnEnabled && !burnPermanentlyDisabled && BURN_RATE > 0) {
            uint256 burnAmount = (amount * BURN_RATE) / 10000;
            uint256 transferAmount = amount - burnAmount;

            if (burnAmount > 0 && totalBurned + burnAmount <= MAX_BURN_AMOUNT) {
                _burn(from, burnAmount);
                totalBurned += burnAmount;
                emit TokensBurned(from, burnAmount);
            } else if (burnAmount > 0) {
                burnAmount = MAX_BURN_AMOUNT - totalBurned;
                if (burnAmount > 0) {
                    _burn(from, burnAmount);
                    totalBurned += burnAmount;
                    emit TokensBurned(from, burnAmount);
                }
                transferAmount = amount - burnAmount;
            }
            return super.transferFrom(from, to, transferAmount);
        }
        return super.transferFrom(from, to, amount);
    }

    /// @notice Burns tokens manually (only owner)
    function burn(uint256 amount) public onlyOwner whenNotPaused {
        require(amount <= getMaxTxAmount(), "Amount exceeds max tx limit");
        require(totalBurned + amount <= MAX_BURN_AMOUNT, "Exceeds max burn limit");
        require(burnEnabled && !burnPermanentlyDisabled, "Burn feature is disabled");
        _burn(msg.sender, amount);
        totalBurned += amount;
        emit TokensBurned(msg.sender, amount);
    }

    /// @notice Locks liquidity tokens
    function lockLiquidity(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        require(amount <= getMaxTxAmount(), "Amount exceeds max tx limit");
        
        uint256 lockTime = block.timestamp;
        bool isOwnerLocked = false;
        
        // If owner is locking, mark it as owner-locked
        if (msg.sender == owner()) {
            isOwnerLocked = true;
        }

        _transfer(msg.sender, address(this), amount);
        
        lockedLiquidity[msg.sender].push(LiquidityLock({
            amount: amount,
            lockTime: lockTime,
            isOwnerLocked: isOwnerLocked
        }));
        
        totalLockedLiquidity += amount;
        emit LiquidityLocked(msg.sender, amount, lockTime);
    }

    /// @notice Withdraws available liquidity tokens
    function withdrawLiquidity(uint256 index) external nonReentrant whenNotPaused {
        require(index < lockedLiquidity[msg.sender].length, "Invalid lock index");
        
        LiquidityLock storage lock = lockedLiquidity[msg.sender][index];
        require(lock.amount > 0, "No liquidity to withdraw");
        
        // Check if owner lock period has passed (365 days)
        if (lock.isOwnerLocked) {
            require(block.timestamp >= lock.lockTime + OWNER_LOCK_DURATION, "Liquidity is still locked");
        }

        uint256 amount = lock.amount;
        totalLockedLiquidity -= amount;
        
        // Remove the lock by swapping with the last element and popping
        lockedLiquidity[msg.sender][index] = lockedLiquidity[msg.sender][lockedLiquidity[msg.sender].length - 1];
        lockedLiquidity[msg.sender].pop();
        
        _transfer(address(this), msg.sender, amount);
        emit LiquidityWithdrawn(msg.sender, amount);
    }

    /// @notice Gets user's locked liquidity details
    function getLockedLiquidity(address account) external view returns (LiquidityLock[] memory) {
        return lockedLiquidity[account];
    }

    /// @notice Checks if liquidity can be withdrawn at a specific index
    function canWithdrawLiquidity(address account, uint256 index) external view returns (bool) {
        if (index >= lockedLiquidity[account].length) return false;
        
        LiquidityLock memory lock = lockedLiquidity[account][index];
        if (lock.amount == 0) return false;
        
        if (lock.isOwnerLocked) {
            return block.timestamp >= lock.lockTime + OWNER_LOCK_DURATION;
        }
        return true;
    }

    /// @notice Toggles the burn feature (only owner)
    function toggleBurn(bool enabled) external onlyOwner {
        require(!burnPermanentlyDisabled, "Burn feature is permanently disabled");
        burnEnabled = enabled;
        emit BurnToggled(enabled);
    }

    /// @notice Permanently disables the burn feature (only owner)
    function disableBurnPermanently() external onlyOwner {
        require(burnEnabled, "Burn feature is already disabled");
        burnEnabled = false;
        burnPermanentlyDisabled = true;
        emit BurnPermanentlyDisabled();
    }

    /// @notice Pauses the contract (only owner)
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract (only owner)
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Gets tokenomics statistics
    function getTokenomics() external view returns (uint256, uint256, uint256) {
        return (MAX_SUPPLY, totalBurned, totalLockedLiquidity);
    }

    /// @notice Prevents direct BNB deposits
    receive() external payable {
        revert("Contract does not accept direct BNB");
    }
}
