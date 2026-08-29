// Mesh armando la transacción de Claim, PASO POR PASO Y SIN RED.
//
// Es la contracara de `demo.ts`: aquella manda transacciones de verdad contra el
// devnet de Yaci y necesita infraestructura levantada. Esta no toca la red — ni
// devnet, ni internet — y corre en un par de segundos:
//
//     npm run demo-sin-red
//
// Sirve para mostrar exactamente el código de la slide "El off-chain (Mesh.js)".
// Lo que se ve es el ARMADO de la transacción, que es donde vive la complejidad
// del off-chain en EUTXO. Lo único que no se ve es el envío, porque para eso hace
// falta una cadena: ahí entra `npm run demo`.
//
// El truco para que funcione sin red es OfflineFetcher: se le cargan a mano los
// parámetros de protocolo y los UTXOs, en vez de que salga a buscarlos.

import {
  DEFAULT_V1_COST_MODEL_LIST,
  DEFAULT_V2_COST_MODEL_LIST,
  DEFAULT_V3_COST_MODEL_LIST,
  MeshTxBuilder,
  MeshWallet,
  OfflineFetcher,
  applyParamsToScript,
  deserializeAddress,
  mConStr0,
  resolveScriptHash,
  serializeData,
  serializePlutusScript,
  type UTxO,
} from "@meshsdk/core";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

import { ada, c, campo, corto, linea, nota, titulo } from "./comun.js";

const aca = dirname(fileURLToPath(import.meta.url));

// Los UTXOs son inventados, así que los hashes también. Se marcan como tales
// para que nadie los confunda con datos de una cadena real.
const TX_DEL_LOCK = "1c".repeat(32);
const TX_DE_BOB = "2b".repeat(32);

const MONTO_BLOQUEADO = "5000000"; // 5 ADA
const FONDOS_DE_BOB = "10000000"; // 10 ADA, para fee y colateral

// ExUnits fijas. Contra una cadena las calcula el evaluador del provider; acá no
// hay cadena a la que preguntarle, así que se declaran. Son holgadas a propósito:
// lo que importa es el armado, no afinar el presupuesto.
const EX_UNITS = { mem: 500_000, steps: 200_000_000 };

// El validator compara el deadline (POSIX ms) contra la validity_range de la tx,
// que se declara en SLOTS. Traducir de uno a otro necesita el génesis del ledger:
//
//     tiempo(slot) = systemStart + slot × slotLength
//
// Contra una cadena eso sale de /genesis/shelley — ver relojDelLedger() en
// comun.ts. Acá no hay ledger, así que los fijamos. Son inventados pero
// coherentes entre sí, y hacen que la demo dé siempre lo mismo.
const SYSTEM_START = 1_788_000_000; // unix seg
const SLOT_LENGTH = 1; // seg por slot, como el devnet del curso

const SLOT_DEL_DEADLINE = 3600; // una hora de cadena
const DEADLINE_MS = (SYSTEM_START + SLOT_DEL_DEADLINE * SLOT_LENGTH) * 1000;

