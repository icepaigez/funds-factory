// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {PrizePool} from "pt-v5-prize-pool/src/PrizePool.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {TwabController} from "pt-v5-twab-controller/src/TwabController.sol";

contract MockPrizePool is PrizePool {
    constructor(
        IERC20 _prizeToken,
        TwabController _twabController,
        address _creator,
        uint256 _tierLiquidityUtilizationRate,
        uint48 _drawPeriodSeconds,
        uint48 _firstDrawOpensAt,
        uint24 _grandPrizePeriodDraws,
        uint8 _numberOfTiers,
        uint8 _tierShares,
        uint8 _canaryShares,
        uint8 _reserveShares,
        uint24 _drawTimeout
    )
        PrizePool(
            ConstructorParams({
                prizeToken: _prizeToken,
                twabController: _twabController,
                creator: _creator,
                tierLiquidityUtilizationRate: _tierLiquidityUtilizationRate,
                drawPeriodSeconds: _drawPeriodSeconds,
                firstDrawOpensAt: _firstDrawOpensAt,
                grandPrizePeriodDraws: _grandPrizePeriodDraws,
                numberOfTiers: _numberOfTiers,
                tierShares: _tierShares,
                canaryShares: _canaryShares,
                reserveShares: _reserveShares,
                drawTimeout: _drawTimeout
            })
        )
    {}
}
