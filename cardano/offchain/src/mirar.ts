// Monitor de la cadena — la ventana para proyectar en clase (Clase 4).
//
//     npm run mirar
//
// Se queda mirando el devnet e imprime CADA transacción que entra, traducida a
// los actores del curso: quién gastó, quién cobró, cuánto se fue en fee, si
// corrió el validator. Pensado para tenerlo en una terminal al lado mientras en
// la otra se corre `npm run demo`: la clase ve la transacción aparecer en la
// cadena, no sólo el relato del script que la mandó.
//
// Por qué existe: el devnet no muestra NADA de esto por su cuenta. `devnet.sh
// logs` sólo tiene el banner de arranque, y los logs internos del nodo y de
// yaci-store son una pared de texto por segundo (un bloque cada 1s) donde una
// transacción real pasa desapercibida.
//
// Sale con Ctrl-C.

import {
  YACI_API,
  script,
  datosDe,
  ada,
  corto,
  c,
  type Actor,
} from "./comun.js";

// --- Quién es quién ----------------------------------------------------------
// Las direcciones son ilegibles y todas se parecen. Sin esto, la pantalla es
// una sopa de addr_test1... y no se entiende nada de lejos.
// Se indexa por dirección (para inputs/outputs) y por pubKeyHash (para los
// campos del datum, que guardan el hash, no la dirección).
type Conocidos = { addr: Map<string, string>; hash: Map<string, string> };

async function conocidos(): Promise<Conocidos> {
  const addr = new Map<string, string>();
  const hash = new Map<string, string>();
  for (const a of ["alice", "bob", "eve"] as Actor[]) {
    const { address, pubKeyHash } = await datosDe(a);
    const Nombre = a[0].toUpperCase() + a.slice(1);
    addr.set(address, Nombre);
    hash.set(pubKeyHash, Nombre);
  }
  addr.set(script().address, "el script");
  return { addr, hash };
}

const nombre = (m: Conocidos, addr: string | null | undefined) =>
  !addr ? "?" : (m.addr.get(addr) ?? corto(addr, 12));

const esScript = (m: Conocidos, addr: string) => m.addr.get(addr) === "el script";

/** Los hashes del datum, traducidos a nombres cuando se puede. */
const quienHash = (m: Conocidos, h: string) => m.hash.get(h) ?? corto(h, 6);

// --- La API ------------------------------------------------------------------
async function api<T>(ruta: string): Promise<T | null> {
  try {
    const r = await fetch(new URL(ruta, YACI_API));
    return r.ok ? ((await r.json()) as T) : null;
  } catch {
    return null;
  }
}

type Monto = { unit: string; quantity: string };
type Utxo = {
  address: string;
  amount: Monto[];
  inline_datum_json?: any;
};
type Tx = {
  hash: string;
  fees: number;
  slot: number;
  invalid?: boolean;
  inputs: Utxo[];
  outputs: Utxo[];
  collateral_inputs?: Utxo[];
  script_data_hash?: string | null;
};

const lovelace = (u: Utxo) =>
  BigInt(u.amount?.find((a) => a.unit === "lovelace")?.quantity ?? 0);

// --- Impresión ---------------------------------------------------------------
// La hora es la del reloj de la máquina en el momento de ver la transacción, no
// el campo `time` del bloque: en este devnet ese campo viene corrido (600 s), y
// proyectar una hora que no coincide con el reloj de la pared sólo confunde.
// El desfasaje es real y está documentado en cardano/offchain/README.md.
const hora = () => new Date().toLocaleTimeString("es-AR");

function mostrarDatumJson(m: Conocidos, d: any): string | null {
  const f = d?.fields;
  if (!Array.isArray(f) || f.length < 3) return null;
  return (
    `beneficiary=${quienHash(m, f[0]?.bytes ?? "?")} ` +
    `owner=${quienHash(m, f[1]?.bytes ?? "?")} ` +
    `deadline=${new Date(Number(f[2]?.int ?? 0)).toLocaleTimeString("es-AR")}`
  );
}

