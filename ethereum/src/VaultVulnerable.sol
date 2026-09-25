// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title VaultVulnerable — el Vault de la Clase 3, con bugs a propósito.
/// @notice MATERIAL DE ENSEÑANZA. No desplegar. Encontrar los bugs, demostrarlos
///         y arreglarlos es el taller de la Clase 7 (ver ethereum/README.md).
/// @dev Comparar con `src/Vault.sol`, la versión correcta.
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

    /// @notice Retira todo el saldo del que llama.
    function withdraw() external {
        uint256 amount = balances[msg.sender];
        if (amount == 0) revert InsufficientBalance();

        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();

        balances[msg.sender] = 0;

        emit Withdraw(msg.sender, amount);
    }

    /// @notice Cambia el admin.
    function setAdmin(address nuevo) external {
        admin = nuevo;
    }

    /// @notice Envía todo el ETH del contrato al admin.
    function sweep() external {
        if (msg.sender != admin) revert InsufficientBalance();
        (bool ok, ) = admin.call{value: address(this).balance}("");
        if (!ok) revert TransferFailed();
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }
}
