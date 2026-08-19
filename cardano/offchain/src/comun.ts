// Piezas compartidas del off-chain del escrow (Clase 4).
//
// Todo apunta al devnet local de Yaci. Ver docs/guia-profesor/clase-04.md §5bis
// y cardano/offchain/README.md.

import {
  MeshWallet,
  MeshTxBuilder,
  YaciProvider,
  applyParamsToScript,
  resolveScriptHash,
  DEFAULT_V1_COST_MODEL_LIST,
  DEFAULT_V2_COST_MODEL_LIST,
  DEFAULT_V3_COST_MODEL_LIST,
  serializePlutusScript,
  deserializeAddress,
  deserializeDatum,
  mConStr0,
  mConStr1,
  type UTxO,
} from "@meshsdk/core";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const aca = dirname(fileURLToPath(import.meta.url));

// --- Conexión ----------------------------------------------------------------
// Desde el host: localhost. Desde adentro de un contenedor: el devnet vive en
// el host, así que hay que apuntar a host.containers.internal (Podman) o
// host.docker.internal (Docker). Se configura con YACI_API.
export const YACI_API =
  process.env.YACI_API ?? "http://localhost:8080/api/v1/";

// La API de administración del devnet (otro puerto). De acá sale el systemStart,
// que es lo único que permite convertir slots a POSIX time sin adivinar.
export const YACI_ADMIN =
  process.env.YACI_ADMIN ?? "http://localhost:10000/local-cluster/api/";

export const provider = new YaciProvider(YACI_API);

// YaciProvider no implementa fetchCostModels: Mesh atrapa la excepción, usa sus
// cost models por defecto y escupe un stack trace por cada transacción. El
// resultado es correcto (todas las txs evalúan bien), pero en una demo en vivo
// el ruido tapa la pantalla. Le pasamos explícitamente los MISMOS defaults que
// Mesh iba a usar, así no hay warning y no cambia nada del comportamiento.
(provider as any).fetchCostModels = async () => [
  DEFAULT_V1_COST_MODEL_LIST,
  DEFAULT_V2_COST_MODEL_LIST,
  DEFAULT_V3_COST_MODEL_LIST,
];

// --- Actores -----------------------------------------------------------------
// El devnet de Yaci deriva 20 cuentas prefinanciadas (10.000 ADA cada una) de
// este mnemonic conocido. Usamos las tres primeras. No hay ningún secreto acá:
// es un devnet descartable.
const MNEMONIC = ("test ".repeat(23) + "sauce").trim().split(" ");

export type Actor = "alice" | "bob" | "eve";

const CUENTA: Record<Actor, number> = { alice: 0, bob: 1, eve: 2 };

export function wallet(actor: Actor): MeshWallet {
  return new MeshWallet({
    networkId: 0,
    fetcher: provider,
    submitter: provider,
    key: { type: "mnemonic", words: MNEMONIC },
    accountIndex: CUENTA[actor],
  });
}

export async function datosDe(actor: Actor) {
  const w = wallet(actor);
  const address = await w.getChangeAddress();
  return { w, address, pubKeyHash: deserializeAddress(address).pubKeyHash };
}

// --- El validator ------------------------------------------------------------
// El CBOR sale del blueprint que genera `aiken build`. La dirección del script
// NO se "despliega": se deriva del hash del código compilado.
export function script() {
  const ruta = join(aca, "..", "..", "plutus.json");
  const bp = JSON.parse(readFileSync(ruta, "utf8"));
  const v = bp.validators.find((x: any) => x.title === "escrow.escrow.spend");
  if (!v) {
    throw new Error(
      `No encontré 'escrow.escrow.spend' en ${ruta}. ¿Corriste 'aiken build' en cardano/?`,
    );
  }
  // OJO: el `compiledCode` del blueprint viene con una sola capa de CBOR, y el
  // witness de la transacción necesita la doble. applyParamsToScript (con lista
  // de parámetros vacía, porque este validator no está parametrizado) devuelve
  // el CBOR envuelto como corresponde. Sin esto el nodo responde
  // "Failed to deserialise a script" y es un rato perdido.
  const cbor = applyParamsToScript(v.compiledCode, []);
  const address = serializePlutusScript({ code: cbor, version: "V3" }, undefined, 0)
    .address;
  const hash = resolveScriptHash(cbor, "V3");
  if (hash !== v.hash) {
    throw new Error(
      `El hash del script no coincide con el blueprint (${hash} vs ${v.hash}). ` +
        `¿Quedó un plutus.json viejo? Recorré 'aiken build' en cardano/.`,
    );
  }
  return { cbor, address, hash };
}

