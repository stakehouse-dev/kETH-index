// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {CurveStETHPool} from "../contracts/mocks/CurveStETHPool.sol";
import {CurveRETHPool} from "../contracts/mocks/CurveRETHPool.sol";
import {WstETHToETH} from "../contracts/keth-vault/swappers/WstETHToETH.sol";
import {WstETHToDETH} from "../contracts/keth-vault/swappers/WstETHToDETH.sol";
import {RETHToETH} from "../contracts/keth-vault/swappers/RETHToETH.sol";
import {RETHToDETH} from "../contracts/keth-vault/swappers/RETHToDETH.sol";
import {IWstETH} from "../contracts/keth-vault/steth/IWstETH.sol";
import {IRocketDepositPool} from "../contracts/keth-vault/reth/IRocketDepositPool.sol";

contract TestUtils is Test {
    address public constant ETH = address(0);
    address savETHManager = 0x9Ef3Bb02CadA3e332Bbaa27cd750541c5FFb5b03;
    address dETH = 0x506C2B850D519065a4005b04b9ceed946A64CB6F;
    address savETH = 0x6BC3266716Df5881A9856491AB93303f725a3047;
    address wstETH = 0x6320cD32aA674d2898A68ec82e869385Fc5f7E2f;
    address stETH = 0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F;
    address rETH = 0x178E141a0E3b34152f73Ff610437A7bf9B83267A;
    address rocketDepositPool = 0xa9A6A14A3643690D0286574976F45abBDAD8f505;

    address curveStETHPool;
    address curveRETHPool;

    /// Define some test accounts
    address strategyManager = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address user1 = 0xdD2FD4581271e230360230F9337D5c0430Bf44C0;
    address user2 = 0xbDA5747bFD65F08deb54cb465eB87D40e51B197E;
    address user3 = 0x2546BcD3c84621e976D8185a91A922aE77ECEc30;
    address user4 = 0x05a8458f59Ae37886A97B2E81127654D4f55dfFA;

    address wstETHToETH;
    address wstETHToDETH;
    address rETHToETH;
    address rETHToDETH;

    function prepareTestingEnvironment() public {
        // fork goerli by default
        string memory GOERLI_URL = vm.envString("GOERLI_URL");
        uint256 goerliFork = vm.createFork(GOERLI_URL);
        vm.selectFork(goerliFork);
        assertEq(vm.activeFork(), goerliFork);

        // deploy mocked curve pools
        curveStETHPool = address(new CurveStETHPool(stETH));
        curveRETHPool = address(new CurveRETHPool(rETH));

        // charge ETH for curve pools
        vm.deal(curveStETHPool, 100 ether);
        vm.deal(curveRETHPool, 100 ether);
    }

    function deploySwappers(address dETHVault) public {
        wstETHToETH = address(new WstETHToETH(wstETH, stETH, curveStETHPool));
        wstETHToDETH = address(
            new WstETHToDETH(wstETH, stETH, curveStETHPool, dETH, dETHVault)
        );
        rETHToETH = address(new RETHToETH(rETH, curveRETHPool));
        rETHToDETH = address(
            new RETHToDETH(rETH, curveRETHPool, dETH, dETHVault)
        );
    }

    function prepareStETH(
        address account,
        uint256 ethAmount
    ) public returns (uint256) {
        vm.startPrank(account);
        vm.deal(account, ethAmount);
        (bool sent, ) = stETH.call{value: ethAmount}("");
        require(sent, "failed to send ether");

        vm.stopPrank();

        return IERC20(stETH).balanceOf(account);
    }

    function prepareWstETH(
        address account,
        uint256 stethAmount
    ) public returns (uint256) {
        vm.startPrank(account);
        IERC20(stETH).approve(wstETH, stethAmount);
        IWstETH(wstETH).wrap(stethAmount);
        vm.stopPrank();

        return IERC20(wstETH).balanceOf(account);
    }

    function prepareRETH(
        address account,
        uint256 ethAmount
    ) public returns (uint256) {
        vm.startPrank(account);
        vm.deal(account, ethAmount);
        IRocketDepositPool(rocketDepositPool).deposit{value: ethAmount}();
        vm.stopPrank();

        return IERC20(rETH).balanceOf(account);
    }

    function prepareDETH(
        address account,
        uint256 dETHAmount
    ) public returns (uint256) {
        address dETHHolder = 0x2cEf68303e40be7bb3b89B93184368fC5fCE6653;
        vm.startPrank(dETHHolder);
        IERC20(dETH).transfer(account, dETHAmount);
        vm.stopPrank();

        return IERC20(dETH).balanceOf(account);
    }

    function assertRange(
        uint256 value,
        uint256 expectedValue,
        uint256 range
    ) public {
        if (expectedValue > range) {
            assertGt(value, expectedValue - range);
        } else {
            assertGt(value, expectedValue);
        }

        assertLt(value, expectedValue + range);
    }
}
