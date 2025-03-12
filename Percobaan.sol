// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Otakudump is ERC20 {
    address public immutable owner;
    uint256 public constant INITIAL_SUPPLY = 121_000_000_000_000 * 10**18; // 121 triliun token
    uint256 public constant BURN_THRESHOLD = 55_000_000_000_000 * 10**18; // 55 triliun token
    uint256 public constant BURN_RATE = 5; // 0,5% (5 per 1000)
    uint256 public constant BURN_DENOMINATOR = 1000;

    // Modifier untuk membatasi akses hanya ke pemilik
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor() ERC20("Otakudump", "OTD") {
        owner = msg.sender; // Pemilik adalah deployer
        _mint(msg.sender, INITIAL_SUPPLY); // Semua token ke dompet pemilik saat deploy
    }

    // Fungsi transfer dengan burning saat "menjual" (transfer ke non-pemilik)
    function transfer(address to, uint256 amount) public override returns (bool) {
        require(to != address(0), "Cannot transfer to zero address");
        require(amount > 0, "Amount must be greater than zero");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        uint256 amountToBurn = 0;
        // Jika bukan transfer ke pemilik (dianggap "penjualan") dan total supply masih di atas 55T
        if (to != owner && totalSupply() > BURN_THRESHOLD) {
            amountToBurn = (amount * BURN_RATE) / BURN_DENOMINATOR; // 0,5% dari jumlah transfer
            uint256 supplyAfterBurn = totalSupply() - amountToBurn;

            // Pastikan total supply tidak turun di bawah 55T
            if (supplyAfterBurn < BURN_THRESHOLD) {
                amountToBurn = totalSupply() - BURN_THRESHOLD;
            }

            if (amountToBurn > 0) {
                _burn(msg.sender, amountToBurn); // Bakar token dari pengirim
            }
        }

        // Transfer jumlah yang tersisa setelah burn (jika ada)
        uint256 amountToTransfer = amount - amountToBurn;
        _transfer(msg.sender, to, amountToTransfer);

        return true;
    }

    // Fungsi burn manual hanya untuk pemilik (opsional, untuk keamanan tambahan)
    function burn(uint256 amount) public onlyOwner {
        require(amount > 0, "Amount must be greater than zero");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        _burn(msg.sender, amount);
    }

    // Override untuk mencegah penggunaan fungsi approve dan transferFrom
    function approve(address, uint256) public pure override returns (bool) {
        revert("Approve function is disabled");
    }

    function transferFrom(address, address, uint256) public pure override returns (bool) {
        revert("TransferFrom function is disabled");
    }

    function allowance(address, address) public pure override returns (uint256) {
        revert("Allowance function is disabled");
    }
}
