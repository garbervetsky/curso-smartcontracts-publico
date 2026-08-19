# Track Cardano (Aiken)

Proyecto compartido por las clases de Cardano (4, 5, 8, 9).

> El material de las Clases 8 y 9 (`escrow_vulnerable.ak`, `escrow_fixed.ak`) **se agrega durante
> el curso**. Ver `PROXIMAS-CLASES.md` en la raíz.

## Estado verificado

| Herramienta | Versión mínima | Estado en este entorno |
|-------------|----------------|------------------------|
| `aiken` | v1.1.0 | ✅ v1.1.21 instalado |
| `aiken-lang/stdlib` | main | ✅ descargado en primer `aiken check` |

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
aiken check
```

En la primera ejecución descarga `aiken-lang/stdlib` desde GitHub (requiere acceso a internet).
Las siguientes ejecuciones usan el cache local en `build/`.

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
aiken check              # type-check + correr todos los tests
aiken build              # compilar a UPLC y generar plutus.json
aiken docs               # generar documentacion del proyecto en HTML
```

## Nota sobre dependencias descargadas

`build/` esta en `.gitignore`. La primera vez que se ejecuta `aiken check` en una
instalacion fresca, Aiken descarga las dependencias declaradas en `aiken.toml`
(actualmente `aiken-lang/stdlib`) y las deja en `build/packages/`.
No hace falta ninguna accion adicional.

## Contenido

- `validators/escrow.ak` — se construye en la Clase 5 y se audita en la Clase 9.
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
