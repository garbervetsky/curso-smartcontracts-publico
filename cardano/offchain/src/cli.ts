// Las operaciones sueltas, para improvisar en clase o para el taller.
//
//   npm run estado                     # qué hay en la dirección del script
//   npm run lock   -- --ada 100 --seg 600
//   npm run claim  -- [--como bob|eve] [--a eve] [--tarde]
//   npm run cancel
//
// Si hay varios UTXOs bloqueados, se opera sobre el primero salvo que pases
// --utxo <txHash>.

import {
  ada,
  c,
  campo,
  corto,
  datosDe,
  mostrarDatum,
  saldo,
  script,
  titulo,
  utxosDelScript,
  verificarCadenaViva,
  type Actor,
} from "./comun.js";
import { bloquear, cancelar, reclamar } from "./pasos.js";

const argv = process.argv.slice(2);
const cmd = argv[0];

function opt(nombre: string, def?: string) {
  const i = argv.indexOf(`--${nombre}`);
  return i >= 0 ? argv[i + 1] : def;
}
const flag = (nombre: string) => argv.includes(`--${nombre}`);

async function elegirUtxo() {
  const us = await utxosDelScript();
  if (us.length === 0) {
    throw new Error("No hay ningún UTXO bloqueado. Corré 'npm run lock' primero.");
  }
  const pedido = opt("utxo");
  const u = pedido ? us.find((x) => x.input.txHash.startsWith(pedido)) : us[0];
  if (!u) throw new Error(`No encontré un UTXO que empiece con ${pedido}`);
  const d = mostrarDatum(u);
  if (!d) throw new Error("Ese UTXO no tiene datum: el validator no lo puede evaluar.");
  return { u, d };
}

async function main() {
  // "estado" es solo lectura: no hace falta que la cadena avance.
  if (cmd !== "estado") await verificarCadenaViva();
  switch (cmd) {
    case "estado": {
      titulo("SALDOS");
      for (const quien of ["alice", "bob", "eve"] as const) {
        const d = await datosDe(quien);
        campo(quien, ada(await saldo(d.address)));
      }
      titulo("DIRECCIÓN DEL SCRIPT");
      campo("address", script().address);
      campo("hash", script().hash);
      const us = await utxosDelScript();
      titulo(`UTXOs BLOQUEADOS (${us.length})`);
      for (const u of us) {
        campo("ref", `${corto(u.input.txHash)} # ${u.input.outputIndex}`);
        campo(
          "valor",
          ada(u.output.amount.find((a) => a.unit === "lovelace")!.quantity),
        );
        mostrarDatum(u);
        console.log("");
      }
      break;
    }

    case "lock": {
      titulo("BLOQUEAR");
      const r = await bloquear({
        montoAda: Number(opt("ada", "100")),
        segundosDeDeadline: Number(opt("seg", "600")),
      });
      console.log(`\n    ${c.verde}aceptada${c.r}  ${r.txHash}`);
      break;
    }

    case "claim": {
      const actor = (opt("como", "bob") as Actor) ?? "bob";
      titulo(`RECLAMAR (como ${actor})`);
      const { u, d } = await elegirUtxo();
      const aQuien = opt("a");
      const destino = aQuien
        ? { nombre: aQuien, address: (await datosDe(aQuien as Actor)).address }
        : undefined;
      const h = await reclamar({
        actor,
        utxo: u,
        deadlineMs: d.deadline,
        destino,
        tarde: flag("tarde"),
      });
      console.log(`\n    ${c.verde}aceptada${c.r}  ${h}`);
      break;
    }

    case "cancel": {
      titulo("CANCELAR");
      const { u, d } = await elegirUtxo();
      const h = await cancelar({ actor: "alice", utxo: u, deadlineMs: d.deadline });
      console.log(`\n    ${c.verde}aceptada${c.r}  ${h}`);
      break;
    }

    default:
      console.log("uso: estado | lock | claim | cancel   (ver el encabezado de cli.ts)");
      process.exit(1);
  }
  process.exit(0);
}

main().catch((e) => {
  console.error(`\n${c.rojo}Falló:${c.r} ${e?.message ?? e}`);
  process.exit(1);
});
