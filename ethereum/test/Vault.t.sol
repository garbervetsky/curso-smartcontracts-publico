// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/Vault.sol";

contract VaultTest is Test {
    Vault vault;
    address alice = makeAddr("alice");
    address bob   = makeAddr("bob");

    function setUp() public {
        vault = new Vault();
        vm.deal(alice, 10 ether);
        vm.deal(bob,   10 ether);
    }

    // ── deposit ──────────────────────────────────────────────────────────

    function test_Deposit_UpdatesBalance() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();
        assertEq(vault.balanceOf(alice), 1 ether);
        assertEq(alice.balance,9 ether);
    }

    function test_Deposit_AccumulatesMultipleDeposits() public {
        vm.startPrank(alice);
        vault.deposit{value: 1 ether}();
        vault.deposit{value: 2 ether}();
        assertEq(vault.balanceOf(alice), 3 ether);
        vm.stopPrank();
    }

    function test_Deposit_EmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit Vault.Deposit(alice, 2 ether);
        vm.prank(alice);
        vault.deposit{value: 1 ether}();
    }

    // ── withdraw ─────────────────────────────────────────────────────────

    function test_Withdraw_ReducesBalanceAndSendsEth() public {
        vm.startPrank(alice);
        vault.deposit{value: 3 ether}();
        uint256 antes = alice.balance;
        vault.withdraw(1 ether);
        assertEq(vault.balanceOf(alice), 2 ether);
        assertEq(alice.balance, antes + 1 ether);
        vm.stopPrank();
    }

    function test_Withdraw_EmitsEvent() public {
        vm.prank(alice);
        vault.deposit{value: 2 ether}();

        vm.expectEmit(true, false, false, true);
        emit Vault.Withdraw(alice, 1 ether);
        vm.prank(alice);
        vault.withdraw(1 ether);
    }

    function test_Withdraw_RevertsOnInsufficientBalance() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();

        vm.prank(alice);
        vm.expectRevert(Vault.InsufficientBalance.selector);
        vault.withdraw(2 ether);
    }

    function test_Withdraw_RevertsWithZeroDeposit() public {
        vm.prank(alice);
        vm.expectRevert(Vault.InsufficientBalance.selector);
        vault.withdraw(1 ether);
    }

    // ── withdrawAll ───────────────────────────────────────────────────────

    // TODO (se escriben en la Clase 3, Segmento 3)
    // Faltan los dos tests de `withdrawAll()` — el par que no puede faltar:
    //   a) el camino feliz: deposita, retira todo, y verifica que el saldo
    //      interno quede en 0 Y que el ETH le haya llegado de verdad.
    //   b) el borde: llamarla sin saldo revierte con `InsufficientBalance`.
    //
    // Ojo: (a) sin (b) es el error mas comun. Un test que solo prueba el
    // camino feliz no distingue una implementacion correcta de una que nunca
    // revierte.


    // ── aislamiento entre usuarios ────────────────────────────────────────

    function test_BalancesAreIsolated() public {
        vm.prank(alice);
        vault.deposit{value: 2 ether}();
        vm.prank(bob);
        vault.deposit{value: 5 ether}();

        assertEq(vault.balanceOf(alice), 2 ether);
        assertEq(vault.balanceOf(bob),   5 ether);
    }

    function test_Withdraw_DoesNotAffectOtherUsers() public {
        vm.prank(alice);
        vault.deposit{value: 2 ether}();
        vm.prank(bob);
        vault.deposit{value: 5 ether}();

        vm.prank(alice);
        vault.withdraw(2 ether);          // todo lo suyo, con `withdraw`

        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.balanceOf(bob),   5 ether);
    }

    // ── fuzz ──────────────────────────────────────────────────────────────

    function testFuzz_DepositWithdraw(uint96 amount) public {
        vm.assume(amount > 0);
        vm.deal(alice, amount);

        vm.startPrank(alice);
        vault.deposit{value: amount}();
        assertEq(vault.balanceOf(alice), amount);
        vault.withdraw(amount);
        assertEq(vault.balanceOf(alice), 0);
        vm.stopPrank();
    }

    function testFuzz_PartialWithdraw(uint96 deposited, uint96 withdrawn) public {
        vm.assume(deposited > 0);
        vm.assume(withdrawn <= deposited);
        vm.deal(alice, deposited);

        vm.startPrank(alice);
        vault.deposit{value: deposited}();
        vault.withdraw(withdrawn);
        assertEq(vault.balanceOf(alice), deposited - withdrawn);
        vm.stopPrank();
    }
}
