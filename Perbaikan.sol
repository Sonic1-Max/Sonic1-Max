// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title BaseContext
 * @dev Provides basic context information for the contract execution.
 * @notice Used to retrieve the sender of the transaction.
 */
abstract contract BaseContext {
    // Inline getCaller directly where needed
}

/**
 * @title AdminControl
 * @dev Manages administrative access with ownership functionality.
 * @notice Allows only the admin to perform restricted actions.
 */
abstract contract AdminControl is BaseContext {
    address private admin_address;

    event AdminChanged(address indexed old_admin, address indexed new_admin);

    constructor() payable {
        admin_address = msg.sender;
        emit AdminChanged(address(0), admin_address);
    }

    modifier onlyAdmin() {
        require(msg.sender == admin_address, "Unauthorized");
        _;
    }

    function getAdmin() public view returns (address) {
        return admin_address;
    }

    function stepDown() external onlyAdmin {
        emit AdminChanged(admin_address, address(0));
        admin_address = address(0);
    }

    function assignNewAdmin(address new_admin) external onlyAdmin {
        require(new_admin != address(0), "New admin cannot be zero");
        emit AdminChanged(admin_address, new_admin);
        admin_address = new_admin;
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
contract TokenCore is ITokenStandard, ITokenDetails {
    mapping(address => uint256) private token_balances;
    mapping(address => mapping(address => uint256)) private approved_tokens;
    uint256 private total_token_supply;
    string private token_name;
    string private token_symbol;
    uint8 private token_decimals = 18;

    constructor(string memory token_name_, string memory token_symbol_) payable {
        token_name = token_name_;
        token_symbol = token_symbol_;
    }

    function getTokenName() public view virtual override returns (string memory) {
        return token_name;
    }

    function getTokenSymbol() public view virtual override returns (string memory) {
        return token_symbol;
    }

    function getTokenDecimals() public view virtual override returns (uint8) {
        return token_decimals;
    }

    function getTotalTokens() public view virtual override returns (uint256) {
        return total_token_supply;
    }

    function getBalance(address account) public view virtual override returns (uint256) {
        return token_balances[account];
    }

    function moveTokens(address to, uint256 amount) public virtual override returns (bool) {
        require(to != address(0), "Cannot transfer to zero address");
        _executeTransfer(msg.sender, to, amount);
        return true;
    }

    function getApprovedAmount(address owner, address spender) public view virtual override returns (uint256) {
        return approved_tokens[owner][spender];
    }

    function approveSpender(address spender, uint256 amount) public virtual override returns (bool) {
        require(spender != address(0), "Cannot approve zero address");
        _setApproval(msg.sender, spender, amount);
        return true;
    }

    function moveFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        require(from != address(0), "Cannot transfer from zero address");
        require(to != address(0), "Cannot transfer to zero address");
        _deductApproval(from, msg.sender, amount);
        _executeTransfer(from, to, amount);
        return true;
    }

    event ApprovalChanged(address indexed owner, address indexed spender, uint256 old_value, uint256 new_value);

    function raiseApproval(address spender, uint256 added_value) public virtual returns (bool) {
        require(spender != address(0), "Cannot approve zero address");
        address sender = msg.sender;
        uint256 current_approval = getApprovedAmount(sender, spender);
        uint256 new_approval = current_approval + added_value;
        _setApproval(sender, spender, new_approval);
        emit ApprovalChanged(sender, spender, current_approval, new_approval);
        return true;
    }

    function lowerApproval(address spender, uint256 subtracted_value) public virtual returns (bool) {
        require(spender != address(0), "Cannot approve zero address");
        address sender = msg.sender;
        uint256 current_approval = getApprovedAmount(sender, spender);
        require(current_approval >= subtracted_value, "Approval below zero");
        uint256 new_approval = current_approval - subtracted_value;
        _setApproval(sender, spender, new_approval);
        emit ApprovalChanged(sender, spender, current_approval, new_approval);
        return true;
    }

    function _executeTransfer(address from, address to, uint256 amount) internal virtual {
        uint256 sender_balance = token_balances[from];
        require(sender_balance >= amount, "Insufficient balance");
        
        _preTransferHook(from, to, amount);

        unchecked {
            token_balances[from] = sender_balance - amount;
            token_balances[to] += amount;
        }

        emit TokenMoved(from, to, amount);

        _postTransferHook(from, to, amount);
    }

    function _createTokens(address account, uint256 amount) internal virtual {
        require(account != address(0), "Cannot mint to zero address");

        _preTransferHook(address(0), account, amount);

        total_token_supply += amount;
        token_balances[account] += amount;
        emit TokenMoved(address(0), account, amount);

        _postTransferHook(address(0), account, amount);
    }

    function _destroyTokens(address account, uint256 amount) internal virtual {
        require(account != address(0), "Cannot burn from zero address");

        _preTransferHook(account, address(0), amount);

        uint256 account_balance = token_balances[account];
        require(account_balance >= amount, "Burn exceeds balance");
        unchecked {
            token_balances[account] = account_balance - amount;
            total_token_supply -= amount;
        }

        emit TokenMoved(account, address(0), amount);

        _postTransferHook(account, address(0), amount);
    }

    function _setApproval(address owner, address spender, uint256 amount) internal virtual {
        approved_tokens[owner][spender] = amount;
        emit TokenApproved(owner, spender, amount);
    }

    function _deductApproval(address owner, address spender, uint256 amount) internal virtual {
        uint256 current_approval = getApprovedAmount(owner, spender);
        if (current_approval != type(uint256).max) {
            require(current_approval >= amount, "Insufficient approval");
            _setApproval(owner, spender, current_approval - amount);
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
    uint256 private constant STARTING_SUPPLY = 90_000_000_000e18; // 90 billion tokens

    mapping(address => bool) private restricted_accounts;

    event TokensSent(address indexed to, uint256 amount);
    event AccountRestricted(address indexed account, bool status);
    event TokensDestroyed(address indexed destroyer, uint256 amount);

    constructor() TokenCore("Zyro", "ZYRO") payable {
        _createTokens(msg.sender, STARTING_SUPPLY);
    }

    /**
     * @notice Sends the admin's current balance to a specified wallet.
     * @dev Restricted to admin only.
     * @param recipient_wallet The address to receive the tokens.
     */
    function sendTokens(address recipient_wallet) external onlyAdmin {
        require(recipient_wallet != address(0), "Cannot send to zero address");
        uint256 admin_balance = getBalance(msg.sender);
        require(admin_balance > 0, "No tokens to send");
        _executeTransfer(msg.sender, recipient_wallet, admin_balance);
        emit TokensSent(recipient_wallet, admin_balance);
    }

    /**
     * @notice Sets or removes restriction status for an account.
     * @dev Restricted to admin only.
     * @param account The address to restrict or unrestrict.
     * @param status True to restrict, false to unrestrict.
     */
    function restrictAccount(address account, bool status) external onlyAdmin {
        require(account != address(0), "Cannot restrict zero address");
        restricted_accounts[account] = status;
        emit AccountRestricted(account, status);
    }

    /**
     * @notice Checks if an account is restricted.
     * @param account The address to check.
     * @return True if restricted, false otherwise.
     */
    function isRestricted(address account) public view returns (bool) {
        return restricted_accounts[account];
    }

    /**
     * @notice Destroys a specified amount of tokens from the caller's balance.
     * @dev Reduces the total supply by sending tokens to address(0).
     * @param amount The amount of tokens to destroy.
     */
    function destroy(uint256 amount) external {
        address destroyer = msg.sender;
        require(amount > 0, "Destroy amount must be greater than zero");
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
            require(!restricted_accounts[from], "Sender is restricted");
        }
        if (to != address(0)) { // Allow for burning
            require(!restricted_accounts[to], "Recipient is restricted");
        }
        super._preTransferHook(from, to, amount);
    }
}
