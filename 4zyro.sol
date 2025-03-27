// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Context
 * @dev Provides information about the current execution context, including the sender of the transaction.
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
 * @dev Implements access control, allowing only the owner to perform specific actions.
 */
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

/**
 * @title IERC20
 * @dev Interface of the ERC20 standard as defined in the EIP.
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
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 */
interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

/**
 * @title ERC20
 * @dev Implementation of the IERC20 interface, providing standard token functionality.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
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

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}

/**
 * @title Zyro
 * @dev Zyro token contract with 90 billion initial supply, owner-controlled distribution, and blacklist functionality.
 * Compatible with BNB Chain (BEP-20). Optimized for low gas and high security.
 */
contract Zyro is ERC20, Ownable {
    uint256 private constant INITIAL_SUPPLY = 90000000000 * 10**18; // 90 billion tokens

    // Blacklist mapping to block specific addresses
    mapping(address => bool) private _blacklist;

    event TokensDistributed(address indexed to, uint256 amount);
    event Blacklisted(address indexed account, bool status);

    constructor() ERC20("Zyro", "ZYRO") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    /**
     * @dev Distributes the entire initial supply to a specified wallet.
     * Can only be called by the owner and only once.
     * @param distributionWallet The address to receive the tokens.
     */
    function distributeTokens(address distributionWallet) external onlyOwner {
        uint256 supply = balanceOf(msg.sender);
        require(supply == INITIAL_SUPPLY, "Tokens already distributed");
        _transfer(msg.sender, distributionWallet, supply);
        emit TokensDistributed(distributionWallet, supply);
    }

    /**
     * @dev Adds or removes an address from the blacklist.
     * Can only be called by the owner.
     * @param account The address to blacklist or unblacklist.
     * @param status True to blacklist, false to unblacklist.
     */
    function setBlacklist(address account, bool status) external onlyOwner {
        require(account != address(0), "Zyro: cannot blacklist zero address");
        _blacklist[account] = status;
        emit Blacklisted(account, status);
    }

    /**
     * @dev Checks if an address is blacklisted.
     * @param account The address to check.
     * @return True if blacklisted, false otherwise.
     */
    function isBlacklisted(address account) public view returns (bool) {
        return _blacklist[account];
    }

    /**
     * @dev Overrides the _transfer function to prevent blacklisted addresses from sending or receiving tokens.
     */
    function _transfer(address from, address to, uint256 amount) internal virtual override {
        require(!_blacklist[from], "Zyro: sender is blacklisted");
        require(!_blacklist[to], "Zyro: recipient is blacklisted");
        super._transfer(from, to, amount);
    }

    /**
     * @dev Overrides the _beforeTokenTransfer to ensure blacklist checks are applied during minting.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        if (from != address(0)) { // Not minting
            require(!_blacklist[from], "Zyro: sender is blacklisted");
        }
        if (to != address(0)) { // Not burning (burning removed)
            require(!_blacklist[to], "Zyro: recipient is blacklisted");
        }
        super._beforeTokenTransfer(from, to, amount);
    }
}
