// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockAggregatorV3.sol";
import {MockPrizeVault} from "../test/mocks/MockPrizeVault.sol";
import {MockPrizePool} from "../test/mocks/MockPrizePool.sol";
import {MockTwabController} from "../test/mocks/MockTwabController.sol";
import {AAVEVault} from "../test/mocks/MockYieldVault.sol";
import {UniswapV3Factory} from "../test/mocks/MockUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {SwapRouter} from "../test/mocks/MockSwapRouter.sol";
import {USDC} from "../test/mocks/MockUSDC.sol";
import {WETH} from "../test/mocks/MockWETH9.sol";
import {IUniswapV3PoolActions} from "../test/mocks/interfaces/IUniswapV3PoolActions.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {IUniswapV3MintCallback} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {LiquidityManagement} from "../test/mocks/base/LiquidityManagement.sol";
import {NonfungiblePositionManager} from "../test/mocks/MockNonfungiblePositionManager.sol";
import {NonfungibleTokenPositionDescriptor} from "../test/mocks/MockNonfungibleTokenPositionDescriptor.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {TwabController} from "pt-v5-twab-controller/src/TwabController.sol";
import {PrizePool} from "pt-v5-prize-pool/src/PrizePool.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {FixedPoint96} from "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";

contract HelperConfig is Script {
    NetworkConfig public deployConfig;
    MockConfigs public mockConfigs;
    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_PRICE = 3689.99e8;
    uint256 public constant SEPOLIA_CHAINID = 11155111;
    uint256 public constant ETH_MAINNET_CHAINID = 1;
    uint256 public constant OP_SEPOLIA_CHAINID = 11155420;
    address public constant SEPOLIA_PRICE_FEED_ADDRESS =
        0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address public constant OP_SEPOLIA_PRICE_FEED_ADDRESS =
        0x61Ec26aA57019C486B10502285c5A3D4A4750AD7;
    address public constant ETH_MAINNET_PRICE_FEED_ADDRESS =
        0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant SEPOLIA_PRIZE_VAULT_ADDRESS =
        0x95849a4C2E58F4f8Bf868ADEf10B05747A24eE71;
    address public constant SEPOLIA_PRIZE_POOL_ADDRESS =
        0x122FecA66c2b1Ba8Fa9C39E88152592A5496Bc99;
    address public constant ETH_MAINNET_PRIZE_VAULT_ADDRESS = address(1);
    address public constant ETH_MAINNET_PRIZE_POOL_ADDRESS = address(1);
    address public constant SEPOLIA_SWAP_CONTRACT_ADDRESS = address(0x123);
    address public constant ETH_MAINNET_SWAP_CONTRACT_ADDRESS = address(1);
    address public constant OP_WETH_ADDRESS =
        0x4200000000000000000000000000000000000006;
    address public constant OP_SEPOLIA_WETH_ADDRESS =
        0x4200000000000000000000000000000000000006;
    address payable public token0;
    address payable public token1;
    UniswapV3Factory uniswapV3Factory;
    INonfungiblePositionManager public immutable nonfungiblePositionManager;
    int24 public immutable i_tickSpacing = 60;
    uint160 public sqrtPriceX96;
    address wethUsdcPoolAddress;

    event LogValue(string message, uint256 value);

    constructor() {
        if (block.chainid == SEPOLIA_CHAINID) {
            deployConfig = getSepoliaConfig();
        } else if (block.chainid == ETH_MAINNET_CHAINID) {
            deployConfig = getETHMainnetConfig();
        } else if (block.chainid == OP_SEPOLIA_CHAINID) {
            deployConfig = getOPSepoliaConfig();
        } else {
            (deployConfig, mockConfigs) = getOrCreateAnvilConfig();
        }
    }

    struct NetworkConfig {
        address priceFeed;
        address prizeVault;
        address prizePool;
        address swapContract;
    }

    struct MockConfigs {
        address payable weth;
        address payable usdc;
        address uniswapV3factory;
        address poolPair;
    }

    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory config = NetworkConfig({
            priceFeed: SEPOLIA_PRICE_FEED_ADDRESS,
            prizeVault: SEPOLIA_PRIZE_VAULT_ADDRESS,
            prizePool: SEPOLIA_PRIZE_POOL_ADDRESS,
            swapContract: SEPOLIA_SWAP_CONTRACT_ADDRESS
        });
        return config;
    }

    function getOPSepoliaConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory config = NetworkConfig({
            priceFeed: SEPOLIA_PRICE_FEED_ADDRESS,
            prizeVault: SEPOLIA_PRIZE_VAULT_ADDRESS,
            prizePool: SEPOLIA_PRIZE_POOL_ADDRESS,
            swapContract: SEPOLIA_SWAP_CONTRACT_ADDRESS
        });
        return config;
    }

    function getETHMainnetConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory config = NetworkConfig({
            priceFeed: ETH_MAINNET_PRICE_FEED_ADDRESS,
            prizeVault: ETH_MAINNET_PRIZE_VAULT_ADDRESS,
            prizePool: ETH_MAINNET_PRIZE_POOL_ADDRESS,
            swapContract: ETH_MAINNET_SWAP_CONTRACT_ADDRESS
        });
        return config;
    }

    function getOrCreateAnvilConfig()
        public
        returns (NetworkConfig memory, MockConfigs memory)
    {
        if (
            deployConfig.swapContract != address(0) &&
            mockConfigs.uniswapV3factory != address(0)
        ) {
            return (deployConfig, mockConfigs);
        }

        NetworkConfig memory config;
        uint32 periodLength = 3600; // 1 hour period length
        uint32 periodOffset = uint32(block.timestamp - 1 days);
        address creator = address(0x123);
        uint256 tierLiquidityUtilizationRate = 500;
        uint48 drawPeriodSeconds = 86400; //
        uint48 firstDrawOpensAt = uint48(block.timestamp + 1 hours);
        uint24 grandPrizePeriodDraws = 90;
        uint8 numberOfTiers = 8;
        uint8 tierShares = 100;
        uint8 canaryShares = 4;
        uint8 reserveShares = 30;
        uint24 drawTimeout = 60;

        string memory name = "PrizeVault";
        string memory symbol = "pUSDC.e";
        uint32 yieldFeePercentage = 500;
        uint256 yieldBuffer = 100 ether;

        address swapRouter;

        vm.startBroadcast();
        MockV3Aggregator priceFeed = new MockV3Aggregator(
            DECIMALS,
            INITIAL_PRICE
        );

        //create a pool of WETH/USDC in uniswap
        uint256 usdcPrice = 3316; //1 WETH = 3316 USDC
        uint256 wethPrice = 1;
        WETH weth = new WETH();
        USDC usdc = new USDC();
        uint256 amount0 = 1000 ether; // 1000 WETH
        uint256 amount1 = usdcPrice * 1000 * 1e6; // 3.316m USDC
        uniswapV3Factory = new UniswapV3Factory();
        uint24 fee = 3000; // 0.3%

        // Create the Uniswap V3 Pool
        token0 = payable(address(weth));
        token1 = payable(address(usdc));

        //swap router
        SwapRouter swapRouterInstance = new SwapRouter(
            address(uniswapV3Factory),
            token0
        );
        swapRouter = address(swapRouterInstance);

        //deposit WETH and USDC into the pool
        sqrtPriceX96 = uint160(
            Math.sqrt(usdcPrice / wethPrice) * FixedPoint96.Q96
        );
        int24 currentTick = 80865;
        int24 tickLower = ((currentTick - i_tickSpacing) % i_tickSpacing) == 0
            ? currentTick - i_tickSpacing
            : currentTick - ((currentTick - i_tickSpacing) % i_tickSpacing);
        int24 tickUpper = ((currentTick + i_tickSpacing) % i_tickSpacing) == 0
            ? currentTick + i_tickSpacing
            : currentTick + (i_tickSpacing - (currentTick % i_tickSpacing));

        wethUsdcPoolAddress = _provideLiquidity(
            token0,
            address(uniswapV3Factory),
            amount0,
            amount1,
            tickLower,
            tickUpper,
            fee
        );
        require(
            wethUsdcPoolAddress != address(0),
            "wethUsdcPoolAddress is invalid"
        );

        //token & contract for the prize pool
        MockTwabController twabController = new MockTwabController(
            periodLength,
            periodOffset
        );
        MockPrizePool prizePool = new MockPrizePool(
            IERC20(token1),
            TwabController(address(twabController)),
            creator,
            tierLiquidityUtilizationRate,
            drawPeriodSeconds,
            firstDrawOpensAt,
            grandPrizePeriodDraws,
            numberOfTiers,
            tierShares,
            canaryShares,
            reserveShares,
            drawTimeout
        );

        //token & contract for the prize vault
        AAVEVault yieldVault = new AAVEVault(token1);
        MockPrizeVault prizeVault = new MockPrizeVault(
            name,
            symbol,
            IERC4626(address(yieldVault)),
            PrizePool(address(prizePool)),
            creator,
            creator,
            yieldFeePercentage,
            yieldBuffer,
            creator
        );

        config = NetworkConfig({
            priceFeed: address(priceFeed),
            prizeVault: address(prizeVault),
            prizePool: address(prizePool),
            swapContract: swapRouter
        });

        mockConfigs = MockConfigs({
            weth: token0,
            usdc: token1,
            uniswapV3factory: address(uniswapV3Factory),
            poolPair: wethUsdcPoolAddress
        });

        vm.stopBroadcast();
        return (config, mockConfigs);
    }

    function _getPositionManager(
        address _WETH9,
        address _factory
    ) internal returns (NonfungiblePositionManager) {
        bytes32 nativeCurrencyLabelBytes = "ETH";
        NonfungibleTokenPositionDescriptor tokenDescriptor = new NonfungibleTokenPositionDescriptor(
                _WETH9,
                nativeCurrencyLabelBytes
            );
        NonfungiblePositionManager positionManager = new NonfungiblePositionManager(
                _factory,
                _WETH9,
                address(tokenDescriptor)
            );

        return positionManager;
    }

    function _provideLiquidity(
        address _WETH9,
        address _factory,
        uint256 _amount0ToMint,
        uint256 _amount1ToMint,
        int24 _tickLower,
        int24 _tickUpper,
        uint24 _poolFee
    ) internal returns (address) {
        NonfungiblePositionManager positionManager = _getPositionManager(
            _WETH9,
            _factory
        );
        TransferHelper.safeApprove(
            token0,
            address(positionManager),
            _amount0ToMint
        );
        TransferHelper.safeApprove(
            token1,
            address(positionManager),
            _amount1ToMint
        );
        address newPool = positionManager.createAndInitializePoolIfNecessary(
            token0,
            token1,
            _poolFee,
            sqrtPriceX96
        );
        require(newPool != address(0), "newPool is 0");
        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: _poolFee,
                tickLower: _tickLower,
                tickUpper: _tickUpper,
                amount0Desired: _amount0ToMint,
                amount1Desired: _amount1ToMint,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            });
        (, , uint256 wethAmount0, uint256 usdcAmount1) = positionManager.mint(
            params
        );

        // Remove allowance and refund in both assets.
        if (wethAmount0 < _amount0ToMint) {
            TransferHelper.safeApprove(token0, address(positionManager), 0);
            uint256 refund0 = _amount0ToMint - wethAmount0;
            TransferHelper.safeTransfer(token0, msg.sender, refund0);
        }

        if (usdcAmount1 < _amount1ToMint) {
            TransferHelper.safeApprove(token1, address(positionManager), 0);
            uint256 refund1 = _amount1ToMint - usdcAmount1;
            TransferHelper.safeTransfer(token1, msg.sender, refund1);
        }
        return newPool;
    }
}
