// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title BaseContext
 * @dev Provides basic context information for the contract execution.
 * @notice Used to retrieve the sender of the transaction.
 */
abstract contract BaseContext {
    function getCaller() internal view virtual returns (address) {
        return msg.sender;
    }
}

/**
 * @title AdminControl
 * @dev Manages administrative access with ownership functionality.
 * @notice Allows only the admin to perform restricted actions.
 */
abstract contract AdminControl is BaseContext {
    address private immutable adminAddress;

    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);

    constructor() {
        adminAddress = getCaller();
        emit AdminChanged(address(0), adminAddress);
    }

    modifier onlyAdmin() {
        require(getCaller() == adminAddress, "AdminControl: unauthorized");
        _;
    }

    function getAdmin() public view returns (address) {
        return adminAddress;
    }

    function stepDown() external onlyAdmin {
        emit AdminChanged(adminAddress, address(0));
        // Note: adminAddress is immutable, so we cannot change it. This function is kept for compatibility.
    }

    function assignNewAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "AdminControl: new admin cannot be zero address");
        // Note: adminAddress is immutable, so we cannot change it. This function is kept for compatibility.
        emit AdminChanged(adminAddress, newAdmin);
    }
}

/**
 * @title ITokenStandard
 * @dev Interface for the token standard, defining core token functionalities.
 * @notice Includes transfer, approval, and balance checking functions.
 */
interface ITokenStandard {
    event TokenMoved(address indexed from, address indexed to, uint256 value);
    event TokenApproved(address indexed owner, address indexed spender, uint256 value);

    function getTotalTokens() external view returns (uint256);
    function getBalance(address account) external view returns (uint256);
    function moveTokens(address to, uint256 amount) external returns (bool);
    function getApprovedAmount(address owner, address spender) external view returns (uint256);
    function approveSpender(address spender, uint256 amount) external returns (bool);
    function moveFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @title ITokenDetails
 * @dev Interface for token metadata.
 * @notice Provides token name, symbol, and decimals.
 */
interface ITokenDetails is ITokenStandard {
    function getTokenName() external view returns (string memory);
    function getTokenSymbol() external view returns (string memory);
    function getTokenDecimals() external view returns (uint8);
}

/**
 * @title TokenCore
 * @dev Core implementation of the token standard with ERC20-like functionality.
 * @notice Handles token transfers, approvals, and balance management.
 */
contract TokenCore is BaseContext, ITokenStandard, ITokenDetails {
    mapping(address => uint256) private tokenBalances;
    mapping(address => mapping(address => uint256)) private approvedTokens;
    uint256 private totalTokenSupply;
    string private constant tokenName = "Zyro";
    string private constant tokenSymbol = "ZYRO";
    uint8 private constant tokenDecimals = 18;
    bool private locked;

    modifier nonReentrant() {
        require(!locked, "TokenCore: reentrant call");
        locked = true;
        _;
        locked = false;
    }

    function getTokenName() public pure virtual override returns (string memory) {
        return tokenName;
    }

    function getTokenSymbol() public pure virtual override returns (string memory) {
        return tokenSymbol;
    }

    function getTokenDecimals() public pure virtual override returns (uint8) {
        return tokenDecimals;
    }

    function getTotalTokens() public view virtual override returns (uint256) {
        return totalTokenSupply;
    }

    function getBalance(address account) public view virtual override returns (uint256) {
        return tokenBalances[account];
    }

    function moveTokens(address to, uint256 amount) public virtual override nonReentrant returns (bool) {
        address sender = getCaller();
        _executeTransfer(sender, to, amount);
        return true;
    }

    function getApprovedAmount(address owner, address spender) public view virtual override returns (uint256) {
        return approvedTokens[owner][spender];
    }

    function approveSpender(address spender, uint256 amount) public virtual override nonReentrant returns (bool) {
        address sender = getCaller();
        _setApproval(sender, spender, amount);
        return true;
    }

    function moveFrom(address from, address to, uint256 amount) public virtual override nonReentrant returns (bool) {
        address spender = getCaller();
        _deductApproval(from, spender, amount);
        _executeTransfer(from, to, amount);
        return true;
    }

    function _executeTransfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "TokenCore: transfer from zero address");
        require(to != address(0) || from == getCaller(), "TokenCore: transfer to zero address not allowed");

        _preTransferHook(from, to, amount);

        uint256 senderBalance = tokenBalances[from];
        require(senderBalance >= amount, "TokenCore: insufficient balance");
        tokenBalances[from] = senderBalance - amount;
        tokenBalances[to] += amount;

        emit TokenMoved(from, to, amount);

