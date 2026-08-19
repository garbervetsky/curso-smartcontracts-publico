// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title Vault — bóveda simple de depósitos en ETH
/// @notice Contrato base del taller de la Clase 3. Se construye acá y se audita
///         (en una variante deliberadamente vulnerable) en la Clase 7.
/// @dev Esta versión usa el patrón checks-effects-interactions a propósito:
///      es la referencia "correcta" contra la que se compara la versión vulnerable.
contract Vault {
    mapping(address => uint256) private balances;

    event Deposit(address indexed account, uint256 amount);
    event Withdraw(address indexed account, uint256 amount);

    error InsufficientBalance();
    error TransferFailed();

    /// @notice Depositar ETH en la bóveda.
    function deposit() external payable {
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice Retirar `amount` de la bóveda.
    /// @dev checks-effects-interactions: primero se actualiza el estado, después se transfiere.
    function withdraw(uint256 amount) external {
        if (balances[msg.sender] < amount) revert InsufficientBalance();

        // effects (antes de la interacción externa)
        balances[msg.sender] -= amount;

        // interaction
        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit Withdraw(msg.sender, amount);
    }

    /// @notice Retirar todo el saldo del llamante.
    ///
    // TODO (se escribe en la Clase 3, Segmento 2)
    // Implementar `withdrawAll()`: el llamante retira TODO su saldo.
    //   1. Aplicar checks-effects-interactions, igual que `withdraw()`.
    //   2. Si no tiene saldo, revertir con `InsufficientBalance()`.
    //   3. Mandar el ETH con `call` y revertir con `TransferFailed()` si falla.
    //   4. Emitir `Withdraw(msg.sender, monto)`.
    //
    // La pregunta que vale: ¿se puede escribir llamando a `withdraw()` desde
    // acá, en vez de repetir el cuerpo? ¿Qué gana y qué pierde esa versión?
    //
    function withdrawAll() external {
        // TODO: implementar
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }
}
