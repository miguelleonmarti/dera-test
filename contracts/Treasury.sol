// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IUniswapV2Router02.sol";

contract Treasury is Ownable {
    IERC20 public stableCoin;
    uint256[] public allocationRatios;
    address[] public tokenAddresses;
    uint256 public totalAllocated;
    address public uniswapRouterAddress;

    // Chainlink Price Feed Aggregator address for Uniswap
    address public uniswapPriceFeedAddress;

    event Deposit(address indexed from, uint256 amount);
    event Withdrawal(address indexed to, uint256 amount);

    constructor(
        address _stableCoinTokenAddress,
        address _uniswapRouterAddress,
        address _uniswapPriceFeedAddress,
        address _usdtTokenAddress,
        address _daiTokenAddress
    ) {
        stableCoin = IERC20(_stableCoinTokenAddress);
        uniswapRouterAddress = _uniswapRouterAddress;
        uniswapPriceFeedAddress = _uniswapPriceFeedAddress;
        tokenAddresses = [
            _stableCoinTokenAddress,
            _usdtTokenAddress,
            _daiTokenAddress
        ];
    }

    receive() external payable {}

    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(
            stableCoin.transferFrom(msg.sender, address(this), amount),
            "Failed to transfer stable coin"
        );
        totalAllocated += amount;
        emit Deposit(msg.sender, amount);
    }

    function setAllocationRatios(uint256[] memory ratios) external onlyOwner {
        require(
            ratios.length == tokenAddresses.length,
            "Incorrected number of ratios"
        );

        uint256 totalRatio = 0;
        for (uint256 i = 0; i < ratios.length; i++) {
            totalRatio += ratios[i];
        }
        require(totalRatio == 100, "Ratios must add up to 100%");

        allocationRatios = ratios;
    }

    function withdraw(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(amount <= totalAllocated, "Amount exceeds total allocated");

        uint256 balance = stableCoin.balanceOf(address(this));

        uint256 targetAmount = (amount * allocationRatios[0]) / 100;
        if (targetAmount > 0) {
            _swapTokensForTokens(targetAmount);
        }

        require(
            stableCoin.transfer(owner, amount),
            "Stable coin transfer failed"
        );
        emit Withdrawal(msg.sender, amount);
    }

    function _swapTokensForTokens(uint256 amountIn) internal returns (uint256) {
        IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(
            uniswapRouterAddress
        );

        uint allocationRatiosLength = allocationRatios.length;
        uint[] memory amounts = new uint256[](allocationRatiosLength);

        for (uint256 i = 0; i < allocationRatiosLength; i++) {
            uint256 ratio = allocationRatios[i];
            if (ratio != 0) {
                amounts[i] = uniswapRouter.swapExactTokensForTokens(
                    (amountIn * ratio) / 100,
                    0,
                    getPath(tokenAddresses[0], tokenAddresses[i]),
                    address(this),
                    block.timestamp
                );
            }
        }

        return amounts;
    }

    function calculateYield() external view returns (uint256) {
        uint256 totalYield = 0;

        for (uint256 i = 0; i < allocationRatios.length; i++) {
            uint256 ratio = allocationRatios[i];
            if (i == 0) {
                uint256 uniswapYield = _calculateUniswapYield();
                totalYield += (ratio * uniswapYield) / 100;
            }
        }

        return totalYield;
    }

    function _calculateUniswapYield() internal view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            uniswapPriceFeedAddress
        );

        (, int256 price, , , ) = priceFeed.latestRoundData();

        uint256 annualYieldRate = 5;

        uint256 uniswapYield = (uint256(price) * annualYieldRate) / 100;

        return uniswapYield;
    }

    function getPath(
        address fromToken,
        address toToken
    ) private pure returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = fromToken;
        path[1] = toToken;
        return path;
    }
}
