// Las tres operaciones del escrow, como transacciones de verdad contra el devnet.
//
//   bloquear  — Alice manda ADA a la dirección del script. NO ejecuta el validator.
//   reclamar  — alguien gasta ese UTXO con el redeemer Claim. SÍ ejecuta el validator.
//   cancelar  — el owner lo recupera con el redeemer Cancel. SÍ ejecuta el validator.

import type { UTxO } from "@meshsdk/core";
import {
  CANCEL,
  CLAIM,
  type Actor,
  ada,
  c,
  campo,
  corto,
  datosDe,
  datum,
  esperarTx,
  nota,
  relojDelLedger,
  script,
  txBuilder,
} from "./comun.js";

/** Elige un UTXO de sólo-ADA para ofrecer como colateral (fase 2). */
async function colateral(w: any) {
  const propios = await w.getUtxos();
  const puro = propios.find(
    (u: UTxO) => u.output.amount.length === 1 && u.output.amount[0].unit === "lovelace",
  );
  if (!puro) throw new Error("No encontré un UTXO de sólo ADA para el colateral");
  return puro;
}

// -----------------------------------------------------------------------------
// BLOQUEAR (lock)
// -----------------------------------------------------------------------------
export async function bloquear(opts: {
  montoAda: number;
  segundosDeDeadline: number;
}) {
  const alice = await datosDe("alice");
  const bob = await datosDe("bob");
  const s = script();
  const reloj = await relojDelLedger();

  // El deadline se ancla al reloj DEL LEDGER (no al del host): así el rango de
  // validez que declare el claim y el deadline del datum hablan del mismo tiempo.
  const ahora = reloj.tiempoDe(reloj.slotActual);
  const deadlineMs = (ahora + opts.segundosDeDeadline) * 1000;
  const lovelace = String(opts.montoAda * 1_000_000);

  campo("de", `Alice  ${corto(alice.address, 12)}`);
  campo("a", `${c.b}la dirección del script${c.r}  ${corto(s.address, 12)}`);
  campo("valor", ada(lovelace));
  campo("datum", `beneficiary = ${bob.pubKeyHash}  ${c.d}(Bob)${c.r}`);
  campo("", `owner       = ${alice.pubKeyHash}  ${c.d}(Alice)${c.r}`);
  campo(
    "",
    `deadline    = ${deadlineMs}  ${c.d}(en ${opts.segundosDeDeadline}s)${c.r}`,
  );
  campo("script", `${c.d}—  esta tx NO ejecuta el validator${c.r}`);

  const utxos = await alice.w.getUtxos();
  const tx = txBuilder();
  await tx
    .txOut(s.address, [{ unit: "lovelace", quantity: lovelace }])
    .txOutInlineDatumValue(datum(bob.pubKeyHash, alice.pubKeyHash, deadlineMs))
    .changeAddress(alice.address)
    .selectUtxosFrom(utxos)
    .complete();

  const firmada = await alice.w.signTx(tx.txHex);
  const txHash = await alice.w.submitTx(firmada);
  await esperarTx(txHash);
  return { txHash, deadlineMs, scriptAddr: s.address };
}

// -----------------------------------------------------------------------------
// RECLAMAR (Claim) / CANCELAR (Cancel)
// -----------------------------------------------------------------------------
type GastoOpts = {
  actor: Actor;
  utxo: UTxO;
  deadlineMs: number;
  /** A dónde van los fondos. Por defecto, a quien gasta. */
  destino?: { nombre: string; address: string };
  /** Fuerza un rango de validez que arranca después del deadline. */
  tarde?: boolean;
};

