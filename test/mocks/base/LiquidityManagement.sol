//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";
import "@uniswap/v3-periphery/contracts/libraries/CallbackValidation.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

import "@uniswap/v3-periphery/contracts/base/PeripheryPayments.sol";
import "@uniswap/v3-periphery/contracts/temp/PeripheryImmutableState.sol";

/// @title Liquidity management functions
/// @notice Internal functions for safely managing liquidity in Uniswap V3
abstract contract LiquidityManagement is
    IUniswapV3MintCallback,
    PeripheryImmutableState,
    PeripheryPayments
{
    struct MintCallbackData {
        PoolAddress.PoolKey poolKey;
        address payer;
    }

    /// @inheritdoc IUniswapV3MintCallback
    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external override {
        MintCallbackData memory decoded = abi.decode(data, (MintCallbackData));
        CallbackValidation.verifyCallback(factory, decoded.poolKey);

        if (amount0Owed > 0)
            pay(decoded.poolKey.token0, decoded.payer, msg.sender, amount0Owed);
        if (amount1Owed > 0)
            pay(decoded.poolKey.token1, decoded.payer, msg.sender, amount1Owed);
    }

    struct AddLiquidityParams {
        address token0;
        address token1;
        uint24 fee;
        address recipient;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    /// @notice Add liquidity to an initialized pool
    function addLiquidity(
        AddLiquidityParams memory params
    )
        internal
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1,
            IUniswapV3Pool pool
        )
    {
        (address tokenA, address tokenB) = params.token0 < params.token1
            ? (params.token0, params.token1)
            : (params.token1, params.token0);
        PoolAddress.PoolKey memory poolKey = PoolAddress.PoolKey({
            token0: tokenA,
            token1: tokenB,
            fee: params.fee
        });
        address poolAddress = PoolAddress.computeAddress(factory, poolKey);
        pool = IUniswapV3Pool(poolAddress);

        // compute the liquidity amount
        {
            (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
            uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(
                params.tickLower
            );
            uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(
                params.tickUpper
            );

            liquidity = LiquidityAmounts.getLiquidityForAmounts(
                sqrtPriceX96,
                sqrtRatioAX96,
                sqrtRatioBX96,
                params.amount0Desired,
                params.amount1Desired
            );
        }

        (amount0, amount1) = pool.mint(
            params.recipient,
            params.tickLower,
            params.tickUpper,
            liquidity,
            abi.encode(MintCallbackData({poolKey: poolKey, payer: msg.sender}))
        );

        require(
            amount0 >= params.amount0Min && amount1 >= params.amount1Min,
            "Price slippage check"
        );
    }
}
