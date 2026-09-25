// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title VaultVulnerable — versión DELIBERADAMENTE ROTA del Vault de la Clase 3.
/// @notice MATERIAL DE ENSEÑANZA. No desplegar. Contiene dos vulnerabilidades
///         canónicas que se explotan y arreglan en la Clase 7:
///           1. Reentrancy en `withdraw` (interacción antes del effect).
///           2. Control de acceso roto en `setAdmin` / `sweep` (sin restricción).
/// @dev Comparar con `src/Vault.sol` (la versión correcta) para ver exactamente
///      qué cambió. El diff es la lección.
contract VaultVulnerable {
    mapping(address => uint256) private balances;

    address public admin;

    event Deposit(address indexed account, uint256 amount);
    event Withdraw(address indexed account, uint256 amount);

    error InsufficientBalance();
    error TransferFailed();

    constructor() {
        admin = msg.sender;
    }

    function deposit() external payable {
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice VULNERABILIDAD 1 — Reentrancy.
    /// @dev La interacción externa (`call`) ocurre ANTES de poner el balance en
    ///      cero. Un contrato malicioso puede re-entrar en su `receive()`: cada
    ///      re-entrada vuelve a leer su balance completo (todavía sin poner en cero) y
    ///      retira de nuevo, drenando el vault.
    /// @dev Nota didáctica: se usa el patrón "leer balance → enviar → poner en 0"
    ///      en vez de `balances -= amount`. Con `-=`, al desenrollar la recursión
    ///      en Solidity 0.8 el segundo descuento haría underflow y revertiría toda
    ///      la transacción (el chequeo de overflow "accidentalmente" frena el
    ///      ataque). El patrón de cero-al-final es el que drena de verdad.
    function withdraw() external {
        uint256 amount = balances[msg.sender];
        if (amount == 0) revert InsufficientBalance();

        // INTERACTION antes del EFFECT  ← el bug
        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();

        // EFFECT (demasiado tarde: ya se re-entró arriba con el balance intacto)
        balances[msg.sender] = 0;

        emit Withdraw(msg.sender, amount);
    }

    /// @notice VULNERABILIDAD 2 — Control de acceso roto.
    /// @dev Cualquiera puede convertirse en admin: no hay chequeo de `msg.sender`.
    function setAdmin(address nuevo) external {
        admin = nuevo;   // ← el bug
    }

    /// @notice Drena todo el ETH del contrato al admin.
    /// @dev "Protegida" por admin, pero como `setAdmin` es abierta, el control
    ///      de acceso es ilusorio: cualquiera se hace admin y después barre.
    function sweep() external {
        if (msg.sender != admin) revert InsufficientBalance();
        (bool ok, ) = admin.call{value: address(this).balance}("");
        if (!ok) revert TransferFailed();
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }
}
