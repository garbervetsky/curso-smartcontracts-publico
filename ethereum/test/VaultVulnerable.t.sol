// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/VaultVulnerable.sol";

// ---------------------------------------------------------------------------
// TALLER DE LA CLASE 7 — lo que falta lo escribis vos
// ---------------------------------------------------------------------------
// Hay tres cosas sin terminar: el contrato atacante y los dos tests que
// demuestran cada bug. Cada una tiene la consigna en su comentario.
//
// Los dos tests arrancan con `vm.skip(true)`, asi `forge test` los muestra como
// [SKIP] y no como falla. Cuando escribas uno, borra esa linea.
//
// Las consignas completas estan en ethereum/README.md, "Taller de la Clase 7".

// ---------------------------------------------------------------------------
// El contrato atacante
// ---------------------------------------------------------------------------
contract ReentrancyAttacker {
    VaultVulnerable public vault;

    constructor(VaultVulnerable _vault) {
        vault = _vault;
    }

    // TODO: el ataque. Recibe ETH del que lo lanza (msg.value), lo deposita en
    // el vault y dispara el robo.
    function attack() external payable {
    }

    // TODO: se ejecuta cada vez que el vault le envia ETH.
    // Ojo con cuando parar: si la ultima llamada al vault revierte, el revert se
    // propaga hacia arriba y deshace todo el ataque.
    receive() external payable {
    }
}

// ---------------------------------------------------------------------------
// PoC 1 — el robo de fondos
// ---------------------------------------------------------------------------
contract VaultVulnerableReentrancyTest is Test {
    VaultVulnerable vault;
    address victima1 = makeAddr("victima1");
    address victima2 = makeAddr("victima2");
    address attackerOwner = makeAddr("attackerOwner");

    function setUp() public {
        vault = new VaultVulnerable();
        // Dos victimas depositan 5 ETH cada una: el vault tiene 10.
        vm.deal(victima1, 5 ether);
        vm.deal(victima2, 5 ether);
        vm.prank(victima1);
        vault.deposit{value: 5 ether}();
        vm.prank(victima2);
        vault.deposit{value: 5 ether}();
    }

    // TODO: demostrar el robo. Con 1 ETH propio, `attackerOwner` lanza tu
    // ReentrancyAttacker. Verificar con asserts cuanto ETH queda en el vault y
    // cuanto tiene el atacante, y que el libro contable (`balanceOf`) sigue
    // diciendo que las victimas tienen su saldo.
    function test_Reentrancy_DrenaElVault() public {
        vm.skip(true);   // borrar cuando lo escribas
    }
}

// ---------------------------------------------------------------------------
// PoC 2 — el otro bug
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

    // TODO: demostrar que `atacante`, que no es el admin, puede quedarse con
    // los 8 ETH de la victima. Sin contrato atacante: alcanza con llamadas
    // desde su cuenta (`vm.prank`).
    function test_AccessControl_ExtranioSeQuedaConLosFondos() public {
        vm.skip(true);   // borrar cuando lo escribas
    }
}

// ---------------------------------------------------------------------------
// PoC 3 — el invariante de solvencia
// ---------------------------------------------------------------------------
// La misma propiedad de la Clase 6, la solvencia, con un handler que ademas de
// depositar puede disparar TU atacante. Es assertGe y no assertEq porque el
// deposito del atacante no se cuenta en `deposited`: un vault sano puede tener
// mas, nunca menos.
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

    // El atacante intenta su ataque. Solo procede si hay fondos.
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

    /// @dev El assertGe esta comentado (con un assertTrue en su lugar) para que
    ///      la suite pase en verde. Cuando tu atacante funcione, descomentarlo y
    ///      correr `forge test --match-contract VaultVulnerableInvariantTest -vv`.
    ///      Volver a comentarlo al terminar.
    function invariant_solvency_DEMO() public view {
        // assertGe(
        //     address(vault).balance,
        //     handler.deposited(),
        //     "INSOLVENCIA: el vault tiene menos ETH del que deberia"
        // );
        assertTrue(true);
    }
}