// --- Datum y redeemer --------------------------------------------------------
// Datum { beneficiary: ByteArray, owner: ByteArray, deadline: Int }
//   -> constructor 0 con tres campos, en el orden en que los declara el tipo.
export const datum = (beneficiary: string, owner: string, deadlineMs: number) =>
  mConStr0([beneficiary, owner, deadlineMs]);

// Redeemer { Claim | Cancel } -> constructor 0 y constructor 1, sin campos.
export const CLAIM = mConStr0([]);
export const CANCEL = mConStr1([]);

// --- Tiempo y slots ----------------------------------------------------------
// El validator compara contra POSIX time en ms, pero la transacción declara su
// rango de validez en SLOTS: el ledger traduce. En vez de hardcodear el génesis
// del devnet, derivamos la relación del propio ledger.
// OJO: NO sirve derivar la relación slot↔tiempo del campo `time` de
// /blocks/latest — en el devnet viene corrido respecto del reloj del ledger (lo
// vimos: 600 s de diferencia, y el claim de Bob se rechazaba por eso). La única
// fuente correcta es el `systemStart` del génesis de Shelley:
//
//     tiempo(slot) = systemStart + slot × slotLength
export async function relojDelLedger() {
  const g = await fetch(new URL("admin/devnet/genesis/shelley", YACI_ADMIN));
  if (!g.ok) {
    throw new Error(
      `No pude leer el génesis del devnet en ${YACI_ADMIN} (${g.status}). ` +
        `¿Está levantado? Probá 'scripts/devnet.sh estado'.`,
    );
  }
  const gen: any = await g.json();
  const systemStart = Math.floor(new Date(gen.systemStart).getTime() / 1000);
  const slotLength: number = gen.slotLength ?? 1;

  const b: any = await (await fetch(new URL("blocks/latest", YACI_API))).json();

  return {
    systemStart,
    slotLength,
    /** el slot en el que va la cadena ahora */
    slotActual: b.slot as number,
    /** slot que corresponde a un unix time en segundos */
    slotDe: (unixSeg: number) => Math.floor((unixSeg - systemStart) / slotLength),
    /** unix time en segundos que corresponde a un slot */
    tiempoDe: (slot: number) => systemStart + slot * slotLength,
  };
}

export function txBuilder() {
  return new MeshTxBuilder({
    fetcher: provider,
    submitter: provider,
    evaluator: provider,
    verbose: false,
  });
}

// --- Consultas ---------------------------------------------------------------
export async function saldo(address: string): Promise<bigint> {
  const utxos = await provider.fetchAddressUTxOs(address);
  return utxos.reduce(
    (t, u) =>
      t + BigInt(u.output.amount.find((a) => a.unit === "lovelace")?.quantity ?? 0),
    0n,
  );
}

export async function utxosDelScript(): Promise<UTxO[]> {
  return provider.fetchAddressUTxOs(script().address);
}

async function alturaActual(): Promise<number | null> {
  try {
    const r = await fetch(new URL("blocks/latest", YACI_API));
    if (!r.ok) return null;
    return ((await r.json()) as any).height ?? null;
  } catch {
    return null;
  }
}

const CADENA_DETENIDA =
  "La cadena NO está produciendo bloques.\n" +
  "  El nodo sigue vivo y la API contesta, pero dejó de forjar — a este devnet le\n" +
  "  pasa si queda corriendo varias horas. Ninguna transacción va a entrar.\n" +
  "  Se arregla asi:  ./scripts/devnet.sh reset && ./scripts/devnet.sh up";

/**
 * Chequea que el devnet esté vivo Y avanzando, antes de mandar nada.
 *
 * Que la API conteste no alcanza: si el nodo dejó de forjar, todo parece normal
 * hasta que la primera transaccion se queda esperando para siempre. Mejor fallar
 * acá, con un mensaje que diga qué hacer.
 */
