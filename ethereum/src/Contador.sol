// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title  Contador — el contrato de la demo en vivo de la Clase 2
/// @notice Lleva una cuenta pública que cualquiera puede incrementar, y que
///         sólo el dueño puede volver a cero.
/// @dev    Es el contrato COMPLETO de la demo en Remix: junta las piezas que
///         en las slides aparecen sueltas (estado y constructor, el custom
///         error con su modifier, y el evento). Pegalo tal cual en Remix.
///
///         Ojo: `incrementar()` NO lleva argumentos a propósito. Es lo que
///         hace que en la consola `decoded input` dé `{}` y se vea que el
///         `data` de la transacción es sólo el selector de la función.
contract Contador {
    uint256 public total;
    address public owner;

    event Incrementado(address indexed quien, uint256 nuevoTotal);

    error NoAutorizado();

    constructor() {
        owner = msg.sender;
    }

    modifier soloOwner() {
        if (msg.sender != owner) revert NoAutorizado();
        _;
    }

    /// @notice Suma uno al total. Cualquiera puede llamarla.
    function incrementar() external {
        total += 1;
        emit Incrementado(msg.sender, total);
    }

    /// @notice Vuelve el total a cero. Sólo el dueño.
    function reset() external soloOwner {
        total = 0;
    }
}
