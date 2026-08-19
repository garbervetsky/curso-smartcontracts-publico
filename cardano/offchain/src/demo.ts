// Demo paso a paso del escrow, con transacciones REALES contra el devnet local.
//
//   npm run demo                # los tres actos, pausando entre pasos
//   npm run demo -- --acto 3    # sólo un acto
//   SIN_PAUSA=1 npm run demo    # de corrido (para revisar antes de la clase)
//
// Es la hermana de scripts/demo-tx-cardano.sh: aquella ejecuta el validator
// aislado y no toca la red; esta manda transacciones de verdad, paga fees y
// mueve saldos. Ver docs/guia-profesor/clase-04.md §5bis.

import {
  ada,
  c,
  campo,
  corto,
  datosDe,
  linea,
  mostrarDatum,
  nota,
  pausa,
  saldo,
  script,
  titulo,
  utxosDelScript,
  verificarCadenaViva,
  YACI_API,
} from "./comun.js";
import { bloquear, cancelar, debeFallar, reclamar } from "./pasos.js";
import type { UTxO } from "@meshsdk/core";

const arg = process.argv.indexOf("--acto");
const SOLO = arg >= 0 ? Number(process.argv[arg + 1]) : null;

const dormir = (s: number) => new Promise((r) => setTimeout(r, s * 1000));

const verTx = (h: string) => nota(`${YACI_API}txs/${h}`);

/** El UTXO que dejó una tx de lock en la dirección del script. */
async function utxoDe(txHash: string): Promise<UTxO> {
  const u = (await utxosDelScript()).find((x) => x.input.txHash === txHash);
  if (!u) throw new Error(`No encontré el UTXO de ${txHash} en el script`);
  return u;
}

async function mostrarUtxoBloqueado(u: UTxO) {
  campo("ref", `${corto(u.input.txHash)} # ${u.input.outputIndex}`);
  campo(
    "valor",
    ada(u.output.amount.find((a) => a.unit === "lovelace")!.quantity),
  );
  return mostrarDatum(u)!;
}

// -----------------------------------------------------------------------------
async function escenario() {
  titulo("EL ESCENARIO");
  const s = script();
  for (const quien of ["alice", "bob", "eve"] as const) {
    const d = await datosDe(quien);
    campo(quien, `${corto(d.address, 14)}   ${ada(await saldo(d.address))}`);
    campo("", `${c.d}pubKeyHash ${d.pubKeyHash}${c.r}`);
  }
  console.log("");
  campo("script", corto(s.address, 14));
  campo("", `${c.d}hash ${s.hash}${c.r}`);
  nota("Esta dirección no se «desplegó»: se deriva del hash del código compilado.");
  nota("Existe desde siempre; empieza a importar cuando alguien manda un UTXO ahí.");
  linea();
  await pausa();
}

// -----------------------------------------------------------------------------
async function acto1() {
  titulo("ACTO 1 · El escrow que funciona");

  console.log(`  ${c.b}PASO 1${c.r}  Alice bloquea 100 ADA`);
  const lock = await bloquear({ montoAda: 100, segundosDeDeadline: 600 });
  console.log(`    ${c.verde}aceptada${c.r}       ${lock.txHash}`);
  verTx(lock.txHash);
  nota("Ninguna firma de Bob, ningún redeemer, ningún script: fue una transferencia común.");
  await pausa();

  console.log(`  ${c.b}PASO 2${c.r}  El UTXO quedó esperando en la dirección del script`);
  const u = await utxoDe(lock.txHash);
  const d = await mostrarUtxoBloqueado(u);
  nota("Cualquiera lo ve. Nadie lo puede tocar sin pasar por spend.");
  await pausa();

  console.log(`  ${c.b}PASO 3${c.r}  Eve intenta reclamarlo`);
  await debeFallar("Eve", () =>
    reclamar({ actor: "eve", utxo: u, deadlineMs: d.deadline }),
  );
  nota("Fase 2: el validator corrió, dijo False, y se cae la transacción entera.");
  nota("El UTXO sigue intacto — y Eve perdió el colateral que ofreció.");
  await pausa();

  console.log(`  ${c.b}PASO 4${c.r}  Bob reclama`);
  const bob = await datosDe("bob");
  const antes = await saldo(bob.address);
  const h = await reclamar({ actor: "bob", utxo: u, deadlineMs: d.deadline });
  console.log(`    ${c.verde}aceptada${c.r}       ${h}`);
  verTx(h);
  campo("saldo de Bob", `${ada(antes)} → ${c.b}${ada(await saldo(bob.address))}${c.r}`);
  nota("El validator no movió un ADA: sólo autorizó. El destino lo puso la tx de Bob.");
  linea();
  await pausa();
}

