// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ISwapper {
    function inputToken() external view returns (address);

    function outputToken() external view returns (address);

    function swap(
        address input,
        uint256 amountIn,
        address output,
        uint256 minAmountOut
    ) external payable returns (uint256 amountOut);
}
