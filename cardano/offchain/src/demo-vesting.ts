// El off-chain del vesting, contra el devnet: bloquear y retirar después del deadline.
//
//     ./scripts/devnet.sh up      (en otra terminal)
//     npm run demo-vesting
//
// ES UN EJERCICIO: el UNLOCK tiene dos TODO. El LOCK ya está resuelto.
//
// Es el espejo de demo-simple.ts. Vale la pena tener los dos archivos abiertos al
// lado: son casi iguales, y las tres diferencias son exactamente las del validator.
//
//   1. el datum tiene DOS campos (beneficiary, deadline), no tres
//   2. el redeemer es Void: no hay Claim ni Cancel que elegir
//   3. el rango de validez va del otro lado -> invalidBefore, no invalidHereafter
//
// La 3 es la que importa: el escrow exige que la tx ocurra ANTES del deadline y
// declara un tope; el vesting exige DESPUÉS y declara un piso.

import {
  ada, datosDe, esperarTx, provider, relojDelLedger,
  saldo, script, txBuilder, utxosDelScript, verificarCadenaViva,
} from "./comun.js";
import { MeshTxBuilder, mConStr0 } from "@meshsdk/core";

// OJO — el evaluador de ogmios rechaza esta transacción y la cadena la acepta.
//
// Con `invalidBefore` (un borde INFERIOR), el EvaluateTx del devnet devuelve
// "Some scripts of the transactions terminated with error(s)". Pero si se saltea
// el evaluador y se manda igual, el nodo la valida y la incluye: el validator
// corre, devuelve True y los fondos se mueven. Está verificado.
//
// Por eso acá se declaran las ExUnits a mano en vez de pedírselas al evaluador.
// Son holgadas a propósito; el escrow, que usa un borde SUPERIOR, no necesita
// nada de esto y sigue usando el evaluador normalmente.
const EX_UNITS = { mem: 500_000, steps: 200_000_000 };

await verificarCadenaViva();

const alice = await datosDe("alice");     // deposita
const bob = await datosDe("bob");         // beneficiario: retira después del deadline
const s = script("vesting.vesting.spend");
const reloj = await relojDelLedger();

// ---- 1. LOCK: Alice bloquea 5 ADA para Bob, liberables en 30 s --------------
const ESPERA = 30;
const deadlineMs = (reloj.tiempoDe(reloj.slotActual) + ESPERA) * 1000;

const lock = txBuilder();
await lock
  .txOut(s.address, [{ unit: "lovelace", quantity: "5000000" }])
  .txOutInlineDatumValue(mConStr0([bob.pubKeyHash, deadlineMs]))   // Datum de 2 campos
  .changeAddress(alice.address)
  .selectUtxosFrom(await alice.w.getUtxos())
  .complete();

const hashLock = await alice.w.submitTx(await alice.w.signTx(lock.txHex));
await esperarTx(hashLock);
console.log(`LOCK    ${hashLock}\n        5 ADA liberables en ${ESPERA}s`);

// ---- 2. Esperar a que pase el deadline --------------------------------------
// El validator exige que TODO el rango de validez esté después del deadline, así
// que antes de esto no hay transacción que valga.
const slotDelDeadline = reloj.slotDe(deadlineMs / 1000);
process.stdout.write(`        esperando al slot ${slotDelDeadline}`);
while ((await relojDelLedger()).slotActual <= slotDelDeadline) {
  process.stdout.write(".");
  await new Promise((r) => setTimeout(r, 2000));
}
console.log(" listo");

// ---- 3. UNLOCK: Bob retira ---------------------------------------------------
const [utxo] = await utxosDelScript(s.address);
const colateral = (await bob.w.getUtxos()).find((u) => u.output.amount.length === 1)!;
const antes = await saldo(bob.address);

const unlock = new MeshTxBuilder({ fetcher: provider, submitter: provider });
unlock
  .spendingPlutusScript("V3")
  .txIn(utxo.input.txHash, utxo.input.outputIndex,
        utxo.output.amount, utxo.output.address)
  .txInScript(s.cbor)
  .txInInlineDatumPresent()
  .txInRedeemerValue(mConStr0([]), "Mesh", EX_UNITS)   // Void, con ExUnits fijas
  .txInCollateral(colateral.input.txHash, colateral.input.outputIndex,
                  colateral.output.amount, colateral.output.address)
  // TODO 1 — declarar el firmante requerido.
  //   Mirá cómo lo hace demo-simple.ts. Sin esto, `extra_signatories` llega
  //   vacío al validator y `can_unlock` devuelve False.
  //
  // TODO 2 — declarar el rango de validez.
  //   demo-simple.ts usa `invalidHereafter`, porque el escrow exige que la tx
  //   ocurra ANTES del deadline. El vesting exige DESPUÉS. ¿Cuál va acá?
  //   La variable que necesitás ya está calculada: `slotDelDeadline`.
  .changeAddress(bob.address)
  .selectUtxosFrom(await bob.w.getUtxos());
await unlock.complete();

const hashUnlock = await bob.w.submitTx(await bob.w.signTx(unlock.txHex));
await esperarTx(hashUnlock);
console.log(`UNLOCK  ${hashUnlock}`);
console.log(`        Bob: ${ada(antes)} → ${ada(await saldo(bob.address))}`);
