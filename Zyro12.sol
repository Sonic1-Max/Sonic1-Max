// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

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
 * @title ZyroToken
 * @dev Zyro token with 90 billion initial supply, admin-controlled distribution, restriction functionality, and token destruction feature.
 * @notice Compatible with Ethereum (ERC20). Tokens can be destroyed by sending to address(0) via the destroy function.
 */
contract ZyroToken is ITokenStandard, ITokenDetails {
    mapping(address => uint256) private tokenBalances;
    mapping(address => mapping(address => uint256)) private approvedTokens;
    mapping(address => bool) private restrictedAccounts;
    uint256 private totalTokenSupply;
    string private constant tokenName = "Zyro";
    string private constant tokenSymbol = "ZYRO";
    uint8 private constant tokenDecimals = 18;
    address private immutable adminAddress;
    bool private locked;
    uint256 private totalDistributed;
    uint256 private totalRestrictedAccounts;

    uint256 private constant STARTING_SUPPLY = 90_000_000_000 * 10**18; // 90 billion tokens
    uint256 private constant MAX_DISTRIBUTION = STARTING_SUPPLY / 2; // Limit distribution to 50% of total supply
    uint256 private constant MAX_RESTRICTED_ACCOUNTS = 1000; // Limit the number of restricted accounts

    event TokenMoved(address indexed from, address indexed to, uint256 value);
    event TokenApproved(address indexed owner, address indexed spender, uint256 value);
    event TokensSent(address indexed to, uint256 amount);
    event AccountRestricted(address indexed account, bool status);
    event TokensDestroyed(address indexed destroyer, uint256 amount);
    event AdminAction(string action, address indexed admin, uint256 value);

    modifier onlyAdmin() {
        require(msg.sender == adminAddress, "ZyroToken: unauthorized");
        _;
    }

    modifier nonReentrant() {
        require(!locked, "ZyroToken: reentrant call");
        locked = true;
        _;
        locked = false;
    }

    constructor() {
        adminAddress = msg.sender;
        _createTokens(msg.sender, STARTING_SUPPLY);
    }

    function getTokenName() public pure override returns (string memory) {
        return tokenName;
    }

    function getTokenSymbol() public pure override returns (string memory) {
        return tokenSymbol;
    }

    function getTokenDecimals() public pure override returns (uint8) {
        return tokenDecimals;
    }

    function getTotalTokens() public view override returns (uint256) {
        return totalTokenSupply;
    }

    function getBalance(address account) public view override returns (uint256) {
        return tokenBalances[account];
    }

    function moveTokens(address to, uint256 amount) public override nonReentrant returns (bool) {
        _executeTransfer(msg.sender, to, amount);
        return true;
    }

    function getApprovedAmount(address owner, address spender) public view override returns (uint256) {
        return approvedTokens[owner][spender];
    }

    function approveSpender(address spender, uint256 amount) public override nonReentrant returns (bool) {
        _setApproval(msg.sender, spender, amount);
        return true;
    }

    function moveFrom(address from, address to, uint256 amount) public override nonReentrant returns (bool) {
        _deductApproval(from, msg.sender, amount);
        _executeTransfer(from, to, amount);
        return true;
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
        uint256 adminBalance = getBalance(msg.sender);
        require(adminBalance >= amount, "ZyroToken: insufficient admin balance");
        _executeTransfer(msg.sender, recipientWallet, amount);
        totalDistributed += amount;
        emit TokensSent(recipientWallet, amount);
        emit AdminAction("sendTokens", msg.sender, amount);
    }

    /**
     * @notice Sets or removes restriction status for an account.
     * @dev Restricted to admin only with a limit on the number of restricted accounts.
     * @param account The address to restrict or unrestrict.
     * @param status True to restrict, false to unrestrict.
     */
    function restrictAccount(address account, bool status) external onlyAdmin {
        require(account != address(0), "ZyroToken: cannot restrict zero address");
        require(account != adminAddress, "ZyroToken: cannot restrict admin");
        if (restrictedAccounts[account] != status) {
            if (status) {
                require(totalRestrictedAccounts < MAX_RESTRICTED_ACCOUNTS, "ZyroToken: restricted accounts limit exceeded");
                totalRestrictedAccounts += 1;
            } else {
                totalRestrictedAccounts -= 1;
            }
            restrictedAccounts[account] = status;
            emit AccountRestricted(account, status);
            emit AdminAction("restrictAccount", msg.sender, status ? 1 : 0);
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
        require(amount > 0, "ZyroToken: destroy amount must be greater than zero");
        _destroyTokens(msg.sender, amount);
        emit TokensDestroyed(msg.sender, amount);
    }

    function _executeTransfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ZyroToken: transfer from zero address");
        require(to != address(0) || from == msg.sender, "ZyroToken: transfer to zero address not allowed");

        if (from != address(0)) { // Skip for minting
            require(!restrictedAccounts[from], "ZyroToken: sender is restricted");
        }
        if (to != address(0)) { // Allow for burning
            require(!restrictedAccounts[to], "ZyroToken: recipient is restricted");
        }

        uint256 senderBalance = tokenBalances[from];
        require(senderBalance >= amount, "ZyroToken: insufficient balance");
        tokenBalances[from] = senderBalance - amount;
        tokenBalances[to] += amount;

        emit TokenMoved(from, to, amount);
    }

    function _createTokens(address account, uint256 amount) internal {
        require(account != address(0), "ZyroToken: mint to zero address");

        totalTokenSupply += amount;
        tokenBalances[account] += amount;
        emit TokenMoved(address(0), account, amount);
    }

    function _destroyTokens(address account, uint256 amount) internal {
        require(account != address(0), "ZyroToken: burn from zero address");

        uint256 accountBalance = tokenBalances[account];
        require(accountBalance >= amount, "ZyroToken: burn exceeds balance");
        tokenBalances[account] = accountBalance - amount;
        totalTokenSupply -= amount;

        emit TokenMoved(account, address(0), amount);
    }

    function _setApproval(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ZyroToken: approve from zero address");
        require(spender != address(0), "ZyroToken: approve to zero address");

        approvedTokens[owner][spender] = amount;
        emit TokenApproved(owner, spender, amount);
    }

    function _deductApproval(address owner, address spender, uint256 amount) internal {
        uint256 currentApproval = getApprovedAmount(owner, spender);
        if (currentApproval != type(uint256).max) {
            require(currentApproval >= amount, "ZyroToken: insufficient approval");
            _setApproval(owner, spender, currentApproval - amount);
        }
    }
}
