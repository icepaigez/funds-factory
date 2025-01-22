// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

//import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

interface IPrizeVault {
    // Events
    event YieldFeeRecipientSet(address indexed yieldFeeRecipient);
    event YieldFeePercentageSet(uint256 yieldFeePercentage);
    event TransferYieldOut(
        address indexed liquidationPair,
        address indexed tokenOut,
        address indexed recipient,
        uint256 amountOut,
        uint256 yieldFee
    );
    event ClaimYieldFeeShares(address indexed recipient, uint256 shares);

    // Errors
    error YieldVaultZeroAddress();
    error OwnerZeroAddress();
    error WithdrawZeroAssets();
    error BurnZeroShares();
    error DepositZeroAssets();
    error MintZeroShares();
    error ZeroTotalAssets();
    error LPZeroAddress();
    error LiquidationAmountOutZero();
    error CallerNotLP(address caller, address liquidationPair);
    error CallerNotYieldFeeRecipient(address caller, address yieldFeeRecipient);
    error PermitCallerNotOwner(address caller, address owner);
    error YieldFeePercentageExceedsMax(
        uint256 yieldFeePercentage,
        uint256 maxYieldFeePercentage
    );
    error SharesExceedsYieldFeeBalance(uint256 shares, uint256 yieldFeeBalance);
    error LiquidationTokenInNotPrizeToken(address tokenIn, address prizeToken);
    error LiquidationTokenOutNotSupported(address tokenOut);
    error LiquidationExceedsAvailable(
        uint256 totalToWithdraw,
        uint256 availableYield
    );
    error LossyDeposit(uint256 totalAssets, uint256 totalSupply);
    error MintLimitExceeded(uint256 excess);
    error MaxSharesExceeded(uint256 shares, uint256 maxShares);
    error MinAssetsNotReached(uint256 assets, uint256 minAssets);
    error FailedToGetAssetDecimals(address asset);

    // Functions
    function totalDebt() external view returns (uint256);
    function totalPreciseAssets() external view returns (uint256);
    function totalYieldBalance() external view returns (uint256);
    function availableYieldBalance() external view returns (uint256);
    function currentYieldBuffer() external view returns (uint256);
    function claimYieldFeeShares(uint256 shares) external;
    function liquidatableBalanceOf(
        address tokenOut
    ) external view returns (uint256);
    function transferTokensOut(
        address sender,
        address receiver,
        address tokenOut,
        uint256 amountOut
    ) external returns (bytes memory);
    function verifyTokensIn(
        address tokenIn,
        uint256 amountIn,
        bytes calldata transferTokensOutData
    ) external;
    function targetOf(address tokenIn) external view returns (address);
    function isLiquidationPair(
        address tokenOut,
        address liquidationPair
    ) external view returns (bool);
    function setClaimer(address claimer) external;
    function setLiquidationPair(address liquidationPair) external;
    function setYieldFeePercentage(uint32 yieldFeePercentage) external;
    function setYieldFeeRecipient(address yieldFeeRecipient) external;
    function asset() external view returns (address);
    function convertToShares(uint256 _assets) external view returns (uint256);
    function deposit(
        uint256 _assets,
        address _receiver
    ) external returns (uint256);
    function withdraw(
        uint256 _assets,
        address _receiver,
        address _owner
    ) external returns (uint256);
}
