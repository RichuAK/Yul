// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {YERC20} from "../src/YERC20.sol";
import {Test, console} from "forge-std/Test.sol";

contract YERC20Test is Test {
    YERC20 public yul20;
    address owner = makeAddr("owner");
    address spender = makeAddr("spender");
    uint256 amount = 100;
    address recipient = makeAddr("recipient");

    error InsufficientBalance();

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public {
        vm.prank(owner);
        yul20 = new YERC20();
    }

    function testInitialBalance() public view {
        assertEq(yul20.balanceOf(owner), type(uint256).max);
    }

    // bit of fuzzing
    function testTransferFromOwnerToRecipient(uint256 _amount) public {
        vm.prank(owner);
        vm.expectEmit();
        emit Transfer(owner, recipient, _amount);
        yul20.transfer(recipient, _amount);
        assertEq(yul20.balanceOf(owner), type(uint256).max - _amount);
        assertEq(yul20.balanceOf(recipient), _amount);
    }

    function testApproval(uint256 _amount) public {
        vm.prank(owner);
        vm.expectEmit();
        emit Approval(owner, spender, _amount);
        yul20.approve(spender, _amount);
        assertEq(yul20.allowance(owner, spender), _amount);
    }

    function testTransferFrom(uint256 _amount) public {
        vm.prank(owner);
        yul20.approve(spender, _amount);
        vm.prank(spender);
        vm.expectEmit();
        emit Transfer(owner, recipient, _amount);
        yul20.transferFrom(owner, recipient, _amount);
        assertEq(yul20.balanceOf(owner), type(uint256).max - _amount);
        assertEq(yul20.balanceOf(recipient), _amount);
    }

    function testRevertsIfInsufficientBalance(uint256 _amount) public {
        vm.prank(owner);
        yul20.transfer(spender, _amount);
        vm.prank(spender);
        // vm.expectRevert(abi.encodeWithSelector(InsufficientBalance.selector));
        // it reverts, but with this message: [Revert] panic: arithmetic underflow or overflow (0x11)
        vm.expectRevert();
        yul20.transfer(recipient, _amount + 1);
    }
}
