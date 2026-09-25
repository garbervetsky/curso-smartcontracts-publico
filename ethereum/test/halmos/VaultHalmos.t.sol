// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// ---------------------------------------------------------------------------
// Halmos — el mismo invariante de solvencia, verificado en vez de fuzzeado
// ---------------------------------------------------------------------------
// Correr desde ethereum/ (halmos.toml elige el solver y limita la corrida a
// los contratos *Halmos de este archivo; los dos tardan ~1 s):
//
//     halmos                                      # los dos
//     halmos --contract VaultVulnerableHalmos     # FAIL + contraejemplo
//     halmos --contract VaultVulnerableHalmos --invariant-depth 4
//
// El fuzzer de VaultVulnerable.t.sol prueba secuencias al azar; halmos
// considera TODAS las secuencias de hasta --invariant-depth llamadas (2 por
// defecto) con argumentos simbolicos. PASS quiere decir "no hay ninguna de
// largo <= k que rompa la solvencia", que es mas que "no encontre ninguna".
//
// `forge test` NO corre este archivo (no_match_path en foundry.toml): contra el
// vault vulnerable el invariante falla a proposito, y la suite tiene que quedar
// en verde.
//
// Por que un atacante y un handler propios, y no los de VaultVulnerable.t.sol:
// aquel atacante re-entra en un loop mientras quede ETH, y con montos
// simbolicos la cantidad de vueltas tambien es simbolica; halmos abre un camino
// por cada una y no termina. Para romper la solvencia alcanza con re-entrar una
// vez. Por lo mismo se usa vm.assume y no bound(): bound() mete un modulo que
// al solver le cuesta mucho mas.

import "forge-std/Test.sol";
import "../../src/Vault.sol";
import "../../src/VaultVulnerable.sol";

// Lo que el handler necesita del vault (tambien sirve para tu version arreglada).
interface IVault {
    function deposit() external payable;
    function withdraw() external;
}

// Re-entra una sola vez.
contract AtacanteUnaVez {
    IVault public vault;
    bool entro;

    constructor(IVault _vault) {
        vault = _vault;
    }

    function attack() external payable {
        vault.deposit{value: msg.value}();
        vault.withdraw();
    }

    receive() external payable {
        if (!entro) {
            entro = true;
            vault.withdraw();
        }
    }
}

// Las llamadas que halmos puede encadenar: un deposito legitimo o un ataque.
contract HalmosHandler is Test {
    IVault public vault;
    AtacanteUnaVez public attacker;
    uint256 public deposited;   // ETH legitimo que "deberia" estar en el vault

    constructor(IVault _vault) {
        vault = _vault;
        attacker = new AtacanteUnaVez(_vault);
    }

    function legitDeposit(uint256 amount) external {
        vm.assume(amount > 0 && amount <= 100 ether);
        vm.deal(address(this), amount);
        vault.deposit{value: amount}();
        deposited += amount;
    }

    function runAttack(uint256 stake) external {
        vm.assume(stake > 0 && stake <= 100 ether);
        vm.deal(address(this), stake);
        attacker.attack{value: stake}();
    }
}

abstract contract SolvenciaHalmos is Test {
    IVault vault;
    HalmosHandler handler;

    function nuevoVault() internal virtual returns (IVault);

    function setUp() public {
        vault = nuevoVault();
        handler = new HalmosHandler(vault);
        targetContract(address(handler));
    }

    // Misma propiedad que invariant_solvency_DEMO en VaultVulnerable.t.sol.
    function invariant_solvencia() public view {
        assertGe(address(vault).balance, handler.deposited(), "INSOLVENCIA");
    }
}

contract VaultVulnerableHalmos is SolvenciaHalmos {
    function nuevoVault() internal override returns (IVault) {
        return IVault(address(new VaultVulnerable()));
    }
}

// Cuando tengas tu version arreglada, agrega un contrato como el de arriba que
// la despliegue en nuevoVault(). Si el arreglo funciona, halmos da PASS.

// ---------------------------------------------------------------------------
// Un test simbolico sin invariante: prefijo check_ en vez de test_
// ---------------------------------------------------------------------------
//     halmos --contract VaultHalmos               # PASS
//
// El deposito va primero: sin el, balanceOf(user) es 0 en un vault recien
// creado, el vm.assume descarta todos los caminos y halmos lo reporta como
// ERROR ("all paths have been reverted") en vez de dar un PASS que no prueba nada.
contract VaultHalmos is Test {
    Vault vault;

    function setUp() public {
        vault = new Vault();
    }

    function check_withdrawNeverExceedsDeposit(address user, uint256 dep, uint256 amount) public {
        vm.assume(user != address(vault));
        vm.deal(user, dep);
        vm.prank(user);
        vault.deposit{value: dep}();

        vm.assume(amount > 0 && amount <= vault.balanceOf(user));
        uint256 antes = vault.balanceOf(user);
        vm.prank(user);
        vault.withdraw(amount);
        assert(vault.balanceOf(user) == antes - amount);   // ¿existe algun (user, dep, amount) que lo viole?
    }
}
