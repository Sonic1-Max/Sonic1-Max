// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// Impor dari GitHub OpenZeppelin versi 4.9.3
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/security/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/security/Pausable.sol";

/// @title Sonic Token Contract
/// @notice An ERC-20 token with burn, reflection, anti-whale, and investor-friendly features
/// @dev Built for BSC with enhanced security, transparency, and liquidity locking
contract Sonic is ERC20, Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    /// @notice Maximum supply of Sonic tokens (121 trillion)
    uint256 public constant MAX_SUPPLY = 121_000_000_000_000 * 10**18;
    bool public isMinted = false;

    /// @notice Burn rate (0.5% per transaction to DEX)
    uint256 public constant BURN_RATE = 50;
    /// @notice Maximum tokens that can be burned (30 trillion)
    uint256 public constant MAX_BURN_AMOUNT = 30_000_000_000_000 * 10**18;
    uint256 public totalBurned = 0;
    bool public burnEnabled = true; // Toggle for burn feature
    bool public burnPermanentlyDisabled = false; // Permanent burn disable flag

    /// @notice Maximum transaction amount (5% of total supply)
    uint256 public constant MAX_TX_AMOUNT = MAX_SUPPLY / 20;

    /// @notice Reward rate for holders (0.2% of burn amount)
    uint256 public constant REWARD_RATE = 20;
    uint256 public totalReflections = 0;
    mapping(address => uint256) public reflectionBalances;
    mapping(address => uint256) public lastUpdated;

    /// @notice Mapping for DEX pairs
    mapping(address => bool) public dexPairs;

    /// @notice Mapping for locked liquidity
    mapping(address => uint256) public lockedLiquidity;
    uint256 public totalLockedLiquidity;

    /// @notice Placeholder for staking contract address
    address public stakingContract;

    /// @notice Event emitted when tokens are burned
    event TokensBurned(address indexed burner, uint256 amount);
    /// @notice Event emitted when rewards are distributed
    event RewardsDistributed(uint256 amount);
    /// @notice Event emitted when burn feature is toggled
    event BurnToggled(bool enabled);
    /// @notice Event emitted when burn is permanently disabled
    event BurnPermanentlyDisabled();
    /// @notice Event emitted when liquidity is burned
    event LiquidityBurned(address indexed burner, uint256 amount);
    /// @notice Event emitted when liquidity is locked
    event LiquidityLocked(address indexed locker, uint256 amount);
    /// @notice Event emitted when staking contract is set
    event StakingContractSet(address indexed stakingContract);

    /// @notice Constructor to initialize the contract
    /// @param _initialDexPair The initial DEX pair address
    constructor(address _initialDexPair) ERC20("Sonic", "SNC") {
        require(!isMinted, "Tokens already minted");
        require(_initialDexPair != address(0), "Invalid initial DEX pair");
        _mint(msg.sender, MAX_SUPPLY);
        isMinted = true;
        dexPairs[_initialDexPair] = true;
    }

    /// @notice Updates reflection balance for an account
    /// @param account The account to update
    function _updateReflection(address account) internal {
        if (lastUpdated[account] < block.timestamp && totalReflections > 0) {
            uint256 currentBalance = super.balanceOf(account);
            if (currentBalance > 0) {
                uint256 share = (currentBalance * totalReflections) / (MAX_SUPPLY - totalBurned);
                reflectionBalances[account] += share;
            }
            lastUpdated[account] = block.timestamp;
        }
    }

    /// @notice Returns the balance of an account including reflections
    /// @param account The account to check
    function balanceOf(address account) public view virtual override returns (uint256) {
        uint256 baseBalance = super.balanceOf(account);
        uint256 reflection = reflectionBalances[account];
        if (baseBalance > 0 && totalReflections > reflectionBalances[account]) {
            uint256 share = (baseBalance * totalReflections) / (MAX_SUPPLY - totalBurned);
            reflection = share > reflectionBalances[account] ? share : reflectionBalances[account];
        }
        return baseBalance + reflection;
    }

    /// @notice Transfers tokens with burn and reflection logic
    /// @param to The recipient address
    /// @param amount The amount to transfer
    function transfer(address to, uint256 amount) public virtual override nonReentrant whenNotPaused returns (bool) {
        require(to != address(0), "Cannot transfer to zero address");
        require(amount <= MAX_TX_AMOUNT, "Amount exceeds max tx limit");

        _updateReflection(msg.sender);
        _updateReflection(to);

        if (dexPairs[to] && BURN_RATE > 0 && !isContract(msg.sender) && burnEnabled && !burnPermanentlyDisabled) {
            uint256 burnAmount = (amount * BURN_RATE) / 10000;
            uint256 rewardAmount = (burnAmount * REWARD_RATE) / 100;
            uint256 netBurnAmount = burnAmount - rewardAmount;
            uint256 transferAmount = amount - burnAmount;

            if (netBurnAmount > 0 && totalBurned + netBurnAmount <= MAX_BURN_AMOUNT) {
                _burn(msg.sender, netBurnAmount);
                totalBurned += netBurnAmount;
                emit TokensBurned(msg.sender, netBurnAmount);
            } else if (netBurnAmount > 0) {
                netBurnAmount = MAX_BURN_AMOUNT - totalBurned;
                if (netBurnAmount > 0) {
                    _burn(msg.sender, netBurnAmount);
                    totalBurned += netBurnAmount;
                    emit TokensBurned(msg.sender, netBurnAmount);
                }
            }
            if (rewardAmount > 0) {
                totalReflections += rewardAmount;
                emit RewardsDistributed(rewardAmount);
            }
            return super.transfer(to, transferAmount);
        }
        return super.transfer(to, amount);
    }

    /// @notice Transfers tokens from one address to another
    /// @param from The sender address
    /// @param to The recipient address
    /// @param amount The amount to transfer
    function transferFrom(address from, address to, uint256 amount) public virtual override nonReentrant whenNotPaused returns (bool) {
        require(amount <= MAX_TX_AMOUNT, "Amount exceeds max tx limit");

        _updateReflection(from);
        _updateReflection(to);

        if (dexPairs[to] && BURN_RATE > 0 && !isContract(from) && burnEnabled && !burnPermanentlyDisabled) {
            uint256 burnAmount = (amount * BURN_RATE) / 10000;
            uint256 rewardAmount = (burnAmount * REWARD_RATE) / 100;
            uint256 netBurnAmount = burnAmount - rewardAmount;
            uint256 transferAmount = amount - burnAmount;

            if (netBurnAmount > 0 && totalBurned + netBurnAmount <= MAX_BURN_AMOUNT) {
                _burn(from, netBurnAmount);
                totalBurned += netBurnAmount;
                emit TokensBurned(from, netBurnAmount);
            } else if (netBurnAmount > 0) {
                netBurnAmount = MAX_BURN_AMOUNT - totalBurned;
                if (netBurnAmount > 0) {
                    _burn(from, netBurnAmount);
                    totalBurned += netBurnAmount;
                    emit TokensBurned(from, netBurnAmount);
                }
            }
            if (rewardAmount > 0) {
                totalReflections += rewardAmount;
                emit RewardsDistributed(rewardAmount);
            }
            return super.transferFrom(from, to, transferAmount);
        }
        return super.transferFrom(from, to, amount);
    }

    /// @notice Burns tokens manually (only owner)
    /// @param amount The amount to burn
    function burn(uint256 amount) public onlyOwner whenNotPaused {
        require(amount <= MAX_TX_AMOUNT, "Amount exceeds max tx limit");
        require(totalBurned + amount <= MAX_BURN_AMOUNT, "Exceeds max burn limit");
        require(burnEnabled && !burnPermanentlyDisabled, "Burn feature is disabled");
        _updateReflection(msg.sender);
        _burn(msg.sender, amount);
        totalBurned += amount;
        emit TokensBurned(msg.sender, amount);
    }

    /// @notice Burns liquidity tokens and locks them (only owner)
    /// @param amount The amount of liquidity tokens to burn and lock
    function burnAndLockLiquidity(uint256 amount) external onlyOwner whenNotPaused {
        require(amount <= MAX_TX_AMOUNT, "Amount exceeds max tx limit");
        require(totalBurned + amount <= MAX_BURN_AMOUNT, "Exceeds max burn limit");
        require(burnEnabled && !burnPermanentlyDisabled, "Burn feature is disabled");
        _updateReflection(msg.sender);
        _burn(msg.sender, amount);
        totalBurned += amount;
        lockedLiquidity[msg.sender] += amount;
        totalLockedLiquidity += amount;
        emit LiquidityBurned(msg.sender, amount);
        emit LiquidityLocked(msg.sender, amount);
    }

    /// @notice Toggles the burn feature (only owner)
    /// @param enabled True to enable, false to disable
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

    /// @notice Adds a new DEX pair (only owner)
    /// @param dexPair The address of the DEX pair
    function addDexPair(address dexPair) external onlyOwner {
        require(dexPair != address(0), "Invalid DEX pair address");
        dexPairs[dexPair] = true;
    }

    /// @notice Removes a DEX pair (only owner)
    /// @param dexPair The address of the DEX pair
    function removeDexPair(address dexPair) external onlyOwner {
        require(dexPairs[dexPair], "DEX pair not found");
        dexPairs[dexPair] = false;
    }

    /// @notice Sets the staking contract address (only owner)
    /// @param _stakingContract The address of the staking contract
    function setStakingContract(address _stakingContract) external onlyOwner {
        require(_stakingContract != address(0), "Invalid staking contract address");
        stakingContract = _stakingContract;
        emit StakingContractSet(_stakingContract);
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
    /// @return Total supply, total burned, total reflections, total locked liquidity
    function getTokenomics() external view returns (uint256, uint256, uint256, uint256) {
        return (MAX_SUPPLY, totalBurned, totalReflections, totalLockedLiquidity);
    }

    /// @notice Checks if an address is a contract
    /// @param account The address to check
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /// @notice Prevents direct BNB deposits
    receive() external payable {
        revert("Contract does not accept direct BNB");
    }
}
