# Bonus opcional — los mismos tests, desde el off-chain

> **Opcional: no hace falta para ninguna clase.** Los tests que sí cuentan son los de Foundry
> (`ethereum/test/`), que corren sin instalar nada.
>
> **En la imagen del curso**, Node ya alcanza (v22.23) pero las dependencias **no vienen
> preparadas** — pesan 372 MB, casi un tercio de la imagen. Se instalan con `npm install`. Si
> preferís tenerlas adentro (por ejemplo para un laboratorio **sin internet**), construí la imagen
> con `--build-arg INSTALL_HARDHAT=true`.

Acá está **la misma suite de tests del `Vault`**, escrita desde afuera del contrato — con
**Hardhat + ethers + chai**, que es el stack clásico de JavaScript del ecosistema Ethereum. El
contrato es exactamente el mismo: `contracts/` es un **symlink a `../src/`**, así que no hay copia
que se desincronice.

El punto no es aprender otra herramienta de testing: es **ver la misma cosa desde el otro lado** y
poder comparar.

## Correrlo

Requiere **Node.js ≥ 22.13** (Hardhat 3 lo exige). La imagen del curso trae **v22.23.2**, así que
cumple. Fuera de la imagen, verificá tu versión: con una anterior falla con
`You are using Node.js X which is not supported by Hardhat`.

```bash
cd ethereum/offchain
npm install          # baja Hardhat, ethers, chai, mocha
npx hardhat test
```

Salida real:

```text
Running Mocha tests

  Vault — los mismos casos, desde el off-chain
    ✔ deposit acredita el saldo del que deposita
    ✔ los depositos sucesivos se acumulan
    ✔ deposit emite Deposit con los datos correctos
    ✔ withdraw descuenta el saldo y manda el ETH
    ✔ withdraw de mas revierte con InsufficientBalance
    ✔ los saldos estan aislados entre usuarios

  6 passing (55ms)
```

Verificado con Node v23.5.0, Hardhat 3.12.0, `@nomicfoundation/hardhat-toolbox-mocha-ethers` 3.0.7,
chai 6.2.2, mocha 11.8.0, hardhat-ethers 4.0.15.

## Lo mismo, en los dos lenguajes

| | Foundry (`../test/Vault.t.sol`) | Off-chain (`test/Vault.test.js`) |
|---|---|---|
| Actuar como otro usuario | `vm.prank(alice)` | `vault.connect(alice)` |
| Fondear una cuenta | `vm.deal(alice, 10 ether)` | ya vienen fondeadas por la red local |
| Estado limpio por test | automático | `loadFixture(desplegar)` |
| Esperar un revert tipado | `vm.expectRevert(Vault.InsufficientBalance.selector)` | `.to.be.revertedWithCustomError(vault, "InsufficientBalance")` |
| Verificar un evento | `vm.expectEmit(...)` | `.to.emit(vault, "Deposit").withArgs(...)` |
| Fuzzing | `testFuzz_` (incluido) | no viene; habría que armarlo |
| Viajar en el tiempo | `vm.warp` / `vm.roll` | `networkHelpers.time.*` |
| Velocidad | **13 tests en ~20 ms** | 6 tests en ~55 ms |

**Se parecen más de lo que uno espera.** `hardhat-chai-matchers` da matchers de errores y eventos
tipados contra el ABI del contrato, así que no se pierde precisión al salir de Solidity.

## Entonces, ¿para qué sirve cada uno?

- **Tests en Solidity (Foundry):** son los que hay que escribir para **auditar y razonar sobre el
  contrato**. Corren dentro de la EVM, tienen cheatcodes que manipulan el estado (`vm.warp`,
  `vm.deal`, `vm.store`), traen fuzzing e invariantes gratis, y son mucho más rápidos. Todo el
  bloque de análisis del curso (Clases 6 y 7) se apoya en esto.
- **Tests desde el off-chain:** son los que atrapan lo que vive **en la frontera**: que el ABI sea
  el que el cliente espera, que la codificación de los argumentos sea correcta, que la app llame
  como el contrato supone. Los tests de Solidity **nunca cruzan esa frontera** — el compilador les
  garantiza los tipos. Un frontend con un ABI desactualizado pasa todos los tests de Foundry y
  falla en producción.

No compiten: cubren cosas distintas. En un proyecto real conviven.

## Para conectar con Cardano (Clases 4 y 5)

Mirá `test/Vault.test.js` y contá **qué necesita el off-chain para mandar una transacción**: la
dirección del contrato, el ABI, los argumentos, y firmar. Nada más.

En Cardano, el off-chain tiene que **encontrar el UTXO, construir el redeemer, balancear la
transacción, calcular el min-ADA, agregar los firmantes requeridos, firmar y enviar** — los seis
pasos de la Clase 4. Esa es la **inversión de complejidad** entre los dos modelos, y acá se puede
medir en lugar de creerla.