        _postTransferHook(from, to, amount);
    }

    function _createTokens(address account, uint256 amount) internal virtual {
        require(account != address(0), "TokenCore: mint to zero address");

        _preTransferHook(address(0), account, amount);

        totalTokenSupply += amount;
        tokenBalances[account] += amount;
        emit TokenMoved(address(0), account, amount);

        _postTransferHook(address(0), account, amount);
    }

    function _destroyTokens(address account, uint256 amount) internal virtual {
        require(account != address(0), "TokenCore: burn from zero address");

        _preTransferHook(account, address(0), amount);

        uint256 accountBalance = tokenBalances[account];
        require(accountBalance >= amount, "TokenCore: burn exceeds balance");
        tokenBalances[account] = accountBalance - amount;
        totalTokenSupply -= amount;

        emit TokenMoved(account, address(0), amount);

        _postTransferHook(account, address(0), amount);
    }

    function _setApproval(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "TokenCore: approve from zero address");
        require(spender != address(0), "TokenCore: approve to zero address");

        approvedTokens[owner][spender] = amount;
        emit TokenApproved(owner, spender, amount);
    }

    function _deductApproval(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentApproval = getApprovedAmount(owner, spender);
        if (currentApproval != type(uint256).max) {
            require(currentApproval >= amount, "TokenCore: insufficient approval");
            _setApproval(owner, spender, currentApproval - amount);
        }
    }

    function _preTransferHook(address from, address to, uint256 amount) internal virtual {}
    function _postTransferHook(address from, address to, uint256 amount) internal virtual {}
}

/**
 * @title ZyroToken
 * @dev Zyro token with 90 billion initial supply, admin-controlled distribution, restriction functionality, and token destruction feature.
 * @notice Compatible with Ethereum (ERC20). Tokens can be destroyed by sending to address(0) via the destroy function.
 */
contract ZyroToken is TokenCore, AdminControl {
    uint256 private constant STARTING_SUPPLY = 90_000_000_000 * 10**18; // 90 billion tokens
    uint256 private constant MAX_DISTRIBUTION = STARTING_SUPPLY / 2; // Limit distribution to 50% of total supply

    mapping(address => bool) private restrictedAccounts;
    uint256 private totalDistributed;

    event TokensSent(address indexed to, uint256 amount);
    event AccountRestricted(address indexed account, bool status);
    event TokensDestroyed(address indexed destroyer, uint256 amount);

    constructor() TokenCore("Zyro", "ZYRO") {
        _createTokens(getCaller(), STARTING_SUPPLY);
    }

    /**
     * @notice Sends a specified amount of tokens from the admin's balance to a wallet.
     * @dev Restricted to admin only with a distribution limit.
     * @param recipientWallet The address to receive the tokens.
     * @param amount The amount of tokens to send.
     */
    function sendTokens(address recipientWallet, uint256 amount) external onlyAdmin nonReentrant {
        require(amount > 0, "ZyroToken: amount must be greater than zero");
        require(totalDistributed + amount <= MAX_DISTRIBUTION, "ZyroToken: distribution limit exceeded");
        uint256 adminBalance = getBalance(getCaller());
        require(adminBalance >= amount, "ZyroToken: insufficient admin balance");
        _executeTransfer(getCaller(), recipientWallet, amount);
        totalDistributed += amount;
        emit TokensSent(recipientWallet, amount);
    }

    /**
     * @notice Sets or removes restriction status for an account.
     * @dev Restricted to admin only.
     * @param account The address to restrict or unrestrict.
     * @param status True to restrict, false to unrestrict.
     */
    function restrictAccount(address account, bool status) external onlyAdmin {
        require(account != address(0), "ZyroToken: cannot restrict zero address");
        require(account != getAdmin(), "ZyroToken: cannot restrict admin");
        if (restrictedAccounts[account] != status) {
            restrictedAccounts[account] = status;
            emit AccountRestricted(account, status);
        }
    }

    /**
     * @notice Checks if an account is restricted.
     * @param account The address to check.
     * @return True if restricted, false otherwise.
     */
    function isRestricted(address account) public view returns (bool) {
        return restrictedAccounts[account];
    }

    /**
     * @notice Destroys a specified amount of tokens from the caller's balance.
     * @dev Reduces the total supply by sending tokens to address(0).
     * @param amount The amount of tokens to destroy.
     */
    function destroy(uint256 amount) external nonReentrant {
        address destroyer = getCaller();
        require(amount > 0, "ZyroToken: destroy amount must be greater than zero");
        _destroyTokens(destroyer, amount);
        emit TokensDestroyed(destroyer, amount);
    }

    /**
     * @dev Internal override to enforce restriction checks during transfers.
     */
    function _executeTransfer(address from, address to, uint256 amount) internal virtual override {
        super._executeTransfer(from, to, amount);
    }

    /**
     * @dev Internal hook to enforce restriction checks before transfers.
     */
    function _preTransferHook(address from, address to, uint256 amount) internal virtual override {
        if (from != address(0)) { // Skip for minting
            require(!restrictedAccounts[from], "ZyroToken: sender is restricted");
        }
        if (to != address(0)) { // Allow for burning
            require(!restrictedAccounts[to], "ZyroToken: recipient is restricted");
        }
        super._preTransferHook(from, to, amount);
    }
}
