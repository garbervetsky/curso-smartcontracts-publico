# Off-chain del escrow — transacciones reales (Clase 4)

Arma y manda **transacciones de verdad** contra un devnet local de Cardano
([Yaci DevKit](https://devkit.yaci.xyz)). Bloquea ADA en la dirección del
validator, las reclama, las cancela — con fees, colateral, firmas y saldos que
se mueven.

> Hay **tres demos** de la Clase 4 y hacen cosas distintas:
>
> | | qué hace | red |
> |---|---|---|
> | `scripts/demo-tx-cardano.sh` | ejecuta el validator aislado sobre transacciones armadas a mano | **ninguna** |
> | `npm run demo-simple` | **bloquea y reclama**, en 40 líneas legibles | devnet local |
> | `npm run demo` | el recorrido completo, con los tres actos | devnet local |
>
> La primera explica el modelo y nunca falla. La segunda es la que acompaña la
> slide "El off-chain (Mesh.js)": el mismo código, corriendo. La tercera es el
> recorrido narrado, incluido el agujero del escrow.
> Ver `docs/guia-profesor/clase-04.md` §5, §5ter y §5bis.

## El ciclo mínimo (`npm run demo-simple`)

```bash
./scripts/devnet.sh up          # terminal 1
cd cardano/offchain && npm run demo-simple
```

Bloquea 5 ADA para Bob y se los deja reclamar. Nada más. Son **~40 líneas de
código**, escritas para leerse en pantalla mientras se explica: el `lock` (que no
ejecuta el validator) y el `claim` (que sí), con la cadena de `MeshTxBuilder`
comentada línea por línea.

El andamiaje —de dónde salen las claves, cómo se lee el blueprint, cómo se
traduce tiempo a slots— vive en `comun.ts`, y por eso el archivo entra de un
vistazo. `pasos.ts` es la versión completa: agrega cancelar, los casos que deben
fallar, y mandar los fondos a otra dirección.

## Arrancar

**El devnet corre en tu máquina, no adentro del contenedor del curso.** Levanta un
contenedor propio, así que hacen falta **dos terminales**:

```bash
# TERMINAL 1 — en tu máquina (el host), desde la raíz del repo
./scripts/devnet.sh up          # la 1ª vez tarda unos minutos: baja el cardano-node
```

```bash
# TERMINAL 2 — acá sí da igual: host o adentro del contenedor
cd cardano/offchain
nvm use 24                      # ver abajo: el install necesita un node moderno
npm install
npm run demo
```

Si corrés `devnet.sh` adentro del contenedor te lo va a decir y no va a hacer nada:
ahí adentro no hay motor de contenedores, y **no falta instalar nada**. Desde adentro,
el off-chain igual lo encuentra porque la imagen trae `YACI_API` apuntando al host
(`host.containers.internal` con Podman; con Docker hay que pasar
`YACI_API=http://host.docker.internal:8080/api/v1/`).

> **Ojo con la versión de node.** Los `npm run` se arreglan solos (pasan por
> `run.sh`, que antepone un node usable al PATH), pero **`npm install` no**: si lo
> corrés con un npm viejo, te reescribe el `package-lock.json` y te deja
> `node_modules` incompleto — el síntoma es un `Cannot find module
> '@harmoniclabs/crypto'` mucho después. Hay un `preinstall` que lo rechaza antes
> de que pase. Si ya te ocurrió: `git checkout package-lock.json && rm -rf
> node_modules`, y reinstalá con node >= 20.

`devnet.sh up` levanta una cadena descartable en tu máquina: bloques cada
segundo, 20 cuentas con 10.000 ADA y ningún faucet que mendigar.

## Los tres actos

```bash
npm run demo                # todo, pausando entre pasos
npm run demo -- --acto 3    # sólo uno
SIN_PAUSA=1 npm run demo    # de corrido, para revisar antes de la clase
```

1. **El escrow que funciona** — Alice bloquea; Eve intenta y la red la rechaza;
   Bob reclama y cobra.
2. **El deadline** — deadline corto, se espera a que venza, Bob llega tarde y
   falla, Alice cancela y recupera.
3. **El agujero** — Bob reclama con su firma **pero manda los 100 ADA a Eve**, y
   la red lo acepta. Es el gancho de la Clase 9, ocurriendo de verdad.

## Operaciones sueltas

```bash
npm run estado                        # saldos, dirección del script, UTXOs bloqueados
npm run lock   -- --ada 100 --seg 600
npm run claim  -- --como bob          # o --como eve, --a eve, --tarde
npm run cancel
```

## Cómo está armado

| archivo | qué hay |
|---|---|
| `src/comun.ts` | provider, wallets, el script desde el blueprint, tiempo/slots, impresión |
| `src/pasos.ts` | `bloquear`, `reclamar`, `cancelar` — las tres transacciones |
| `src/demo.ts` | el recorrido paso a paso |
| `src/cli.ts` | las operaciones sueltas |

Los actores salen del mnemonic conocido del devnet (`test test … sauce`), como
cuentas 0, 1 y 2: **Alice**, **Bob**, **Eve**. No hay ningún secreto acá.

El validator se lee de `cardano/plutus.json`, que genera `aiken build`. **Si
tocás `escrow.ak`, volvé a correr `aiken build`**: si no, el off-chain sigue
usando el código viejo y la dirección del script no es la misma.

## Correrlo desde el contenedor del curso

El devnet vive en el host, así que hay que decirle al off-chain dónde
encontrarlo:

```bash
podman run -it --rm -v "$PWD":/curso:Z -w /curso/cardano/offchain curso-sc:amd64 \
  bash -lc 'YACI_API=http://host.containers.internal:8080/api/v1/ \
            YACI_ADMIN=http://host.containers.internal:10000/local-cluster/api/ \
            npm run demo'
```

Con Docker, cambiá `host.containers.internal` por `host.docker.internal`.

## Detalles que costaron y conviene no repetir

- **El CBOR del blueprint necesita otra vuelta.** `compiledCode` viene con una
  sola capa de CBOR; el witness quiere la doble. Va por `applyParamsToScript(code, [])`
  aunque el validator **no** esté parametrizado. Sin eso el nodo contesta
  *"Failed to deserialise a script"* y, peor, la dirección del script te da
  **distinta**: los fondos que mandes ahí no los recupera nadie.
- **La relación slot↔tiempo sale del `systemStart` del génesis**, no del campo
  `time` de `/blocks/latest` — ese viene corrido (600 s en el devnet) y hace que
  el claim se rechace por deadline aunque esté en hora.
- **El validator devuelve `False` → el nodo dice *"explicit use of 'error'"***.
  Aiken compila un `False` a un `error` de UPLC. Ojo al leer errores: un fallo de
  CBOR o de presupuesto también llega envuelto en un `EvaluationFailure`, así que
  no todo `EvaluationFailure` significa "el validator dijo que no".
- **Una tx que falla en fase 2 quema el colateral.** Cuando Eve es rechazada, no
  sale gratis: es la contracara de que el script haya llegado a ejecutarse.

## Reiniciar

```bash
./scripts/devnet.sh reset && ./scripts/devnet.sh up   # cadena de cero, ~40s
./scripts/devnet.sh down                              # apagar
```

`reset` **no** borra el cardano-node descargado, así que no hay que bajarlo otra vez.

## Si las transacciones dejan de entrar

Este devnet **deja de forjar bloques** si queda corriendo varias horas
(`epochLength` de 600 slots es un valor de juguete). Lo traicionero es que desde
afuera no se nota: el contenedor sigue arriba y la API contesta con normalidad,
pero la altura no sube y ninguna transacción entra nunca.

```bash
./scripts/devnet.sh estado    # dice si está PRODUCIENDO o detenida
```

`npm run demo` y los comandos que mandan transacciones lo chequean solos antes de
empezar, así que si pasó te enterás en 6 segundos con el comando para arreglarlo,
en vez de esperar un timeout a mitad de la demo. La salida siempre es
`./scripts/devnet.sh reset && ./scripts/devnet.sh up`.
