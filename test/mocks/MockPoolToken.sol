// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockPoolToken is ERC20, ERC20Burnable {
    constructor() ERC20("Mock Pool Token", "POOL") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function prizeToken() external view returns (address) {
        return address(this);
    }
}
