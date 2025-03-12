// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    
    event Transfer(address indexed from, address indexed to, uint256 value);
}

contract OtakuDump is IERC20 {
    string public constant name = "OtakuDump";
    string public constant symbol = "OTD";
    uint8 public constant decimals = 18;
    uint256 private immutable _totalSupply = 121 * 10**12 * 10**18; // 121 Triliun

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    constructor() {
        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        uint256 senderBalance = _balances[msg.sender];
        require(senderBalance >= amount, "Insufficient balance");

        unchecked {
            _balances[msg.sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "Insufficient balance");

        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(currentAllowance >= amount, "Allowance exceeded");

        unchecked {
            _balances[sender] = senderBalance - amount;
            _allowances[sender][msg.sender] = currentAllowance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
        return true;
    }
}