async function main() {
  // ---------------------------------------------------------------------------
  titulo("1 · El validator: del blueprint a una dirección");

  const ruta = join(aca, "..", "..", "plutus.json");
  const bp = JSON.parse(readFileSync(ruta, "utf8"));
  const v = bp.validators.find((x: any) => x.title === "escrow.escrow.spend");
  if (!v) {
    throw new Error(
      `No encontré 'escrow.escrow.spend' en ${ruta}. ¿Corriste 'aiken build' en cardano/?`,
    );
  }

  // El compiledCode del blueprint viene con una capa de CBOR; el witness necesita
  // la doble. applyParamsToScript con lista vacía (este validator no está
  // parametrizado) devuelve el envoltorio correcto.
  const cbor = applyParamsToScript(v.compiledCode, []);
  const scriptAddr = serializePlutusScript({ code: cbor, version: "V3" }, undefined, 0)
    .address;

  campo("blueprint", `cardano/plutus.json  ${c.d}(lo genera 'aiken build')${c.r}`);
  campo("validator", v.title);
  campo("hash", resolveScriptHash(cbor, "V3"));
  campo("dirección", scriptAddr);
  nota("La dirección NO se despliega: se deriva del hash del código compilado.");

  // ---------------------------------------------------------------------------
  titulo("2 · Los actores, derivados de claves (sin red)");

  const MNEMONIC = ("test ".repeat(23) + "sauce").trim().split(" ");
  const fetcher = new OfflineFetcher();

  const pp = JSON.parse(readFileSync(join(aca, "parametros-protocolo.json"), "utf8"));
  fetcher.addProtocolParameters(pp);
  // OfflineFetcher no implementa fetchCostModels y Mesh escupe un stack trace por
  // cada tx. Le pasamos los mismos defaults que iba a usar igual: no cambia nada
  // del resultado, y la pantalla queda limpia para la demo.
  (fetcher as any).fetchCostModels = async () => [
    DEFAULT_V1_COST_MODEL_LIST,
    DEFAULT_V2_COST_MODEL_LIST,
    DEFAULT_V3_COST_MODEL_LIST,
  ];

  const billetera = (indice: number) =>
    new MeshWallet({
      networkId: 0,
      fetcher,
      key: { type: "mnemonic", words: MNEMONIC },
      accountIndex: indice,
    });

  const aliceAddr = await billetera(0).getChangeAddress();
  const bob = billetera(1);
  const bobAddr = await bob.getChangeAddress();
  const alicePkh = deserializeAddress(aliceAddr).pubKeyHash;
  const bobPkh = deserializeAddress(bobAddr).pubKeyHash;

  campo("Alice (owner)", `${corto(aliceAddr, 14)}  pkh ${corto(alicePkh)}`);
  campo("Bob (benefic.)", `${corto(bobAddr, 14)}  pkh ${corto(bobPkh)}`);
  nota("Salen del mnemonic conocido del devnet. Ninguna clave sale de acá.");

  // ---------------------------------------------------------------------------
  titulo("3 · El UTXO bloqueado (como si el LOCK ya hubiera pasado)");

  const datumEscrow = mConStr0([bobPkh, alicePkh, DEADLINE_MS]);
  const datumHex = serializeData(datumEscrow, "Mesh");

  const utxoDelEscrow: UTxO = {
    input: { txHash: TX_DEL_LOCK, outputIndex: 0 },
    output: {
      address: scriptAddr,
      amount: [{ unit: "lovelace", quantity: MONTO_BLOQUEADO }],
      plutusData: datumHex,
    },
  };

  const utxoDeBob: UTxO = {
    input: { txHash: TX_DE_BOB, outputIndex: 0 },
    output: {
      address: bobAddr,
      amount: [{ unit: "lovelace", quantity: FONDOS_DE_BOB }],
    },
  };

  fetcher.addUTxOs([utxoDelEscrow, utxoDeBob]);

  campo("en", `${corto(scriptAddr, 14)}  ${c.d}(dirección del script)${c.r}`);
  campo("valor", ada(MONTO_BLOQUEADO));
  campo("datum", `beneficiary = ${corto(bobPkh)}  ${c.d}(Bob)${c.r}`);
  campo("", `owner       = ${corto(alicePkh)}  ${c.d}(Alice)${c.r}`);
  campo("", `deadline    = ${DEADLINE_MS}  ${c.d}(slot ${SLOT_DEL_DEADLINE})${c.r}`);
  campo("datum (CBOR)", corto(datumHex, 24));
  nota("Va inline en el UTXO: el que gasta no tiene que aportarlo, ya está en la cadena.");

  // ---------------------------------------------------------------------------
  titulo("4 · Bob arma el Claim — esto es lo que hace Mesh");

  const tx = new MeshTxBuilder({ fetcher, verbose: false });

  tx.spendingPlutusScript("V3") //                    versión de Plutus, NO el CBOR
    .txIn(
      utxoDelEscrow.input.txHash, //                   el UTXO bloqueado
      utxoDelEscrow.input.outputIndex,
      utxoDelEscrow.output.amount,
      utxoDelEscrow.output.address,
    )
    .txInScript(cbor) //                               acá sí va el código del validator
    .txInInlineDatumPresent() //                       el datum ya está en la cadena
    .txInRedeemerValue(mConStr0([]), "Mesh", EX_UNITS) // Claim = constructor 0
    .requiredSignerHash(bobPkh) //                     declarar el firmante
    .txInCollateral(
      //                                               colateral: se pierde si el
      utxoDeBob.input.txHash, //                       script falla en fase 2
      utxoDeBob.input.outputIndex,
      utxoDeBob.output.amount,
      utxoDeBob.output.address,
    )
    .invalidHereafter(SLOT_DEL_DEADLINE) //             ← SIN esto el Claim se rechaza
    .changeAddress(bobAddr)
    .selectUtxosFrom([utxoDeBob]);

  await tx.complete();

  campo("input", `${corto(TX_DEL_LOCK)} # 0   ${c.d}← el UTXO del escrow${c.r}`);
  campo("redeemer", `Claim  ${c.d}(constructor 0, sin campos)${c.r}`);
  campo("script", `${c.b}sí — corre escrow.spend${c.r}`);
  campo("signatories", `[ Bob  ${corto(bobPkh)} ]`);
  campo("colateral", `${corto(TX_DE_BOB)} # 0`);
  campo("validity", `hasta el slot ${SLOT_DEL_DEADLINE}  ${c.d}(el del deadline)${c.r}`);
  nota(
    "Ese último es el que más se olvida: can_claim exige que la validity_range esté",
  );
  nota(
    "contenida en (-∞, deadline]. Sin invalidHereafter el rango es infinito y falla.",
  );

  // ---------------------------------------------------------------------------
  titulo("5 · La transacción armada");

  const hex = tx.txHex;
  campo("tamaño", `${hex.length / 2} bytes de CBOR`);
  campo("CBOR", `${hex.slice(0, 64)}…`);

  const firmada = await bob.signTx(hex);
  campo("firmada", `${firmada.length / 2} bytes  ${c.d}(+${(firmada.length - hex.length) / 2} del witness)${c.r}`);

  linea();
  console.log(
    `\n  ${c.b}Eso es todo el off-chain${c.r}: encontrar el UTXO, aportar el redeemer,\n` +
      `  declarar el firmante, poner colateral, balancear y firmar.\n` +
      `  El validator on-chain que autoriza todo esto tiene ${c.b}5 líneas${c.r}.\n`,
  );
  nota("Falta un paso: submitTx. Para eso hace falta una cadena → npm run demo");
  console.log("");
}

main().catch((e) => {
  console.error(`\n${c.rojo}${e.message ?? e}${c.r}\n`);
  process.exit(1);
});
