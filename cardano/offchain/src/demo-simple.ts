// El ciclo mínimo del escrow, contra el devnet: bloquear y reclamar.
//
//     ./scripts/devnet.sh up      (en otra terminal)
//     npm run demo-simple
//
// Está escrito para LEERSE EN PANTALLA: es el archivo que acompaña la slide
// "El off-chain (Mesh.js)". La versión completa —cancelar, los casos que fallan,
// mandar los fondos a otro— está en pasos.ts.
//
// Lo que se importa de comun.ts es el andamiaje: de dónde salen las claves, cómo
// se lee el blueprint, cómo se traduce tiempo a slots. Vale mirarlo después.

import {
  CLAIM, ada, datosDe, datum, esperarTx, relojDelLedger,
  saldo, script, txBuilder, utxosDelScript, verificarCadenaViva,
} from "./comun.js";

await verificarCadenaViva();

const alice = await datosDe("alice");     // el owner: bloquea los fondos
const bob = await datosDe("bob");         // el beneficiario: los reclama
const s = script();                       // cbor + dirección, derivada del hash
const reloj = await relojDelLedger();     // para traducir tiempo ↔ slot

// --- 1. LOCK ----------------------------------------------------------------
// Alice manda 5 ADA a la dirección del script. Es una transferencia común:
// NO ejecuta el validator. El datum viaja pegado al output.

const deadlineMs = (reloj.tiempoDe(reloj.slotActual) + 300) * 1000;

const lock = txBuilder();
await lock
  .txOut(s.address, [{ unit: "lovelace", quantity: "5000000" }])
  .txOutInlineDatumValue(datum(bob.pubKeyHash, alice.pubKeyHash, deadlineMs))
  .changeAddress(alice.address)
  .selectUtxosFrom(await alice.w.getUtxos())
  .complete();

const hashLock = await alice.w.submitTx(await alice.w.signTx(lock.txHex));
await esperarTx(hashLock);
console.log(`LOCK   ${hashLock}\n       5 ADA en ${s.address}`);

// --- 2. CLAIM ---------------------------------------------------------------
// Bob gasta ese UTXO. Acá SÍ corre el validator, y hay que darle todo lo que
// necesita para decir que sí.

const [utxo] = await utxosDelScript();
const colateral = (await bob.w.getUtxos())
  .find((u) => u.output.amount.length === 1)!;   // el colateral no puede tener tokens
const antes = await saldo(bob.address);

const claim = txBuilder();
claim
  .spendingPlutusScript("V3")                    // la versión de Plutus, no el código
  .txIn(utxo.input.txHash, utxo.input.outputIndex,
        utxo.output.amount, utxo.output.address) // el UTXO bloqueado
  .txInScript(s.cbor)                            // el código del validator
  .txInInlineDatumPresent()                      // el datum ya está en la cadena
  .txInRedeemerValue(CLAIM)                      // Claim = constructor 0
  .requiredSignerHash(bob.pubKeyHash)            // declarar el firmante, no alcanza con firmar
  .txInCollateral(colateral.input.txHash, colateral.input.outputIndex,
                  colateral.output.amount, colateral.output.address)
  .invalidHereafter(reloj.slotDe(deadlineMs / 1000))  // sin esto, can_claim rechaza
  .changeAddress(bob.address);

await claim.complete();                          // balancea, calcula fee y ExUnits

const hashClaim = await bob.w.submitTx(await bob.w.signTx(claim.txHex));
await esperarTx(hashClaim);
console.log(`CLAIM  ${hashClaim}`);
console.log(`       Bob: ${ada(antes)} → ${ada(await saldo(bob.address))}`);
