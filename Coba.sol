// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Interface untuk IERC20
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// Interface untuk IERC20Metadata
interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

// Interface untuk IERC20Errors
interface IERC20Errors {
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InvalidSender(address sender);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    error ERC20InvalidApprover(address approver);
    error ERC20InvalidSpender(address spender);
}

// Interface untuk IERC165 (digunakan oleh SafeERC20)
interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// Interface untuk IERC20Permit (opsional, untuk SafeERC20)
interface IERC20Permit {
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
    function nonces(address owner) external view returns (uint256);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// Kontrak abstrak Initializable (untuk kontrak upgradeable)
abstract contract Initializable {
    struct InitializableStorage {
        uint64 _initialized;
        bool _initializing;
    }

    bytes32 private constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;
    error InvalidInitialization();
    error NotInitializing();
    event Initialized(uint64 version);

    modifier initializer() {
        InitializableStorage storage $ = _getInitializableStorage();
        bool isTopLevelCall = !$._initializing;
        uint64 initialized = $._initialized;
        bool initialSetup = initialized == 0 && isTopLevelCall;
        bool construction = initialized == 1 && address(this).code.length == 0;

        if (!initialSetup && !construction) {
            revert InvalidInitialization();
        }
        $._initialized = 1;
        if (isTopLevelCall) {
            $._initializing = true;
        }
        _;
        if (isTopLevelCall) {
            $._initializing = false;
            emit Initialized(1);
        }
    }

    modifier reinitializer(uint64 version) {
        InitializableStorage storage $ = _getInitializableStorage();
        if ($._initializing || $._initialized >= version) {
            revert InvalidInitialization();
        }
        $._initialized = version;
        $._initializing = true;
        _;
        $._initializing = false;
        emit Initialized(version);
    }

    modifier onlyInitializing() {
        _checkInitializing();
        _;
    }

    function _checkInitializing() internal view virtual {
        if (!_isInitializing()) {
            revert NotInitializing();
        }
    }

    function _disableInitializers() internal virtual {
        InitializableStorage storage $ = _getInitializableStorage();
        if ($._initializing) {
            revert InvalidInitialization();
        }
        if ($._initialized != type(uint64).max) {
            $._initialized = type(uint64).max;
            emit Initialized(type(uint64).max);
        }
    }

    function _getInitializedVersion() internal view returns (uint64) {
        return _getInitializableStorage()._initialized;
    }

    function _isInitializing() internal view returns (bool) {
        return _getInitializableStorage()._initializing;
    }

    function _getInitializableStorage() private pure returns (InitializableStorage storage $) {
        assembly {
            $.slot := INITIALIZABLE_STORAGE
        }
    }
}

// Kontrak abstrak ContextUpgradeable
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {}
    function __Context_init_unchained() internal onlyInitializing {}
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

// Kontrak abstrak ERC20Upgradeable
abstract contract ERC20Upgradeable is Initializable, ContextUpgradeable, IERC20, IERC20Metadata, IERC20Errors {
    struct ERC20Storage {
        mapping(address => uint256) _balances;
        mapping(address => mapping(address => uint256)) _allowances;
        uint256 _totalSupply;
        string _name;
        string _symbol;
    }

    bytes32 private constant ERC20StorageLocation = 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00;

    function _getERC20Storage() private pure returns (ERC20Storage storage $) {
        assembly {
            $.slot := ERC20StorageLocation
        }
    }

    function __ERC20_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC20_init_unchained(name_, symbol_);
    }

    function __ERC20_init_unchained(string memory name_, string memory symbol_) internal onlyInitializing {
        ERC20Storage storage $ = _getERC20Storage();
        $._name = name_;
        $._symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._name;
    }

    function symbol() public view virtual override returns (string memory) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._balances[account];
    }

    function transfer(address to, uint256 value) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._allowances[owner][spender];
    }

    function approve(address spender, uint256 value) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    function _update(address from, address to, uint256 value) internal virtual {
        ERC20Storage storage $ = _getERC20Storage();
        if (from == address(0)) {
            $._totalSupply += value;
        } else {
            uint256 fromBalance = $._balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                $._balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                $._totalSupply -= value;
            }
        } else {
            unchecked {
                $._balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        ERC20Storage storage $ = _getERC20Storage();
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        $._allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}

// Kontrak abstrak OwnableUpgradeable
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    struct OwnableStorage {
        address _owner;
    }

    bytes32 private constant OwnableStorageLocation = 0x9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c199300;
    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function __Ownable_init(address initialOwner) internal onlyInitializing {
        __Ownable_init_unchained(initialOwner);
    }

    function __Ownable_init_unchained(address initialOwner) internal onlyInitializing {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        OwnableStorage storage $ = _getOwnableStorage();
        return $._owner;
    }

    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        OwnableStorage storage $ = _getOwnableStorage();
        address oldOwner = $._owner;
        $._owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function _getOwnableStorage() private pure returns (OwnableStorage storage $) {
        assembly {
            $.slot := OwnableStorageLocation
        }
    }
}

