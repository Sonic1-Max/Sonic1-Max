// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// Base Context Contract
abstract contract BaseContext {
    function getCaller() internal view virtual returns (address) {
        return msg.sender;
    }
}

// Admin Control Contract
abstract contract AdminControl is BaseContext {
    address private adminAddress;
    
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);
    
    modifier onlyAdmin() {
        require(getCaller() == adminAddress, "AdminControl: unauthorized");
        _;
    }
    
    constructor() {
        adminAddress = getCaller();
        emit AdminChanged(address(0), adminAddress);
    }
    
    function getAdmin() public view returns (address) {
        return adminAddress;
    }
    
    function assignNewAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "AdminControl: new admin cannot be zero address");
        emit AdminChanged(adminAddress, newAdmin);
        adminAddress = newAdmin;
    }
    
    function stepDown() external onlyAdmin {
        emit AdminChanged(adminAddress, address(0));
        adminAddress = address(0);
    }
}

// Token Standard Interface
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

// Token Details Interface
interface ITokenDetails is ITokenStandard {
    function getTokenName() external view returns (string memory);
    function getTokenSymbol() external view returns (string memory);
    function getTokenDecimals() external view returns (uint8);
}

// Token Core Implementation
contract TokenCore is BaseContext, ITokenStandard, ITokenDetails {
    // State Variables
    string private tokenName;
    string private tokenSymbol;
    uint8 private tokenDecimals = 18;
    uint256 private totalTokenSupply;
    mapping(address => uint256) private tokenBalances;
    mapping(address => mapping(address => uint256)) private approvedTokens;
    
    // Constructor
    constructor(string memory name_, string memory symbol_) {
        tokenName = name_;
        tokenSymbol = symbol_;
    }
    
    // Token Metadata Functions
    function getTokenName() public view virtual override returns (string memory) {
        return tokenName;
    }
    
    function getTokenSymbol() public view virtual override returns (string memory) {
        return tokenSymbol;
    }
    
    function getTokenDecimals() public view virtual override returns (uint8) {
        return tokenDecimals;
    }
    
    // Token Supply Functions
    function getTotalTokens() public view virtual override returns (uint256) {
        return totalTokenSupply;
    }
    
    function getBalance(address account) public view virtual override returns (uint256) {
        return tokenBalances[account];
    }
    
    // Token Transfer Functions
    function moveTokens(address to, uint256 amount) public virtual override returns (bool) {
        _executeTransfer(getCaller(), to, amount);
        return true;
    }
    
    function moveFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        _deductApproval(from, getCaller(), amount);
        _executeTransfer(from, to, amount);
        return true;
    }
    
    // Approval Functions
    function approveSpender(address spender, uint256 amount) public virtual override returns (bool) {
        _setApproval(getCaller(), spender, amount);
        return true;
    }
    
    function getApprovedAmount(address owner, address spender) public view virtual override returns (uint256) {
        return approvedTokens[owner][spender];
    }
    
    function raiseApproval(address spender, uint256 addedValue) public virtual returns (bool) {
        address sender = getCaller();
        _setApproval(sender, spender, getApprovedAmount(sender, spender) + addedValue);
        return true;
    }
    
    function lowerApproval(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address sender = getCaller();
        uint256 currentApproval = getApprovedAmount(sender, spender);
        require(currentApproval >= subtractedValue, "TokenCore: approval below zero");
        _setApproval(sender, spender, currentApproval - subtractedValue);
        return true;
    }
    
    // Internal Functions
    function _executeTransfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "TokenCore: transfer from zero address");
        _preTransferHook(from, to, amount);
        
        uint256 senderBalance = tokenBalances[from];
        require(senderBalance >= amount, "TokenCore: insufficient balance");
        unchecked {
            tokenBalances[from] = senderBalance - amount;
            tokenBalances[to] += amount;
        }
        
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
        unchecked {
            tokenBalances[account] = accountBalance - amount;
            totalTokenSupply -= amount;
        }
        
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

// Zyro Token Implementation
contract ZyroToken is TokenCore, AdminControl {
    // Constants and State Variables
    uint256 private constant STARTING_SUPPLY = 90000000000 * 10**18;
    mapping(address => bool) private restrictedAccounts;
    
    // Events
    event TokensSent(address indexed to, uint256 amount);
    event AccountRestricted(address indexed account, bool status);
    event TokensDestroyed(address indexed destroyer, uint256 amount);
    
    // Constructor
    constructor() TokenCore("Zyro", "ZYRO") {
        _createTokens(getCaller(), STARTING_SUPPLY);
    }
    
    // Admin Functions
    function sendTokens(address recipientWallet) external onlyAdmin {
        uint256 adminBalance = getBalance(getCaller());
        require(adminBalance > 0, "ZyroToken: no tokens to send");
        _executeTransfer(getCaller(), recipientWallet, adminBalance);
        emit TokensSent(recipientWallet, adminBalance);
    }
    
    function restrictAccount(address account, bool status) external onlyAdmin {
        require(account != address(0), "ZyroToken: cannot restrict zero address");
        restrictedAccounts[account] = status;
        emit AccountRestricted(account, status);
    }
    
    // Public Functions
    function destroy(uint256 amount) external {
        address destroyer = getCaller();
        require(amount > 0, "ZyroToken: destroy amount must be greater than zero");
        _destroyTokens(destroyer, amount);
        emit TokensDestroyed(destroyer, amount);
    }
    
    function isRestricted(address account) public view returns (bool) {
        return restrictedAccounts[account];
    }
    
    // Internal Overrides
    function _executeTransfer(address from, address to, uint256 amount) internal virtual override {
        super._executeTransfer(from, to, amount);
    }
    
    function _preTransferHook(address from, address to, uint256 amount) internal virtual override {
        if (from != address(0)) {
            require(!restrictedAccounts[from], "ZyroToken: sender is restricted");
        }
        if (to != address(0)) {
            require(!restrictedAccounts[to], "ZyroToken: recipient is restricted");
        }
        super._preTransferHook(from, to, amount);
    }
}
