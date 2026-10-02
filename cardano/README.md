# Track Cardano (Aiken)

Proyecto compartido por las clases de Cardano (4, 5, 8, 9).

> Para la Clase 9 ya están `escrow_vulnerable.ak` y `vesting_vulnerable.ak`. La versión arreglada
> la escribís vos en el taller: ver [Taller de la Clase 9](Taller-Clase9.md), y
> `PROXIMAS-CLASES.md` en la raíz.

## Estado verificado

| Herramienta | Versión mínima | Estado en este entorno |
|-------------|----------------|------------------------|
| `aiken` | v1.1.0 | ✅ v1.1.21 instalado |
| `aiken-lang/stdlib` | v3.1.0 | ✅ descargado en primer `aiken check` |
| `aiken-lang/fuzz` | v2.2.0 | ✅ descargado en primer `aiken check` (property tests, Clases 8 y 9) |

## Instalación paso a paso

### Paso 1 — Instalar Aiken

```bash
# via aikup (el instalador de Aiken, similar a foundryup)
curl -sSfL https://install.aiken-lang.org | bash
# recargar el shell o abrir una terminal nueva, luego:
aikup install
```

Verificar:

```bash
aiken --version   # aiken vX.Y.Z+hash
```

### Paso 2 — Pararse en el directorio del proyecto

```bash
cd cardano/
```

### Paso 3 — Verificar que compila y los tests pasan

```bash
aiken check -m claim -m cancel -m v2_
```

Se filtra a la línea base a propósito: **14 tests** (los 7 del escrow, 2 del escrow vulnerable y
5 del vesting versión 2). `aiken check` pelado corre **también** lo que arranca **en rojo porque
es material de taller**: los 5 de `vesting.ak` (Clase 5, `can_unlock` sin implementar) y los 4
`poc_*`/`prop_*` de `vesting_vulnerable.ak` (Clase 9, son `todo`). Es lo esperable, no una
instalación rota.

En la primera ejecución descarga `aiken-lang/stdlib` y `aiken-lang/fuzz` desde GitHub (requiere
acceso a internet). Las siguientes ejecuciones usan el cache local en `build/`.

Salida esperada:

```
Compiling curso/cardano 0.0.0 (.)
Resolving dependencies
...
Testing ...
  PASS [unit] escrow.claim_requires_beneficiary_signature
```

### Paso 4 — (Opcional) Compilar el blueprint

```bash
aiken build
```

Genera `plutus.json` con el CBOR del validator compilado. Es lo que el código off-chain
usa para conocer la dirección del validator.

## Comandos de uso frecuente

```bash
aiken check                             # type-check + TODOS los tests (los talleres de las
                                        # Clases 5 y 9 arrancan en rojo)
aiken check -m claim -m cancel -m v2_   # la línea base, 14/0
aiken check -m poc_ -m prop_            # el taller de la Clase 9
aiken check --seed=<n>                  # reproducir una corrida de property tests
aiken build              # compilar a UPLC y generar plutus.json
aiken docs               # generar documentacion del proyecto en HTML
```

## Nota sobre dependencias descargadas

`build/` esta en `.gitignore`. La primera vez que se ejecuta `aiken check` en una
instalacion fresca, Aiken descarga las dependencias declaradas en `aiken.toml`
(`aiken-lang/stdlib` y `aiken-lang/fuzz`) y las deja en `build/packages/`.
No hace falta ninguna accion adicional.

## Contenido

- `validators/escrow.ak` — se construye en la Clase 5; su versión vulnerable se analiza en las
  Clases 8 y 9.
- `validators/vesting.ak` — el taller de la Clase 5: viene sin implementar, sus tests arrancan en rojo.
- `validators/escrow_vulnerable.ak` — el escrow que valida el output pero es double-satisfiable,
  con el test que lo demuestra (Clases 8 y 9).
- `validators/vesting_vulnerable.ak` — el taller de la Clase 9: el vesting versión 2, con dos bugs.
  **Los PoCs y las propiedades están sin escribir** (arrancan en rojo).
- `Taller-Clase9.md` — las consignas del taller de la Clase 9.
- `offchain/` — off-chain con Mesh: arma y manda **transacciones reales** del escrow
  contra un devnet local. Ver `offchain/README.md`.
- `aiken.toml` — configuracion del proyecto (nombre, version de Plutus, dependencias).
- `aiken.lock` — lock file de dependencias (commitear para reproducibilidad).

## Ver el validator en acción

Hay dos demos, y hacen cosas distintas:

```bash
../scripts/demo-tx-cardano.sh    # ejecuta el validator sobre txs armadas a mano; sin red
../scripts/devnet.sh up          # levanta un devnet local...
cd offchain && npm install && npm run demo   # ...y le manda transacciones de verdad
```

La primera no toca la red y no puede fallar; la segunda mueve saldos, paga fees y
quema colateral.

**Si tocás un validator, corré `aiken build`**: el off-chain lee `plutus.json`, y con un
blueprint viejo la dirección del script es otra.