function mostrarTx(m: Conocidos, tx: Tx, alto: number) {
  const corrioScript = tx.inputs.some((i) => esScript(m, i.address));
  const marca = tx.invalid
    ? `${c.rojo}RECHAZADA (fase 2: se quema el colateral)${c.r}`
    : corrioScript
      ? `${c.amar}corre el validator${c.r}`
      : "";

  console.log(
    `\n${c.b}${c.cian}bloque #${alto}${c.r}  ${c.d}${hora()}${c.r}  ` +
      `${c.b}tx ${corto(tx.hash)}${c.r}  ${marca}`,
  );

  for (const i of tx.inputs) {
    const quien = nombre(m, i.address);
    const flecha = esScript(m, i.address) ? `${c.amar}◀ desde${c.r}` : "  gasta";
    console.log(`    ${flecha} ${quien.padEnd(12)} ${ada(lovelace(i))}`);
  }

  for (const o of tx.outputs) {
    const quien = nombre(m, o.address);
    const flecha = esScript(m, o.address) ? `${c.amar}▶ bloquea${c.r}` : "  → ";
    console.log(`    ${flecha} ${quien.padEnd(12)} ${ada(lovelace(o))}`);
    const d = o.inline_datum_json ? mostrarDatumJson(m, o.inline_datum_json) : null;
    if (d) console.log(`         ${c.d}datum: ${d}${c.r}`);
  }

  if (tx.collateral_inputs?.length && tx.invalid) {
    for (const col of tx.collateral_inputs) {
      console.log(
        `    ${c.rojo}  colateral${c.r} ${nombre(m, col.address).padEnd(12)} ` +
          `${ada(lovelace(col))} ${c.d}(perdido)${c.r}`,
      );
    }
  }

  console.log(`    ${c.d}  fee        ${ada(tx.fees ?? 0)}${c.r}`);
}

// --- El bucle ----------------------------------------------------------------
async function main() {
  const m = await conocidos();

  console.log(`${c.b}Mirando la cadena${c.r}  ${c.d}${YACI_API}${c.r}`);
  console.log(
    `${c.d}Alice, Bob, Eve y el script (${corto(script().address, 12)}). ` +
      `Ctrl-C para salir.${c.r}`,
  );

  const primero = await api<{ height: number }>("blocks/latest");
  if (!primero) {
    console.error(
      `\n${c.rojo}No pude hablar con el devnet en ${YACI_API}${c.r}\n` +
        "  Levantalo con:  ./scripts/devnet.sh up",
    );
    process.exit(1);
  }

  // Se arranca desde el bloque actual: interesa lo que pase de ahora en más, no
  // el historial. Con `--desde N` se puede revisar hacia atrás.
  const arg = process.argv.indexOf("--desde");
  let ultimo =
    arg !== -1 ? Number(process.argv[arg + 1]) - 1 : primero.height;

  console.log(`${c.d}En el bloque #${primero.height}. Esperando transacciones…${c.r}`);

  const tty = process.stdout.isTTY && !process.env.NO_COLOR;

  for (;;) {
    const latest = await api<{ height: number }>("blocks/latest");
    if (latest && latest.height > ultimo) {
      // Se recorren TODOS los bloques nuevos, no sólo el último: a 1 bloque por
      // segundo, un tirón del poll se comería transacciones enteras.
      for (let h = ultimo + 1; h <= latest.height; h++) {
        const b = await api<{ tx_count: number }>(`blocks/${h}`);
        if (!b) continue;
        if (b.tx_count > 0) {
          const txs = await api<{ tx_hash: string }[]>(`blocks/${h}/txs`);
          for (const t of txs ?? []) {
            const tx = await api<Tx>(`txs/${t.tx_hash}`);
            if (tx) mostrarTx(m, tx, h);
          }
        } else if (tty) {
          // Los bloques vacíos no ensucian la pantalla: una sola línea que se
          // pisa a sí misma y deja ver que la cadena está viva.
          process.stdout.write(
            `\r${c.d}bloque #${h} · sin transacciones${c.r}\x1b[K`,
          );
        }
      }
      ultimo = latest.height;
    }
    await new Promise((r) => setTimeout(r, 1000));
  }
}

main().catch((e) => {
  console.error(`\n${c.rojo}${e.message ?? e}${c.r}`);
  process.exit(1);
});