// -----------------------------------------------------------------------------
async function acto2() {
  titulo("ACTO 2 · El deadline");

  const segundos = 20;
  console.log(`  ${c.b}PASO 1${c.r}  Alice bloquea 50 ADA con un deadline de ${segundos}s`);
  const lock = await bloquear({ montoAda: 50, segundosDeDeadline: segundos });
  console.log(`    ${c.verde}aceptada${c.r}       ${lock.txHash}`);
  const u = await utxoDe(lock.txHash);
  await pausa();

  console.log(`  ${c.b}PASO 2${c.r}  Esperamos a que venza…`);
  for (let i = segundos + 10; i > 0; i -= 5) {
    process.stdout.write(`\r    ${c.d}faltan ~${i}s${c.r}   `);
    await dormir(5);
  }
  console.log(`\r    ${c.amar}el deadline venció${c.r}          `);
  await pausa();

  console.log(`  ${c.b}PASO 3${c.r}  Bob reclama, tarde`);
  await debeFallar("claim tarde", () =>
    reclamar({ actor: "bob", utxo: u, deadlineMs: lock.deadlineMs, tarde: true }),
  );
  nota("La firma estaba bien. Lo que falló es el rango de validez contra el deadline.");
  await pausa();

  console.log(`  ${c.b}PASO 4${c.r}  Alice cancela y recupera`);
  const alice = await datosDe("alice");
  const antes = await saldo(alice.address);
  const h = await cancelar({ actor: "alice", utxo: u, deadlineMs: lock.deadlineMs });
  console.log(`    ${c.verde}aceptada${c.r}       ${h}`);
  verTx(h);
  campo("saldo de Alice", `${ada(antes)} → ${c.b}${ada(await saldo(alice.address))}${c.r}`);
  nota("can_cancel sólo pide la firma del owner: no mira el tiempo.");
  linea();
  await pausa();
}

// -----------------------------------------------------------------------------
async function acto3() {
  titulo("ACTO 3 · El agujero (gancho de la Clase 9)");

  console.log(`  ${c.b}PASO 1${c.r}  Alice bloquea 100 ADA para Bob, otra vez`);
  const lock = await bloquear({ montoAda: 100, segundosDeDeadline: 600 });
  const u = await utxoDe(lock.txHash);
  const d = await mostrarUtxoBloqueado(u);
  await pausa();

  console.log(
    `  ${c.b}PASO 2${c.r}  Bob arma el claim… pero manda los fondos a ${c.amar}Eve${c.r}`,
  );
  const eve = await datosDe("eve");
  const bob = await datosDe("bob");
  const eveAntes = await saldo(eve.address);
  const bobAntes = await saldo(bob.address);
  const h = await reclamar({
    actor: "bob",
    utxo: u,
    deadlineMs: d.deadline,
    destino: { nombre: "Eve", address: eve.address },
  });
  console.log(`    ${c.rojo}${c.b}ACEPTADA${c.r}       ${h}`);
  verTx(h);
  campo("saldo de Eve", `${ada(eveAntes)} → ${c.b}${ada(await saldo(eve.address))}${c.r}`);
  campo("saldo de Bob", `${ada(bobAntes)} → ${ada(await saldo(bob.address))}`);
  console.log("");
  console.log(
    `  ${c.amar}El validator verificó que Bob FIRMARA. Nunca miró a dónde iba la plata.${c.r}`,
  );
  nota("list.has(extra_signatories, beneficiary) — y nada más.");
  nota("Los 100 ADA terminaron en Eve y la red lo aceptó sin chistar.");
  nota("Ese hueco es lo que se explota en la Clase 9.");
  linea();
  await pausa();
}

// -----------------------------------------------------------------------------
async function main() {
  console.log(`${c.d}devnet: ${YACI_API}${c.r}`);
  await verificarCadenaViva();
  const actos = [acto1, acto2, acto3];
  if (SOLO === null) {
    await escenario();
    for (const a of actos) await a();
  } else {
    if (!actos[SOLO - 1]) throw new Error(`No hay acto ${SOLO} (hay ${actos.length})`);
    await escenario();
    await actos[SOLO - 1]();
  }
  console.log(`\n${c.b}Listo.${c.r} Todo esto ocurrió de verdad en el devnet.\n`);
  process.exit(0);
}

main().catch((e) => {
  const msg = String(e?.message ?? e);
  console.error(`\n${c.rojo}Se cortó la demo:${c.r} ${msg}`);
  // Si el error ya dice qué comando correr, no lo contradigas con otro.
  if (!msg.includes("devnet.sh")) {
    console.error(
      `${c.d}Si el devnet no está levantado: ./scripts/devnet.sh up${c.r}`,
    );
  }
  process.exit(1);
});
