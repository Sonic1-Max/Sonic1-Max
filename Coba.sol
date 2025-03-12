// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract OtakuDump is ERC20, Ownable {
    uint256 public constant TOTAL_SUPPLY = 121_000_000_000_000 * 10**18;
    uint256 public constant FEE = 100; // 1% fee (basis poin)
    uint256 private totalBurned;

    event FeeBurned(address indexed burner, uint256 amount);

    constructor() ERC20("OtakuDump", "OTD") {
        _mint(msg.sender, TOTAL_SUPPLY);
        renounceOwnership(); // Menghapus risiko rug pull
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        require(recipient != address(0), "OtakuDump: transfer to zero address");
        require(amount > 0, "OtakuDump: transfer amount must be greater than zero");

        uint256 feeAmount = (amount * FEE) / 10000;
        uint256 transferAmount = amount - feeAmount;

        if (feeAmount > 0) {
            _burn(msg.sender, feeAmount);
            totalBurned += feeAmount;
            emit FeeBurned(msg.sender, feeAmount);
        }

        _transfer(msg.sender, recipient, transferAmount);
        return true;
    }

    function totalBurnedAmount() public view returns (uint256) {
        return totalBurned;
    }
}
