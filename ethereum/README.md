# Track Ethereum (Foundry)

Proyecto compartido por las clases de Ethereum (2, 3, 6, 7).

> Para la Clase 7 ya están `VaultVulnerable.sol`, sus tests y `test/halmos/`. La versión
> arreglada la escribís vos en el taller: ver [Taller de la Clase 7](#taller-de-la-clase-7) más
> abajo, y `PROXIMAS-CLASES.md` en la raíz.

## Estado verificado

| Herramienta | Versión | Estado |
|-------------|---------|--------|
| `forge` / `anvil` | 1.7.1 | ✅ instalado |
| `forge-std` | v1.16.1 | ✅ en `lib/forge-std/` (submódulo git) |
| `halmos` | 0.3.3 | ✅ en la imagen (Clase 7) |

`forge build` compila sin errores. `forge test --no-match-contract AlcanciaTest` deja la línea
base en verde: **12 tests** (11 de `Vault.t.sol` y el invariante de `VaultVulnerable.t.sol`), y
**2 en SKIP**: los PoCs que se escriben en el taller de la Clase 7.

## Instalación paso a paso

### Paso 1 — Instalar Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
# recargar el shell o abrir una terminal nueva, luego:
foundryup --install v1.7.1   # la versión del curso (la misma que trae la imagen)
```

Si ya tenés una 1.8 o posterior, también anda: la línea base da lo mismo y `halmos` funciona
(verificado con la 1.8.3).

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
forge test -vvv                        # + traces de los tests que FALLAN
forge test -vvvv                       # + traces de todos, también los que pasan
forge test --match-test test_Withdraw  # filtrar por nombre
forge test --fuzz-runs 1000            # más iteraciones de fuzzing (Clase 6/7)
anvil                                  # nodo local para deploy (Clase 3)
halmos                                 # verificación simbólica de test/halmos/ (Clase 7)
```

`halmos` viene en la imagen del curso. Fuera del contenedor: `pipx install halmos`.

## Contenido

- `src/Vault.sol` — se construye en la Clase 3 (`withdrawAll()` se escribió en vivo en clase) y
  es la versión correcta con la que se compara el vulnerable en la Clase 7.
- `src/VaultVulnerable.sol` — el Vault con bugs a propósito, para el taller de la Clase 7.
- `test/VaultVulnerable.t.sol` — el taller de la Clase 7: **el atacante y los dos PoCs están sin
  escribir** (los tests arrancan en SKIP); el handler y el invariante de solvencia ya están.
- `test/halmos/VaultHalmos.t.sol` — la solvencia, para `halmos` (Clase 7). **`AtacanteUnaVez` está
  sin escribir.** `forge test` no lo corre.
- `src/Alcancia.sol` — la **actividad** de la Clase 3: `retirar()` está sin implementar.
- `test/Vault.t.sol` — tests de Foundry (Clase 3). **Le faltan los dos de `withdrawAll`**: se
  escriben en clase.
- `test/Alcancia.t.sol` — 1 test modelo + 4 consignas en rojo, para la actividad.
- `foundry.lock` — lock file de dependencias (commitear junto con `.gitmodules`).

## Taller de la Clase 7

**Entregable, en pares: un reporte corto de hallazgos y un fix verificado.** Todo se corre desde
`ethereum/`. Para `halmos` hace falta la imagen reconstruida después de este cambio
(`./scripts/build-image.sh`).

1. **Análisis estático y triage.** Correr `slither src/VaultVulnerable.sol` y clasificar cada
   hallazgo como real o ruido, con una frase que lo justifique. Después correr
   `slither src/VaultVulnerable.sol --print vars-and-auth`: ¿qué fila delata un bug que el triage
   de los hallazgos no encontró?

2. **El atacante y los PoCs.** En `test/VaultVulnerable.t.sol`, escribir `ReentrancyAttacker`
   y los dos tests (`test_Reentrancy_DrenaElVault` y
   `test_AccessControl_ExtranioSeQuedaConLosFondos`), cada uno según la consigna de su
   comentario, y borrarles el `vm.skip(true)`. Correr
   `forge test --match-path test/VaultVulnerable.t.sol -vvvv` y leer los traces (con `-vvv` no
   salen: forge sólo muestra la traza de los tests que fallan). En el de la
   reentrancy, contar las llamadas anidadas a `withdraw`.

3. **Invariantes y halmos.** Con su atacante andando, descomentar el `assertGe` de
   `invariant_solvency_DEMO` y correr
   `forge test --match-contract VaultVulnerableInvariantTest -vv`. ¿El fuzzer rompe la
   solvencia? ¿A cuántas llamadas reduce la secuencia? Volver a comentarlo al terminar.
   Después correr `halmos --contract VaultVulnerableHalmos`: con `AtacanteUnaVez` vacío da
   `[PASS]`. ¿Por qué? Escribirlo (consigna en su comentario) y volver a correr: ¿qué secuencia
   devuelve? ¿Qué afirma ese `FAIL` que no afirmaba el del fuzzer?

4. **Dos hallazgos**, uno por bug, con este formato:

   ```markdown
   ## [SEVERIDAD] Título corto

   **Ubicación:** archivo y líneas
   **Descripción:** qué está mal y por qué es explotable
   **Impacto:** qué se pierde, cuantificado
   **Prueba de concepto:** el test que lo demuestra
   **Recomendación:** el cambio concreto
   **Estado:** dónde está corregido y qué test lo verifica
   ```

5. **El fix.** Copiar `src/VaultVulnerable.sol` a `src/MiVaultFixed.sol`, renombrar el contrato
   a `MiVaultFixed` y arreglar los dos bugs con el cambio más chico que los cierre. Conservar
   `deposit()` y `withdraw()` con la misma firma. Verificarlo dos veces:
   - **Con halmos.** Al final de `test/halmos/VaultHalmos.t.sol`, agregar un contrato igual a
     `VaultVulnerableHalmos` que despliegue `MiVaultFixed`. El nombre tiene que terminar en
     `Halmos` (si no, `halmos` no lo corre). `halmos --contract <ese nombre>` tiene que dar
     `[PASS]`; probarlo también con `--invariant-depth 4`.
   - **Con sus PoCs**, en `test/MiVaultFixed.t.sol`: los dos de la consigna 2 apuntados a su
     contrato, cambiados para que esperen que el ataque falle y que el Vault conserve los fondos.

   Discutir: ¿su arreglo sigue protegiendo si alguien después reordena `withdraw()` o agrega
   otra función que envía ETH?

6. **Opcional: un LLM como auditor.** Pedirle una auditoría de `VaultVulnerable.sol`. ¿Encuentra
   los dos bugs? ¿Inventa alguno que no existe? Confirmar o descartar **cada** hallazgo con un
   test.
