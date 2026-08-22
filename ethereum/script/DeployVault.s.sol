// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/Vault.sol";

/// @title  DeployVault — despliegue del Vault contra una red local
/// @notice Se corre con anvil escuchando en otra terminal:
///
///     forge script script/DeployVault.s.sol \
///       --rpc-url http://127.0.0.1:8545 \
///       --private-key <clave de anvil> \
///       --broadcast
///
/// @dev Sin `--broadcast` el script sólo simula: no manda ninguna transacción.
///      Lo que va entre `startBroadcast` y `stopBroadcast` es lo que se convierte
///      en transacciones reales.
contract DeployVault is Script {
    function run() external {
        vm.startBroadcast();
        Vault vault = new Vault();
        vm.stopBroadcast();

        console.log("Vault desplegado en:", address(vault));
    }
}
