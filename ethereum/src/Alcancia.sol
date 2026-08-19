// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title Alcancia — ahorro en ETH con cierre por parte del owner
/// @notice Este es el contrato que leyeron en la Clase 2. Le falta lo mismo que
///         descubrieron ahí: NO tiene forma de sacar la plata.
/// @dev ACTIVIDAD DE LA CLASE 3. El `retirar()` de abajo está sin implementar a
///      propósito: es lo que hay que escribir, aplicando checks-effects-interactions.
///      El `Vault.sol` construido en clase es la referencia del patrón — pero no
///      lo copies sin pensar: la Alcancia tiene una condición que el Vault no tiene.
contract Alcancia {
    address public immutable owner;
    mapping(address => uint256) private ahorros;
    bool public cerrada;

    event Ahorro(address indexed quien, uint256 monto);
    event Retiro(address indexed quien, uint256 monto);
    event Cierre(uint256 totalFinal);

    error EstaCerrada();
    error NoEsOwner();
    error SinAhorros();
    error TransferenciaFallo();

    constructor() {
        owner = msg.sender;
    }

    modifier soloOwner() {
        if (msg.sender != owner) revert NoEsOwner();
        _;
    }

    /// @notice Depositar ETH en la alcancía.
    function ahorrar() external payable {
        if (cerrada) revert EstaCerrada();
        ahorros[msg.sender] += msg.value;
        emit Ahorro(msg.sender, msg.value);
    }

    /// @notice Cuánto tiene ahorrado quien llama.
    function miAhorro() external view returns (uint256) {
        return ahorros[msg.sender];
    }

    /// @notice Cerrar la alcancía: no se aceptan más depósitos.
    function cerrar() external soloOwner {
        cerrada = true;
        emit Cierre(address(this).balance);
    }

    // -------------------------------------------------------------------------
    // TODO (actividad de la Clase 3)
    // -------------------------------------------------------------------------
    //
    // Implementar `retirar()`: quien llama recupera TODO lo que ahorró.
    //
    // Requisitos:
    //   1. Aplicar checks-effects-interactions.
    //   2. Si no tiene nada ahorrado, revertir con `SinAhorros()`.
    //   3. Si la transferencia falla, revertir con `TransferenciaFallo()`.
    //   4. Emitir `Retiro(msg.sender, monto)`.
    //
    // Y una decisión de DISEÑO que no tiene una única respuesta correcta —
    // pensala y defendé la tuya en la puesta en común:
    //
    //   ¿Se puede retirar cuando la alcancía está `cerrada`?
    //
    //   - Si decís que NO: `cerrar()` congela los fondos para siempre. ¿Es eso
    //     una alcancía, o una trampa? ¿Quién se queda con el ETH?
    //   - Si decís que SÍ: ¿para qué sirve entonces `cerrar()`? ¿Qué impide
    //     exactamente?
    //
    // Tu implementación tiene que ser coherente con los tests que escribas.
    //
    function retirar() external {
        // TODO: implementar
    }
}
