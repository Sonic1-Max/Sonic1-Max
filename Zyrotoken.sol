// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Library untuk operasi matematika aman
library SafeOperations {
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeOperations: subtraction overflow");
        return a - b;
    }
    
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeOperations: addition overflow");
        return c;
    }
}

// Interface token dengan fungsi yang dibutuhkan
interface IZyroSecure {
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// Kontrak utama dengan keamanan tinggi
contract ZyroSecure is IZyroSecure {
    using SafeOperations for uint256;
    
    // Konstanta token
    string public constant name = "Zyro";
    string public constant symbol = "ZYRO";
    uint8 public constant decimals = 18;
    uint256 public immutable totalSupply;
    
    // State variables
    address private immutable owner;
    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;
    mapping(address => bool) private blacklist;
    bool private locked;
    
    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event BlacklistUpdated(address indexed account, bool status);
    event Distribution(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "ZyroSecure: caller is not owner");
        _;
    }
    
    modifier nonReentrant() {
        require(!locked, "ZyroSecure: reentrancy detected");
        locked = true;
        _;
        locked = false;
    }
    
    modifier notBlacklisted(address account) {
        require(!blacklist[account], "ZyroSecure: account is blacklisted");
        _;
    }
    
    // Constructor dengan supply tetap
    constructor() {
        owner = msg.sender;
        totalSupply = 90000000000 * 10**18; // 90 miliar token
        balances[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }
    
    // Fungsi informasi
    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }
    
    function allowance(address _owner, address spender) external view returns (uint256) {
        return allowances[_owner][spender];
    }
    
    function isBlacklisted(address account) external view returns (bool) {
        return blacklist[account];
    }
    
    // Fungsi transfer utama
    function transfer(address to, 
                     uint256 amount) 
                     external 
                     override 
                     notBlacklisted(msg.sender) 
                     notBlacklisted(to) 
                     nonReentrant 
                     returns (bool) {
        _safeTransfer(msg.sender, to, amount);
        return true;
    }
    
    // Fungsi approval
    function approve(address spender, 
                    uint256 amount) 
                    external 
                    override 
                    notBlacklisted(msg.sender) 
                    returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    // Fungsi transferFrom
    function transferFrom(address from, 
                         address to, 
                         uint256 amount) 
                         external 
                         override 
                         notBlacklisted(from) 
                         notBlacklisted(to) 
                         nonReentrant 
                         returns (bool) {
        uint256 currentAllowance = allowances[from][msg.sender];
        require(currentAllowance >= amount, "ZyroSecure: insufficient allowance");
        
        _approve(from, msg.sender, currentAllowance.sub(amount));
        _safeTransfer(from, to, amount);
        return true;
    }
    
    // Fungsi distribusi oleh owner
    function distribute(address to, uint256 amount) 
                        external 
                        onlyOwner 
                        notBlacklisted(to) 
                        nonReentrant {
        require(amount > 0, "ZyroSecure: amount must be greater than 0");
        _safeTransfer(owner, to, amount);
        emit Distribution(to, amount);
    }
    
    // Fungsi blacklist
    function updateBlacklist(address account, bool status) 
                            external 
                            onlyOwner {
        require(account != address(0), "ZyroSecure: zero address not allowed");
        require(account != owner, "ZyroSecure: cannot blacklist owner");
        blacklist[account] = status;
        emit BlacklistUpdated(account, status);
    }
    
    // Fungsi burn
    function burn(uint256 amount) 
                 external 
                 notBlacklisted(msg.sender) 
                 nonReentrant {
        require(amount > 0, "ZyroSecure: amount must be greater than 0");
        _burn(msg.sender, amount);
    }
    
    // Fungsi internal dengan keamanan
    function _safeTransfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ZyroSecure: transfer from zero address");
        require(to != address(0), "ZyroSecure: transfer to zero address");
        require(balances[from] >= amount, "ZyroSecure: insufficient balance");
        
        // Checks-effects-interactions pattern
        balances[from] = balances[from].sub(amount);
        balances[to] = balances[to].add(amount);
        
        emit Transfer(from, to, amount);
    }
    
    function _approve(address _owner, address spender, uint256 amount) internal {
        require(_owner != address(0), "ZyroSecure: approve from zero address");
        require(spender != address(0), "ZyroSecure: approve to zero address");
        
        allowances[_owner][spender] = amount;
        emit Approval(_owner, spender, amount);
    }
    
    function _burn(address from, uint256 amount) internal {
        require(balances[from] >= amount, "ZyroSecure: burn amount exceeds balance");
        
        balances[from] = balances[from].sub(amount);
        emit Burn(from, amount);
        emit Transfer(from, address(0), amount);
    }
}
