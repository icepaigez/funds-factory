// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeTransferLib} from "./libraries/SafeTransferLib.sol";

contract WETH is ERC20 {
    using SafeTransferLib for address;

    event Deposit(address indexed sender, uint256 amount);
    event Withdraw(address indexed sender, uint256 amount);

    constructor() ERC20("Wrapped Ether", "WETH") {
        _mint(msg.sender, 10000000 * 10 ** 18);
    }

    // Add these WETH-specific functions
    function deposit() public payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function withdraw(uint256 amount) public {
        _burn(msg.sender, amount);
        emit Withdraw(msg.sender, amount);
        msg.sender.safeTransferETH(amount);
    }

    // For testing purposes, you might want to keep this
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    receive() external payable virtual {
        deposit();
    }
}
