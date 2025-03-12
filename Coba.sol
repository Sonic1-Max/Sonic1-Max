// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract OtakuDump is ERC20, Ownable {
    uint256 constant TOTAL_SUPPLY = 121_000_000_000_000 * 10**18;
    uint256 constant FEE = 100; // 1% fee (basis poin)
    uint256 private _totalBurned;

    constructor() ERC20("OtakuDump", "OTD") {
        _mint(msg.sender, TOTAL_SUPPLY);
        transferOwnership(msg.sender); // Pastikan ownership jelas
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        require(recipient != address(0), "ERC20: transfer to the zero address");
        uint256 feeAmount = (amount * FEE) / 10000;
        uint256 transferAmount = amount - feeAmount;
        
        if (feeAmount > 0) {
            _burn(msg.sender, feeAmount); // Burn fee langsung
            _totalBurned += feeAmount;
        }
        _transfer(msg.sender, recipient, transferAmount);
        return true;
    }

    // Fungsi untuk mengecek total burned
    function totalBurned() public view returns (uint256) {
        return _totalBurned;
    }

    // Hanya owner yang bisa menarik token (jika perlu)
    function emergencyWithdraw(uint256 amount) public onlyOwner {
        _transfer(address(this), msg.sender, amount);
    }
}
