// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract OtakuDump is ERC20 {
    uint256 public constant TOTAL_SUPPLY = 121_000_000_000_000 * 10**18;
    uint256 public constant FEE = 100; // 1% fee (basis poin)

    constructor() ERC20("OtakuDump", "OTD") {
        _mint(msg.sender, TOTAL_SUPPLY);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        require(recipient != address(0) && amount > 0, "OtakuDump: invalid transfer");

        uint256 feeAmount = (amount * FEE) / 10000;
        if (feeAmount > 0) {
            _burn(msg.sender, feeAmount);
        }
        _transfer(msg.sender, recipient, amount - feeAmount);
        return true;
    }
}
