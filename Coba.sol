// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract OtakuDump is ERC20 {
    uint256 constant TOTAL_SUPPLY = 121_000_000_000_000 * 10**18;
    uint256 constant FEE = 100; // 1% fee (basis poin)

    constructor() ERC20("OtakuDump", "OTD") {
        _mint(msg.sender, TOTAL_SUPPLY);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        uint256 feeAmount = (amount * FEE) / 10000;
        _transfer(msg.sender, address(this), feeAmount); // Fee ke kontrak
        _transfer(msg.sender, recipient, amount - feeAmount);
        return true;
    }
}