// Kontrak abstrak ReentrancyGuardUpgradeable
abstract contract ReentrancyGuardUpgradeable is Initializable {
    struct ReentrancyGuardStorage {
        uint256 _status;
    }

    bytes32 private constant ReentrancyGuardStorageLocation = 0xad7c5bef027816a800da1736444fb58a807ef4c9603b7848673f7e3a68ebcd00;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    error ReentrancyGuardReentrantCall();

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        $._status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        if ($._status == _ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }
        $._status = _ENTERED;
        _;
        $._status = _NOT_ENTERED;
    }

    function _getReentrancyGuardStorage() private pure returns (ReentrancyGuardStorage storage $) {
        assembly {
            $.slot := ReentrancyGuardStorageLocation
        }
    }
}

// Kontrak abstrak PausableUpgradeable
abstract contract PausableUpgradeable is Initializable, ContextUpgradeable {
    struct PausableStorage {
        bool _paused;
    }

    bytes32 private constant PausableStorageLocation = 0xcd5a11904ed2d5a02c2a37e7f7b5d4b4f6d967f6f327b46778481a4d6f3b48a0;
    event Paused(address account);
    event Unpaused(address account);
    error EnforcedPause();
    error ExpectedPause();

    function __Pausable_init() internal onlyInitializing {
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal onlyInitializing {
        PausableStorage storage $ = _getPausableStorage();
        $._paused = false;
    }

    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    modifier whenPaused() {
        _requirePaused();
        _;
    }

    function paused() public view virtual returns (bool) {
        PausableStorage storage $ = _getPausableStorage();
        return $._paused;
    }

    function _requireNotPaused() internal view virtual {
        if (paused()) {
            revert EnforcedPause();
        }
    }

    function _requirePaused() internal view virtual {
        if (!paused()) {
            revert ExpectedPause();
        }
    }

    function _pause() internal virtual whenNotPaused {
        PausableStorage storage $ = _getPausableStorage();
        $._paused = true;
        emit Paused(_msgSender());
    }

    function _unpause() internal virtual whenPaused {
        PausableStorage storage $ = _getPausableStorage();
        $._paused = false;
        emit Unpaused(_msgSender());
    }

    function _getPausableStorage() private pure returns (PausableStorage storage $) {
        assembly {
            $.slot := PausableStorageLocation
        }
    }
}

// Library SafeERC20 (untuk transfer aman)
library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert("SafeERC20: transfer failed");
            }
        }
        if (returndata.length > 0) {
            if (!abi.decode(returndata, (bool))) {
                revert("SafeERC20: transfer failed");
            }
        }
    }
}

// Kontrak utama Otakudump
contract Otakudump is Initializable, ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;

    /// @notice Maximum supply of Otakudump tokens (121 trillion)
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
    constructor() {
        _disableInitializers(); // Mencegah inisialisasi langsung tanpa proxy
    }

    /// @notice Fungsi inisialisasi untuk kontrak upgradeable
    function initialize(address initialOwner, address _initialDexPair) initializer public {
        __ERC20_init("Otakudump", "OTD"); // Nama: Otakudump, Simbol: OTD
        __Ownable_init(initialOwner); // Menetapkan pemilik awal
        __ReentrancyGuard_init(); // Inisialisasi ReentrancyGuard
        __Pausable_init(); // Inisialisasi Pausable

        require(!isMinted, "Tokens already minted");
        require(_initialDexPair != address(0), "Invalid initial DEX pair");
        _mint(initialOwner, MAX_SUPPLY);
        isMinted = true;
        dexPairs[_initialDexPair] = true;
    }

    /// @notice Updates reflection balance for an account
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
    function addDexPair(address dexPair) external onlyOwner {
        require(dexPair != address(0), "Invalid DEX pair address");
        dexPairs[dexPair] = true;
    }

    /// @notice Removes a DEX pair (only owner)
    function removeDexPair(address dexPair) external onlyOwner {
        require(dexPairs[dexPair], "DEX pair not found");
        dexPairs[dexPair] = false;
    }

    /// @notice Sets the staking contract address (only owner)
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
    function getTokenomics() external view returns (uint256, uint256, uint256, uint256) {
        return (MAX_SUPPLY, totalBurned, totalReflections, totalLockedLiquidity);
    }

    /// @notice Checks if an address is a contract
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
