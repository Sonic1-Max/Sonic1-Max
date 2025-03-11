// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Sonic is ERC20 {
    uint256 public constant MAX_SUPPLY = 121_000_000_000_000 * 10**18;
    bool public isMinted = false;

    uint256 public constant BURN_RATE = 50;
    uint256 public constant MAX_BURN_AMOUNT = 30_000_000_000_000 * 10**18;
    uint256 public totalBurned = 0;

    uint256 public constant MAX_TX_AMOUNT = MAX_SUPPLY / 20;

    uint256 public constant REWARD_RATE = 20;
    uint256 public totalReflections = 0;
    mapping(address => uint256) public reflectionBalances;
    mapping(address => uint256) public lastUpdated;

    mapping(address => bool) public dexPairs;

    event TokensBurned(address indexed burner, uint256 amount);
    event RewardsDistributed(uint256 amount);

    constructor(address _initialDexPair) ERC20("Sonic", "SNC") {
        require(!isMinted, "Tokens already minted");
        require(_initialDexPair != address(0), "Invalid initial DEX pair");
        _mint(msg.sender, MAX_SUPPLY);
        isMinted = true;
        dexPairs[_initialDexPair] = true;
    }

    function _updateReflection(address account) internal {
        if (lastUpdated[account] < block.timestamp) {
            uint256 currentBalance = super.balanceOf(account);
            if (currentBalance > 0 && totalReflections > 0) {
                uint256 share = (currentBalance * totalReflections) / (MAX_SUPPLY - totalBurned);
                reflectionBalances[account] += share;
            }
            lastUpdated[account] = block.timestamp;
        }
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        uint256 baseBalance = super.balanceOf(account);
        uint256 reflection = reflectionBalances[account];
        if (baseBalance > 0 && totalReflections > reflectionBalances[account]) {
            uint256 share = (baseBalance * totalReflections) / (MAX_SUPPLY - totalBurned);
            reflection = share > reflectionBalances[account] ? share : reflectionBalances[account];
        }
        return baseBalance + reflection;
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        require(to != address(0), "Cannot transfer to zero address");
        require(amount <= MAX_TX_AMOUNT, "Amount exceeds max tx limit");

        _updateReflection(msg.sender);
        _updateReflection(to);

        if (dexPairs[to] && BURN_RATE > 0 && !isContract(msg.sender)) {
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

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        require(amount <= MAX_TX_AMOUNT, "Amount exceeds max tx limit");

        _updateReflection(from);
        _updateReflection(to);

        if (dexPairs[to] && BURN_RATE > 0 && !isContract(from)) {
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

    function burn(uint256 amount) public {
        require(amount <= MAX_TX_AMOUNT, "Amount exceeds max tx limit");
        require(totalBurned + amount <= MAX_BURN_AMOUNT, "Exceeds max burn limit");
        _updateReflection(msg.sender);
        _burn(msg.sender, amount);
        totalBurned += amount;
        emit TokensBurned(msg.sender, amount);
    }

    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    receive() external payable {
        revert("Contract does not accept direct BNB");
    }
}
