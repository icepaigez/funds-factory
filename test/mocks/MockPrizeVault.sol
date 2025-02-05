// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {PrizeVault} from "pt-v5-vault/src/PrizeVault.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PrizePool} from "pt-v5-prize-pool/src/PrizePool.sol";

contract MockPrizeVault is PrizeVault {
    address yieldVaultAdd;
    constructor(
        string memory name_,
        string memory symbol_,
        IERC4626 yieldVault_,
        PrizePool prizePool_,
        address claimer_,
        address yieldFeeRecipient_,
        uint32 yieldFeePercentage_,
        uint256 yieldBuffer_,
        address owner_
    )
        PrizeVault(
            name_,
            symbol_,
            yieldVault_,
            prizePool_,
            claimer_,
            yieldFeeRecipient_,
            yieldFeePercentage_,
            yieldBuffer_,
            owner_
        )
    {
        yieldVaultAdd = address(yieldVault_);
    }

    function approveYieldVault() public {
        IERC20(this.asset()).approve(yieldVaultAdd, type(uint256).max);
    }
}
