// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockPrizeVault is ERC4626 {
    constructor(
        IERC20 asset
    ) ERC4626(asset) ERC20("Prize Vault Token", "pvPOOL") {}
}
