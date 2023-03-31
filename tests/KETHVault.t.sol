// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {TestUtils} from "./util.sol";
import {DETHVault} from "../contracts/deth-vault/DETHVault.sol";
import {KETHStrategy} from "../contracts/keth-vault/KETHStrategy.sol";
import {KETHVault} from "../contracts/keth-vault/KETHVault.sol";

contract KETHVaultTest is TestUtils {
    DETHVault dETHVault;
    KETHStrategy kETHStrategy;
    KETHVault kETHVault;

    function setUp() public {
        prepareTestingEnvironment();

        // deploy DETH vault
        ERC1967Proxy dETHVaultProxy = new ERC1967Proxy(
            address(new DETHVault()),
            abi.encodeCall(
                DETHVault.initialize,
                (
                    "kwETH",
                    "kwETH",
                    savETHManager,
                    dETH,
                    savETH,
                    0.01 ether,
                    1 weeks,
                    1 weeks
                )
            )
        );
        dETHVault = DETHVault(address(dETHVaultProxy));

        deploySwappers(address(dETHVault));

        // deploy KETH vault
        ERC1967Proxy kETHVaultProxy = new ERC1967Proxy(
            address(new KETHVault()),
            abi.encodeCall(
                KETHVault.initialize,
                ("kETH", "kETH", 30 days, 30 days)
            )
        );
        kETHVault = KETHVault(payable(address(kETHVaultProxy)));

        // deploy KETH strategist
        ERC1967Proxy kETHStrategyProxy = new ERC1967Proxy(
            address(new KETHStrategy()),
            abi.encodeCall(
                KETHStrategy.initialize,
                (
                    KETHStrategy.AddressConfig({
                        wstETH: wstETH,
                        stETH: stETH,
                        curveStETHPool: curveStETHPool,
                        rETH: rETH,
                        curveRETHPool: curveRETHPool
                    }),
                    savETHManager,
                    dETH,
                    savETH,
                    address(dETHVault),
                    address(kETHVault)
                )
            )
        );
        kETHStrategy = KETHStrategy(payable(address(kETHStrategyProxy)));

        // set strategy
        kETHVault.setStrategy(address(kETHStrategy));

        // set swappers
        kETHStrategy.addSwapper(wstETH, ETH, wstETHToETH, true);
        kETHStrategy.addSwapper(wstETH, dETH, wstETHToDETH, true);
        kETHStrategy.addSwapper(rETH, ETH, rETHToETH, true);
        kETHStrategy.addSwapper(rETH, dETH, rETHToDETH, true);

        // set strategy manager
        kETHStrategy.setManager(strategyManager);

        // deposit dETH into dETHVault for liquidity
        uint256 dETHAmount = 5 ether;
        prepareDETH(user1, dETHAmount);
        vm.startPrank(user1);
        IERC20(dETH).approve(address(dETHVault), dETHAmount);
        dETHVault.deposit(dETHAmount, user1);
        vm.stopPrank();
    }

    function testDepositWstETHIntoKETHVault() public {
        prepareWstETH(user1, prepareStETH(user1, 3 ether));

        vm.startPrank(user1);
        IERC20(wstETH).approve(address(kETHVault), 1 ether);
        kETHVault.deposit(wstETH, 1 ether, user1, false);
        vm.stopPrank();

        assertGt(kETHVault.balanceOf(user1), 0);
        assertEq(IERC20(wstETH).balanceOf(address(kETHStrategy)), 1 ether);
    }

    function testDepositStETHIntoKETHVault() public {
        prepareStETH(user1, 3 ether);

        vm.startPrank(user1);
        IERC20(stETH).approve(address(kETHVault), 1 ether);
        kETHVault.deposit(stETH, 1 ether, user1, false);
        vm.stopPrank();

        assertGt(kETHVault.balanceOf(user1), 0);
        assertGt(IERC20(wstETH).balanceOf(address(kETHStrategy)), 0);
    }

    function testDepositWstETHIntoKETHVaultWithSell() public {
        prepareWstETH(user1, prepareStETH(user1, 3 ether));

        vm.startPrank(user1);
        IERC20(wstETH).approve(address(kETHVault), 1 ether);
        kETHVault.deposit(wstETH, 1 ether, user1, true);
        vm.stopPrank();

        assertGt(kETHVault.balanceOf(user1), 0);
        // wstETH is swapped to dETH and deposited into savETHRegistry
        assertEq(IERC20(wstETH).balanceOf(address(kETHStrategy)), 0);
        assertGt(IERC20(savETH).balanceOf(address(kETHStrategy)), 0);
    }

    function testDepositRETHIntoKETHVault() public {
        prepareRETH(user1, 3 ether);

        vm.startPrank(user1);
        IERC20(rETH).approve(address(kETHVault), 1 ether);
        kETHVault.deposit(rETH, 1 ether, user1, false);
        vm.stopPrank();

        assertGt(kETHVault.balanceOf(user1), 0);
        assertEq(IERC20(rETH).balanceOf(address(kETHStrategy)), 1 ether);
    }

    function testDepositRETHIntoKETHVaultWithSell() public {
        prepareRETH(user1, 3 ether);

        vm.startPrank(user1);
        IERC20(rETH).approve(address(kETHVault), 1 ether);
        kETHVault.deposit(rETH, 1 ether, user1, true);
        vm.stopPrank();

        assertGt(kETHVault.balanceOf(user1), 0);
        // wstETH is swapped to dETH and deposited into savETHRegistry
        assertEq(IERC20(rETH).balanceOf(address(kETHStrategy)), 0);
        assertGt(IERC20(savETH).balanceOf(address(kETHStrategy)), 0);
    }

    function testWithdrawAndReceiveETHAndDETH() public {
        // user 1 deposit wsteth
        prepareWstETH(user1, prepareStETH(user1, 3 ether));
        vm.startPrank(user1);
        IERC20(wstETH).approve(address(kETHVault), 1 ether);
        kETHVault.deposit(wstETH, 1 ether, user1, false);
        vm.stopPrank();

        // user 2 deposit reth with sell
        prepareRETH(user2, 3 ether);
        vm.startPrank(user2);
        IERC20(rETH).approve(address(kETHVault), 1 ether);
        kETHVault.deposit(rETH, 1 ether, user2, true);
        vm.stopPrank();

        vm.warp(block.timestamp + 30 days);

        // user1 withdraw
        vm.startPrank(user1);
        uint256 ethBalance = user1.balance;
        uint256 kethBalance = kETHVault.balanceOf(user1);
        kETHVault.withdraw(kethBalance, user1);
        vm.stopPrank();

        assertEq(kETHVault.balanceOf(user1), 0);
        assertGt(user1.balance, ethBalance);
        assertGt(IERC20(dETH).balanceOf(user1), 0);
    }

    function testSellWstETHForDETH() public {
        // user 1 deposit wsteth
        prepareWstETH(user1, prepareStETH(user1, 3 ether));
        vm.startPrank(user1);
        IERC20(wstETH).approve(address(kETHVault), 1 ether);
        kETHVault.deposit(wstETH, 1 ether, user1, false);
        vm.stopPrank();

        // user 2 deposit reth with sell
        prepareRETH(user2, 3 ether);
        vm.startPrank(user2);
        IERC20(rETH).approve(address(kETHVault), 1 ether);
        kETHVault.deposit(rETH, 1 ether, user2, false);
        vm.stopPrank();

        // strategy manager sell wstETH for dETH
        vm.startPrank(strategyManager);
        kETHStrategy.invokeSwap(wstETHToDETH, wstETH, 1 ether, dETH, 0);
        vm.stopPrank();

        assertEq(IERC20(wstETH).balanceOf(address(kETHStrategy)), 0);
        assertGt(IERC20(savETH).balanceOf(address(kETHStrategy)), 0);
    }

    function testSellRETHForDETH() public {
        // user 1 deposit wsteth
        prepareWstETH(user1, prepareStETH(user1, 3 ether));
        vm.startPrank(user1);
        IERC20(wstETH).approve(address(kETHVault), 1 ether);
        kETHVault.deposit(wstETH, 1 ether, user1, false);
        vm.stopPrank();

        // user 2 deposit reth with sell
        prepareRETH(user2, 3 ether);
        vm.startPrank(user2);
        IERC20(rETH).approve(address(kETHVault), 1 ether);
        kETHVault.deposit(rETH, 1 ether, user2, false);
        vm.stopPrank();

        // strategy manager sell rETH for DETH
        vm.startPrank(strategyManager);
        kETHStrategy.invokeSwap(rETHToDETH, rETH, 1 ether, dETH, 0);
        vm.stopPrank();

        assertEq(IERC20(rETH).balanceOf(address(kETHStrategy)), 0);
        assertGt(IERC20(savETH).balanceOf(address(kETHStrategy)), 0);
    }

    function testFirstDepositorPotentialAttackWithShares() public {
        // user1 deposit 0.02 stETH
        prepareStETH(user1, 3 ether);
        vm.startPrank(user1);
        IERC20(stETH).approve(address(kETHVault), 0.02 ether);
        kETHVault.deposit(stETH, 0.02 ether, user1, false);
        vm.stopPrank();

        assertRange(kETHStrategy.totalAssets(), 0.02 ether, 0.0005 ether);

        // user1 tries to transfer 100 wstETH
        prepareWstETH(user1, prepareStETH(user1, 110 ether));
        vm.startPrank(user1);
        IERC20(wstETH).transfer(address(kETHStrategy), 100 ether);
        vm.stopPrank();

        assertRange(kETHStrategy.totalAssets(), 0.02 ether, 0.0005 ether);

        // user2 deposit 0.02 stETH
        prepareStETH(user2, 3 ether);
        vm.startPrank(user2);
        IERC20(stETH).approve(address(kETHVault), 0.02 ether);
        kETHVault.deposit(stETH, 0.02 ether, user2, false);
        vm.stopPrank();

        assertRange(kETHStrategy.totalAssets(), 0.04 ether, 0.0005 ether);

        // user2 withdraw
        vm.warp(block.timestamp + 30 days);
        uint256 kethBalance = kETHVault.balanceOf(user2);
        vm.startPrank(user2);
        kETHVault.withdraw(kethBalance, user2);
        vm.stopPrank();

        assertRange(user2.balance, 0.02 ether, 0.0005 ether);
    }
}
