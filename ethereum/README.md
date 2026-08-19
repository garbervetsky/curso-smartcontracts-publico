# Track Ethereum (Foundry)

Proyecto compartido por las clases de Ethereum (2, 3, 6, 7).

> El material de las Clases 6 y 7 (`VaultVulnerable.sol`, `VaultFixed.sol` y sus tests) **se
> agrega durante el curso**. Ver `PROXIMAS-CLASES.md` en la raíz.

## Estado verificado

| Herramienta | Versión | Estado |
|-------------|---------|--------|
| `forge` / `anvil` | 1.7.1 | ✅ instalado |
| `forge-std` | v1.16.1 | ✅ en `lib/forge-std/` (submódulo git) |

`forge build` compila sin errores. `forge test --no-match-contract AlcanciaTest` deja la línea
base en verde: **11 tests** de `Vault.t.sol`.

## Instalación paso a paso

### Paso 1 — Instalar Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
# recargar el shell o abrir una terminal nueva, luego:
foundryup
```

Verificar:

```bash
forge --version   # forge x.y.z (hash)
anvil --version   # anvil x.y.z (hash)
```

### Paso 2 — Pararse en el directorio raíz del repositorio

```bash
cd curso-smartcontracts-alumnos/
```

### Paso 3 — Instalar forge-std

`forge-std` es la librería de testing de Foundry. Se instala como submódulo de git:

```bash
cd ethereum/
forge install foundry-rs/forge-std
```

Esto crea `lib/forge-std/`, el archivo `.gitmodules` en la raíz del repo, y `foundry.lock`
(equivalente al `aiken.lock` de Cardano: fija la versión exacta de cada dependencia).

Si el repositorio ya tiene `.gitmodules` configurado (p.ej. al clonar), alcanza con:

```bash
git submodule update --init --recursive
```

### Paso 4 — Verificar

```bash
forge build                                        # debe compilar sin errores
forge test --no-match-contract AlcanciaTest -vv    # la línea base, toda en verde
```

`forge test` a secas también corre `AlcanciaTest`, que **arranca en rojo a propósito**: son los
tests de la actividad de la Clase 3, que se completan durante el taller.

## Comandos de uso frecuente

```bash
forge build                            # compilar
forge test -vv                         # correr tests (con nombres y logs)
forge test -vvv                        # también muestra traces de ejecución
forge test --match-test test_Withdraw  # filtrar por nombre
forge test --fuzz-runs 1000            # más iteraciones de fuzzing (Clase 6/7)
anvil                                  # nodo local para deploy (Clase 3)
```

## Contenido

- `src/Vault.sol` — se construye en la Clase 3 y se audita/explota en la Clase 7.
  **`withdrawAll()` está sin implementar**: es parte del taller.
- `src/Alcancia.sol` — la **actividad** de la Clase 3: `retirar()` está sin implementar.
- `test/Vault.t.sol` — tests de Foundry (Clase 3). **Le faltan los dos de `withdrawAll`**: se
  escriben en clase.
- `test/Alcancia.t.sol` — 1 test modelo + 4 consignas en rojo, para la actividad.
- `foundry.lock` — lock file de dependencias (commitear junto con `.gitmodules`).
