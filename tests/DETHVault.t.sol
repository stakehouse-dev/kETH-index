// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {TestUtils} from "./util.sol";
import {DETHVault} from "../contracts/deth-vault/DETHVault.sol";

contract DETHVaultTest is TestUtils {
    DETHVault dETHVault;

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
    }

    function testInitialize() public {
        assertEq(dETHVault.minDepositAmount(), 0.01 ether);
        assertEq(dETHVault.minLockUpPeriodForUser(), 1 weeks);
        assertEq(dETHVault.minLockUpPeriodForPool(), 1 weeks);
    }

    function testSetMinDepositAmount() public {
        assertEq(dETHVault.minDepositAmount(), 0.01 ether);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.startPrank(user1);
        dETHVault.setMinDepositAmount(0.02 ether);
        vm.stopPrank();

        dETHVault.setMinDepositAmount(0.02 ether);

        assertEq(dETHVault.minDepositAmount(), 0.02 ether);
    }

    function testDepositRevertWithInvalidParams() public {
        vm.expectRevert(bytes4(keccak256("ZeroAddress()")));
        vm.startPrank(user1);
        dETHVault.deposit(1 ether, address(0));
        vm.stopPrank();

        vm.expectRevert(bytes4(keccak256("TooSmall()")));
        vm.startPrank(user1);
        dETHVault.deposit(0.009 ether, user1);
        vm.stopPrank();
    }

    function testDepositMintShare() public {
        uint256 amount = 1 ether;
        prepareDETH(user1, amount);
        vm.startPrank(user1);
        IERC20(dETH).approve(address(dETHVault), amount);
        vm.stopPrank();

        uint256 expectedShare = dETHVault.amountToShare(amount);

        vm.startPrank(user1);
        dETHVault.deposit(amount, user1);
        vm.stopPrank();

        assertEq(dETHVault.balanceOf(user1), expectedShare);
    }

    function testWithdrawToDETHRevertWithInvalidParams() public {
        uint256 amount = 1 ether;
        prepareDETH(user1, amount);
        vm.startPrank(user1);
        IERC20(dETH).approve(address(dETHVault), amount);
        dETHVault.deposit(amount, user1);
        vm.stopPrank();

        uint256 share = dETHVault.balanceOf(user1);

        vm.expectRevert(bytes4(keccak256("ZeroAddress()")));
        vm.startPrank(user1);
        dETHVault.withdrawToDETH(share, address(0));
        vm.stopPrank();
    }

    function testWithdrawToDETHRevertWhenLockUpPeriod() public {
        uint256 amount = 1 ether;
        prepareDETH(user1, amount);
        vm.startPrank(user1);
        IERC20(dETH).approve(address(dETHVault), amount);
        dETHVault.deposit(amount, user1);
        vm.stopPrank();

        uint256 share = dETHVault.balanceOf(user1);

        vm.expectRevert(bytes4(keccak256("ComeBackLater()")));
        vm.startPrank(user1);
        dETHVault.withdrawToDETH(share, user1);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 weeks - 1);

        vm.expectRevert(bytes4(keccak256("ComeBackLater()")));
        vm.startPrank(user1);
        dETHVault.withdrawToDETH(share, user1);
        vm.stopPrank();
    }

    function testWithdrawToDETH() public {
        uint256 amount = 1 ether;
        prepareDETH(user1, amount);
        vm.startPrank(user1);
        IERC20(dETH).approve(address(dETHVault), amount);
        dETHVault.deposit(amount, user1);
        vm.stopPrank();

        uint256 share = dETHVault.balanceOf(user1);
        assertEq(IERC20(dETH).balanceOf(user1), 0);

        vm.warp(block.timestamp + 1 weeks);

        vm.startPrank(user1);
        dETHVault.withdrawToDETH(share, user1);
        vm.stopPrank();

        assertEq(dETHVault.balanceOf(user1), 0);
        assertRange(IERC20(dETH).balanceOf(user1), 1 ether, 10000);
    }

    function testWithdrawToETHRevertWithInvalidParams() public {
        uint256 amount = 1 ether;
        prepareDETH(user1, amount);
        vm.startPrank(user1);
        IERC20(dETH).approve(address(dETHVault), amount);
        dETHVault.deposit(amount, user1);
        vm.stopPrank();

        uint256 share = dETHVault.balanceOf(user1);

        vm.expectRevert(bytes4(keccak256("ZeroAddress()")));
        vm.startPrank(user1);
        dETHVault.withdrawToETH(share, address(0));
        vm.stopPrank();
    }

    function testWithdrawToETHRevertWhenLockUpPeriod() public {
        uint256 amount = 1 ether;
        prepareDETH(user1, amount);
        vm.startPrank(user1);
        IERC20(dETH).approve(address(dETHVault), amount);
        dETHVault.deposit(amount, user1);
        vm.stopPrank();

        uint256 share = dETHVault.balanceOf(user1);

        vm.expectRevert(bytes4(keccak256("ComeBackLater()")));
        vm.startPrank(user1);
        dETHVault.withdrawToETH(share, user1);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 weeks - 1);

        vm.expectRevert(bytes4(keccak256("ComeBackLater()")));
        vm.startPrank(user1);
        dETHVault.withdrawToETH(share, user1);
        vm.stopPrank();
    }

    function testWithdrawToETH() public {
        uint256 amount = 1 ether;
        prepareDETH(user1, amount);
        vm.startPrank(user1);
        IERC20(dETH).approve(address(dETHVault), amount);
        dETHVault.deposit(amount, user1);
        vm.stopPrank();

        uint256 share = dETHVault.balanceOf(user1);
        assertEq(IERC20(dETH).balanceOf(user1), 0);

        vm.warp(block.timestamp + 1 weeks);

        vm.expectRevert(bytes4(keccak256("FailedToSendETH()")));
        vm.startPrank(user1);
        dETHVault.withdrawToETH(share, user1);
        vm.stopPrank();

        uint256 totalAssets = dETHVault.totalAssets();
        assertRange(totalAssets, 1 ether, 10000);
        vm.deal(user2, totalAssets);
        vm.startPrank(user2);
        dETHVault.swapETHToDETH{value: totalAssets}(user2);
        vm.stopPrank();

        vm.startPrank(user1);
        dETHVault.withdrawToETH(share, user1);
        vm.stopPrank();

        assertEq(dETHVault.balanceOf(user1), 0);
        assertRange(user1.balance, 1 ether, 10000);
    }

    function testSwapETHToDETHRevertWithInvalidParams() public {
        vm.expectRevert(bytes4(keccak256("ZeroAddress()")));
        vm.startPrank(user1);
        dETHVault.swapETHToDETH(address(0));
        vm.stopPrank();
    }

    function testDepositAndWithdrawIntegration() public {
        // user1 deposit 1 dETH
        uint256 amount = 1 ether;
        prepareDETH(user1, amount);
        vm.startPrank(user1);
        IERC20(dETH).approve(address(dETHVault), amount);
        dETHVault.deposit(amount, user1);
        vm.stopPrank();

        // user2 swap 0.5 eth to dETH
        vm.deal(user2, 0.5 ether);
        vm.startPrank(user2);
        dETHVault.swapETHToDETH{value: 0.5 ether}(user2);
        vm.stopPrank();
        assertEq(IERC20(dETH).balanceOf(user2), 0.5 ether);

        uint256 share = dETHVault.balanceOf(user1);

        // user1 transfer 20% share to user2
        vm.startPrank(user1);
        dETHVault.transfer(user2, share / 5);
        vm.stopPrank();

        // user1 withdraw 25% share in ETH, almost 0.25 ether
        vm.warp(block.timestamp + 1 weeks);
        vm.startPrank(user1);
        dETHVault.withdrawToETH(share / 4, user1);
        vm.stopPrank();
        assertRange(user1.balance, 0.25 ether, 10000);

        // user2 withdraw 100% share in ETH, almost 0.2 ether
        vm.warp(block.timestamp + 1 weeks);
        share = dETHVault.balanceOf(user2);
        vm.startPrank(user2);
        dETHVault.withdrawToETH(share, user2);
        vm.stopPrank();
        assertRange(user2.balance, 0.2 ether, 10000);
    }

    function testUUPSUpgradeable() public {
        bytes32 implementationSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

        // upgrade to new implementation address
        DETHVault newImplementation = new DETHVault();
        dETHVault.upgradeTo(address(newImplementation));
        assertEq(
            address(
                uint160(
                    uint256(vm.load(address(dETHVault), implementationSlot))
                )
            ),
            address(newImplementation)
        );

        // test upgrade after renounce ownership
        dETHVault.renounceOwnership();
        assertEq(dETHVault.owner(), address(0));

        vm.expectRevert("Ownable: caller is not the owner");
        dETHVault.upgradeTo(address(newImplementation));
    }

    function testIsolateKnotFromOpenIndex() public {
        // user1 deposit 100 dETH
        uint256 amount = 100 ether;
        prepareDETH(user1, amount);
        vm.startPrank(user1);
        IERC20(dETH).approve(address(dETHVault), amount);
        dETHVault.deposit(amount, user1);
        vm.stopPrank();

        address stakeHouse = 0xC31a8e5d944F011927E9C884DF5a990Ee6B72071;
        bytes
            memory blsPublicKey = hex"8021cca323eb594a275752032852777098ef5bc7970db412c9c2c10be3f083d1e02fbe5d0992f24e9aa52a9f7815fe59";
        dETHVault.isolateKnotFromOpenIndex(stakeHouse, blsPublicKey);
    }

    function testFirstDepositorPotentialAttackWithShares() public {
        // user1 deposit 0.01 dETH
        prepareDETH(user1, 0.01 ether);
        vm.startPrank(user1);
        IERC20(dETH).approve(address(dETHVault), 0.01 ether);
        dETHVault.deposit(0.01 ether, user1);
        vm.stopPrank();

        // user1 tries to transfer 100000 ETH
        // but can't transfer, no receive()
        vm.deal(user1, 100000 ether);
        (bool sent, ) = payable(address(dETHVault)).call{value: 100000 ether}(
            ""
        );
        assertEq(sent, false);

        // user1 tries to transfer 100 dETH
        prepareDETH(user1, 100 ether);
        vm.startPrank(user1);
        IERC20(dETH).transfer(address(dETHVault), 100 ether);
        vm.stopPrank();

        // user2 deposit 0.01 dETH
        prepareDETH(user2, 0.01 ether);
        vm.startPrank(user2);
        IERC20(dETH).approve(address(dETHVault), 0.01 ether);
        dETHVault.deposit(0.01 ether, user2);
        vm.stopPrank();

        // user2 withdraw
        vm.warp(block.timestamp + 1 weeks);
        uint256 share = dETHVault.balanceOf(user2);
        vm.startPrank(user2);
        dETHVault.withdrawToDETH(share, user2);
        vm.stopPrank();

        assertRange(IERC20(dETH).balanceOf(user2), 0.01 ether, 10000);
    }
}