async function gastar(modo: "Claim" | "Cancel", o: GastoOpts) {
  const quien = await datosDe(o.actor);
  const s = script();
  const reloj = await relojDelLedger();

  const lovelace =
    o.utxo.output.amount.find((a) => a.unit === "lovelace")?.quantity ?? "0";
  const destino = o.destino ?? { nombre: o.actor, address: quien.address };

  // Claim mira el tiempo; Cancel no. El rango se declara en slots y el ledger
  // lo traduce a POSIX ms para el ScriptContext.
  const slotDelDeadline = reloj.slotDe(Math.floor(o.deadlineMs / 1000));
  const hereafter =
    modo === "Claim"
      ? o.tarde
        ? reloj.slotActual + 120 // un tope que cae DESPUÉS del deadline
        : slotDelDeadline
      : undefined;

  campo("inputs", `${corto(o.utxo.input.txHash)} # ${o.utxo.input.outputIndex}   ← el UTXO del escrow`);
  campo("redeemer", modo);
  campo(
    "outputs",
    destino.nombre === o.actor
      ? `${ada(lovelace)} → ${destino.nombre}`
      : `${c.amar}${ada(lovelace)} → ${destino.nombre}${c.r}`,
  );
  campo("signatories", `[ ${o.actor}  ${corto(quien.pubKeyHash)} ]`);
  campo(
    "validity",
    hereafter === undefined
      ? `${c.d}(sin tope — Cancel no mira el tiempo)${c.r}`
      : `hasta el slot ${hereafter}  ${c.d}(el deadline cae en el slot ${slotDelDeadline}; ahora va por el ${reloj.slotActual})${c.r}`,
  );
  campo("script", `${c.b}sí — corre escrow.spend${c.r}`);

  const utxos = await quien.w.getUtxos();
  const col = await colateral(quien.w);

  const tx = txBuilder();
  tx.spendingPlutusScript("V3")
    .txIn(
      o.utxo.input.txHash,
      o.utxo.input.outputIndex,
      o.utxo.output.amount,
      o.utxo.output.address,
    )
    .txInScript(s.cbor)
    .txInInlineDatumPresent()
    .txInRedeemerValue(modo === "Claim" ? CLAIM : CANCEL)
    .requiredSignerHash(quien.pubKeyHash)
    .txInCollateral(
      col.input.txHash,
      col.input.outputIndex,
      col.output.amount,
      col.output.address,
    );

  if (o.destino) {
    // Mandar los fondos a otra dirección: el caso que el validator no mira.
    tx.txOut(o.destino.address, [{ unit: "lovelace", quantity: lovelace }]);
  }
  if (hereafter !== undefined) tx.invalidHereafter(hereafter);

  await tx.changeAddress(quien.address).selectUtxosFrom(utxos).complete();

  const firmada = await quien.w.signTx(tx.txHex);
  const txHash = await quien.w.submitTx(firmada);
  await esperarTx(txHash);
  return txHash;
}

export const reclamar = (o: GastoOpts) => gastar("Claim", o);
export const cancelar = (o: GastoOpts) => gastar("Cancel", o);

/**
 * Corre una operación que ESPERAMOS que falle y muestra por qué.
 * Devuelve true si efectivamente falló.
 */
export async function debeFallar(
  etiqueta: string,
  fn: () => Promise<string>,
): Promise<boolean> {
  try {
    const txHash = await fn();
    console.log(
      `    ${c.rojo}${c.b}¡PASÓ!${c.r}  ${etiqueta} debería haber fallado (tx ${corto(txHash)})`,
    );
    return false;
  } catch (e: any) {
    const msg = String(e?.message ?? e);
    console.log(`    ${c.verde}${c.b}rechazada${c.r}  la red no aceptó la transacción`);
    nota(motivo(msg));
    return true;
  }
}

/**
 * Traduce el error del nodo a algo que se pueda leer en pantalla.
 *
 * Ojo con el orden: un fallo de CBOR o de presupuesto también viaja adentro de
 * un `EvaluationFailure`, así que hay que descartarlos ANTES de concluir que el
 * validator dijo que no. Si no, la demo miente y muestra "el validator devolvió
 * False" cuando en realidad el bug está en el off-chain.
 */
function motivo(msg: string): string {
  if (/Failed to deserialise a script/i.test(msg)) {
    return "el nodo no pudo leer el script (bug del off-chain, no del validator)";
  }
  if (/ExUnits|budget|overspending/i.test(msg)) {
    return "el script se pasó del presupuesto de ejecución (ExUnits)";
  }
  if (/MissingRequiredSigners|MissingVKeyWitness/i.test(msg)) {
    return "falta una firma que el cuerpo de la tx declara como requerida";
  }
  if (/OutsideValidityInterval/i.test(msg)) {
    return "el rango de validez de la tx no incluye el slot actual";
  }
  // Aiken compila un `False` del validator a un `error` de UPLC: este es el
  // mensaje que deja el intérprete cuando el validator rechaza.
  if (/explicit use of 'error'|machine terminated because of an error/i.test(msg)) {
    return "el validator devolvió False → la transacción entera se rechaza";
  }
  return msg.slice(0, 300).replace(/\s+/g, " ");
}
