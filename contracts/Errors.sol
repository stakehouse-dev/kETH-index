// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface Errors {
    error ZeroAddress();
    error InvalidIndex();
    error InvalidAddress();
    error InvalidAmount();
    error Unauthorized();
    error FailedToSendETH();
    error ExceedsDepositCeiling();
    error UnknownAsset();
    error TooSmall();
    error ComeBackLater();
    error ExceedMinAmountOut();
    error InvalidSwapper();
    error SetDefaultSwapperBefore();
    error NotSupportedSwapper();
}
