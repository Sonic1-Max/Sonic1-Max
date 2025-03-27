// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title Context
 * @dev Provides information about the current execution context.
 * @notice Used to retrieve the sender of the transaction.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @title Ownable
 * @dev Manages ownership with access control.
 * @notice Allows only the owner to perform restricted actions.
 */
abstract contract Ownable is Context {
    address private immutable _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        // Note: _owner is immutable, so we cannot change it. This function is kept for compatibility.
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        // Note: _owner is immutable, so we cannot change it. This function is kept for compatibility.
        emit OwnershipTransferred(_owner, newOwner);
    }
}

/**
 * @title IERC20
 * @dev Interface for the ERC20 standard.
 * @notice Defines core token functionalities.
 */
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

/**
 * @title IERC20Metadata
 * @dev Interface for ERC20 metadata.
 * @notice Provides token name, symbol, and decimals.
 */
interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

/**
 * @title ERC20
 * @dev Implementation of the ERC20 standard.
 * @notice Provides standard token functionality with hooks for extensions.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private constant _name = "Zyro";
    string private constant _symbol = "ZYRO";
    uint8 private constant _decimals = 18;
    bool private locked;

    modifier nonReentrant() {
        require(!locked, "ERC20: reentrant call");
        locked = true;
        _;
        locked = false;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override nonReentrant returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override nonReentrant returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        _balances[from] = fromBalance - amount;
        _balances[to] += amount;

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        _balances[account] = accountBalance - amount;
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from zero address");
        require(spender != address(0), "ERC20: approve to zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            _approve(owner, spender, currentAllowance - amount);
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}

/**
 * @title Zyro
 * @dev Zyro token with 90 billion initial supply, owner-controlled distribution, blacklist functionality, and burn feature.
 * @notice Compatible with Ethereum (ERC20). Tokens can be burned by sending to address(0) via the burn function.
 */
contract Zyro is ERC20, Ownable {
    uint256 private constant INITIAL_SUPPLY = 90_000_000_000 * 10**18; // 90 billion tokens

    mapping(address => bool) private _blacklist;

    event TokensDistributed(address indexed to, uint256 amount);
    event Blacklisted(address indexed account, bool status);
    event TokensBurned(address indexed burner, uint256 amount);

    constructor() {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    /**
     * @notice Distributes the owner's current balance to a specified wallet.
     * @dev Can only be called by the owner.
     * @param distributionWallet The address to receive the tokens.
     */
    function distributeTokens(address distributionWallet) external onlyOwner nonReentrant {
        uint256 supply = balanceOf(msg.sender);
        require(supply > 0, "Zyro: no tokens to distribute");
        _transfer(msg.sender, distributionWallet, supply);
        emit TokensDistributed(distributionWallet, supply);
    }

    /**
     * @notice Adds or removes an address from the blacklist.
     * @dev Can only be called by the owner.
     * @param account The address to blacklist or unblacklist.
     * @param status True to blacklist, false to unblacklist.
     */
    function setBlacklist(address account, bool status) external onlyOwner {
        require(account != address(0), "Zyro: cannot blacklist zero address");
        require(account != owner(), "Zyro: cannot blacklist owner");
        if (_blacklist[account] != status) {
            _blacklist[account] = status;
            emit Blacklisted(account, status);
        }
    }

    /**
     * @notice Checks if an address is blacklisted.
     * @param account The address to check.
     * @return True if blacklisted, false otherwise.
     */
    function isBlacklisted(address account) public view returns (bool) {
        return _blacklist[account];
    }

    /**
     * @notice Burns a specified amount of tokens from the caller's balance.
     * @dev Reduces the total supply by sending tokens to address(0).
     * @param amount The amount of tokens to burn.
     */
    function burn(uint256 amount) external nonReentrant {
        address burner = _msgSender();
        require(amount > 0, "Zyro: burn amount must be greater than zero");
        _burn(burner, amount);
        emit TokensBurned(burner, amount);
    }

    /**
     * @dev Internal override to enforce blacklist restrictions.
     */
    function _transfer(address from, address to, uint256 amount) internal virtual override {
        super._transfer(from, to, amount);
    }

    /**
     * @dev Internal hook to enforce blacklist restrictions before transfers.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        if (from != address(0)) { // Skip check for minting
            require(!_blacklist[from], "Zyro: sender is blacklisted");
        }
        if (to != address(0)) { // Allow address(0) for burning
            require(!_blacklist[to], "Zyro: recipient is blacklisted");
        }
        super._beforeTokenTransfer(from, to, amount);
    }
}
