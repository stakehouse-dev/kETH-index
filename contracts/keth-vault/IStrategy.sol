// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IStrategy {
    function assetValue(
        address asset,
        uint256 balance
    ) external view returns (uint256);

    function totalAssets() external view returns (uint256);

    function deposit(address underlying, uint256 amount, bool sellForDETH) external;

    function withdraw(
        uint256 share,
        uint256 totalSupply,
        address recipient
    ) external returns (uint256 ethAmount, uint256 dETHAmount);

    // send funds to new strategy
    function migrateFunds(address newStrategy) external;

    // additional logic to accept funds from previous strategy
    function acceptMigration(address prevStrategy) external;
}