export async function verificarCadenaViva() {
  const a = await alturaActual();
  if (a === null) {
    throw new Error(
      `No pude hablar con el devnet en ${YACI_API}\n` +
        "  Levantalo con:  ./scripts/devnet.sh up",
    );
  }
  for (let i = 0; i < 6; i++) {
    await new Promise((r) => setTimeout(r, 1000));
    const b = await alturaActual();
    if (b !== null && b > a) return;
  }
  throw new Error(CADENA_DETENIDA);
}

/** Espera a que la tx aparezca en el ledger. En el devnet son ~1-2 bloques. */
export async function esperarTx(txHash: string, timeoutMs = 60_000) {
  const hasta = Date.now() + timeoutMs;
  const alturaInicial = await alturaActual();
  while (Date.now() < hasta) {
    try {
      const r = await fetch(new URL(`txs/${txHash}`, YACI_API));
      if (r.ok) return;
    } catch {
      /* el nodo todavía no la indexó */
    }
    await new Promise((r) => setTimeout(r, 1000));
  }
  // Distinguir "la tx no entró" de "la cadena está muerta": si la altura no se
  // movió en todo ese tiempo, el problema no es la transacción.
  const alturaFinal = await alturaActual();
  if (alturaInicial !== null && alturaFinal === alturaInicial) {
    throw new Error(CADENA_DETENIDA);
  }
  throw new Error(
    `La tx ${txHash} no aparecio en ${timeoutMs / 1000}s (la cadena sí avanza).`,
  );
}

// --- Presentación ------------------------------------------------------------
const tty = process.stdout.isTTY && !process.env.NO_COLOR;
export const c = {
  b: tty ? "\x1b[1m" : "",
  d: tty ? "\x1b[2m" : "",
  r: tty ? "\x1b[0m" : "",
  verde: tty ? "\x1b[32m" : "",
  rojo: tty ? "\x1b[31m" : "",
  amar: tty ? "\x1b[33m" : "",
  cian: tty ? "\x1b[36m" : "",
};

export const ada = (lovelace: bigint | string | number) =>
  `${(Number(lovelace) / 1_000_000).toLocaleString("es-AR", {
    maximumFractionDigits: 6,
  })} ADA`;

export const corto = (s: string, n = 8) =>
  s.length <= n * 2 ? s : `${s.slice(0, n)}…${s.slice(-4)}`;

export function titulo(t: string) {
  console.log(`\n${c.b}${c.cian}${t}${c.r}\n`);
}

export function campo(k: string, v: string) {
  console.log(`    ${k.padEnd(15)}${v}`);
}

export function nota(t: string) {
  console.log(`  ${c.d}${t}${c.r}`);
}

export function linea() {
  console.log(`${c.d}${"─".repeat(72)}${c.r}`);
}

/** Decodifica el datum inline de un UTXO del script y lo muestra legible. */
export function mostrarDatum(u: UTxO) {
  const hex = u.output.plutusData;
  if (!hex) {
    campo("datum", `${c.amar}(ninguno)${c.r}`);
    return null;
  }
  const d: any = deserializeDatum(hex);
  const campos = d.fields ?? [];
  const beneficiary = campos[0]?.bytes ?? "?";
  const owner = campos[1]?.bytes ?? "?";
  const deadline = Number(campos[2]?.int ?? 0);
  campo("datum", `beneficiary = ${beneficiary}`);
  campo("", `owner       = ${owner}`);
  campo(
    "",
    `deadline    = ${deadline}  ${c.d}(${new Date(deadline).toLocaleTimeString("es-AR")})${c.r}`,
  );
  return { beneficiary, owner, deadline };
}

/** Pausa hasta que el profesor apriete enter (salvo --sin-pausa / no TTY). */
export async function pausa() {
  if (process.env.SIN_PAUSA === "1" || !process.stdin.isTTY) {
    console.log("");
    return;
  }
  process.stdout.write(`${c.d}  [enter]${c.r}`);
  await new Promise<void>((res) => {
    process.stdin.setEncoding("utf8");
    process.stdin.resume();
    process.stdin.once("data", () => {
      process.stdin.pause();
      res();
    });
  });
  console.log("");
}
