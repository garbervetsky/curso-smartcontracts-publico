# Entorno en contenedor (Podman / Docker)

Imagen con **todo el material del curso + todas las herramientas** de las 9 clases, con las
cachés preparadas para poder dar clase **sin depender de internet ni del setup de cada máquina**.

Resuelve el riesgo que la guía del profesor marca como #1 en las clases de taller: que la clase
se vaya en problemas de instalación.

---

## 1. Construir la imagen

Hay **dos imágenes**, una por arquitectura de CPU: **`amd64`** (Intel/AMD, x86_64) y **`arm64`**
(Apple Silicon / ARM). Elegí según la máquina donde vas a construir y correr — averiguá su
arquitectura con `uname -m`:

| Tu máquina | `uname -m` | Imagen | Cómo va el build |
|---|---|---|---|
| **Linux Intel/AMD** (PC, servidor, lab) | `x86_64` | **`amd64`** | nativo y rápido — **ideal para armar la imagen de los labs** |
| **Mac Intel** | `x86_64` | **`amd64`** | nativo y rápido — también sirve para armar la de los labs |
| **Mac Apple Silicon** (M1/M2/M3…) | `arm64` | **`arm64`** | nativo; Aiken se **compila desde fuente** (no hay binario `aarch64-linux`), así que la 1ª vez tarda más |

> **La imagen que se usa en los labs es `amd64`.** Cualquier máquina **x86_64** (Linux Intel/AMD o
> Mac Intel) la construye de forma nativa. Desde una Mac Apple Silicon **no** conviene construir
> `amd64` (ver recuadro abajo): armala en una x86_64 y distribuila ya hecha (§6).

Lo más simple es el script:

```bash
cd curso-smartcontracts/
./scripts/build-image.sh amd64     # la de los labs
./scripts/build-image.sh arm64     # la de tu Mac
./scripts/build-image.sh both
FULL=1 ./scripts/build-image.sh amd64   # + Aderyn, Medusa, Chromium
```

O a mano:

```bash
podman build --platform linux/amd64 -t curso-sc:amd64 .
podman build --platform linux/arm64 -t curso-sc:arm64 .
```

> Con Docker es idéntico (`docker build ...`): el `Containerfile` es OCI estándar y hay un
> `.dockerignore` equivalente.

> ### ⚠️ La imagen `amd64` se construye en una máquina x86_64 (no en Apple Silicon)
>
> Construir `amd64` desde una Mac con Apple Silicon **no funciona**: aunque la emulación corre
> binarios simples, los de **Foundry segfaultean** al traducirse (`forge -V` → `exit status 139`),
> y el build aborta.
>
> **Solución:** construir la imagen de los labs en cualquier máquina **x86_64** — una PC/servidor
> **Linux Intel o AMD**, o una **Mac Intel** (además es mucho más rápido que emular) — y distribuirla
> ya armada al resto (§6).
>
> En una Mac **Apple Silicon**, construí la `arm64` para preparar clases y probar demos localmente.

### En macOS: antes que nada, la máquina virtual

> **En Linux esto no hace falta:** Podman corre los contenedores directo sobre el kernel del host,
> sin VM. Salteá esta sección y andá a construir.

Podman en macOS (Intel **y** Apple Silicon) corre los contenedores dentro de una VM Linux. Una sola
vez:

```bash
podman machine init --cpus 4 --memory 6144 --disk-size 60
podman machine start
```

> Compilar Aiken desde fuente (build `arm64`) es pesado en RAM: si el build muere con `SIGKILL`
> (OOM), dale más memoria a la VM — `podman machine stop && podman machine set --memory 8192 &&
> podman machine start`.

Si `podman` no aparece en el PATH (instalación por `.pkg` / Podman Desktop), está en
`/opt/podman/bin`:

```bash
export PATH="/opt/podman/bin:$PATH"   # agregalo a ~/.zshrc para que quede fijo
```

### Herramientas opcionales (no vienen por defecto, para no inflar la imagen)

```bash
podman build -t curso-sc:full \
  --build-arg INSTALL_ADERYN=true \
  --build-arg INSTALL_MEDUSA=true \
  --build-arg INSTALL_CHROMIUM=true \
  .
```

| Flag | Para qué | Clase |
|---|---|---|
| `INSTALL_ADERYN` | analizador estático alternativo (Rust, Cyfrin) | 6 |
| `INSTALL_MEDUSA` | fuzzer guiado por cobertura (Trail of Bits) | 6 |
| `INSTALL_CHROMIUM` | **sólo** si querés exportar slides a PDF/PPTX desde el contenedor | todas |

> Para **dar la clase** no hace falta Chromium: el modo servidor de Marp sirve HTML.

---

## 2. Usarla

> **Las imágenes se llaman `curso-sc:amd64` y `curso-sc:arm64`** (una por arquitectura, ver §1).
> **Elegí el tag según la arquitectura de la máquina donde vas a correr el contenedor**, no según
> dónde la construiste:
>
> - **Intel / AMD** (los labs, Macs **Intel**, la mayoría de las PCs) → **`amd64`**
> - **Apple Silicon** (Mac M1/M2/M3…) → **`arm64`**
>
> Averiguá la tuya con `uname -m` (`x86_64` → amd64, `arm64`/`aarch64` → arm64).
>
> > ⚠️ Si pedís un tag que **no tenés construido localmente**, Podman cree que es de un registro
> > remoto e intenta descargarlo, y falla con `requested access to the resource is denied`. **No es
> > un problema de permisos**: es que ese tag no existe en tu máquina. Verificá qué tenés con
> > `podman images` (deberías ver `localhost/curso-sc` con su tag).
>
> Los ejemplos de abajo usan `amd64` (el target de los labs y de las Macs Intel); en Apple Silicon
> cambiá `amd64` por `arm64`.
>
> **No hace falta ningún archivo `.tar` para usarla en la máquina donde la construiste**: al
> terminar el build, la imagen ya queda cargada en Podman. Comprobalo con `podman images`.
> El `.tar` aparece **sólo** cuando querés *mover* la imagen a otra máquina (§6).

### Modo taller (efímero, material listo)

```bash
podman run -it --rm curso-sc:amd64
```

Te deja adentro, en `/curso`, con todo listo. Probá que anda:

```bash
cd ethereum && forge test        # → 15 passed + 4 failed (los 4 son la ACTIVIDAD de la Clase 3)
cd ethereum && forge test --no-match-contract AlcanciaTest   # → 14 passed, 0 failed (línea base)
cd ethereum && halmos            # → 1 PASS + 1 FAIL (el FAIL es el vault vulnerable, a propósito)
cd ../cardano && aiken check                     # → 7 passed + 5 failed (el TALLER de la Clase 5)
cd ../cardano && aiken check -m claim -m cancel  # → 7 passed, 0 failed (línea base)
```

Las versiones exactas preparadas están en `~/VERSIONES.txt`.

### Modo trabajo (montando tu copia del repo)

Para que lo que edites persista en tu máquina:

```bash
podman run -it --rm -v "$PWD":/curso:Z -w /curso curso-sc:amd64
```

> El sufijo `:Z` es de Podman con SELinux (Linux). En macOS podés omitirlo.

### Servir las slides para dar la clase

```bash
podman run -it --rm -p 8080:8080 curso-sc:amd64 \
  marp -s docs/slides --server-port 8080 --host 0.0.0.0
```

Abrís `http://localhost:8080` y navegás los decks de las 9 clases.

### Dos terminales dentro del mismo contenedor (Clase 3)

`anvil` ocupa una terminal entera, y el `forge script` / `cast` va en otra. Para que las dos
vean el mismo `127.0.0.1:8545`, tienen que ser **dos shells del mismo contenedor**:

```bash
# TERMINAL 1 — arrancar el contenedor CON NOMBRE
podman run -it --rm --name curso -v "$PWD":/curso:z curso-sc:arm64
cd ethereum && anvil

# TERMINAL 2 — entrar al mismo contenedor
podman exec -it curso bash
cd /curso/ethereum
forge script script/DeployVault.s.sol --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac09...ff80 --broadcast
```

El **`--name`** es lo que hace posible el `exec`: sin él no hay forma de volver a entrar.
`podman exec` hereda el `PATH` de la imagen, así que `forge` y `cast` están disponibles sin
pasar por un login shell.

### Deploy local con anvil, en su propio contenedor (Clase 3)

```bash
podman run -it --rm -p 8545:8545 curso-sc:amd64 anvil --host 0.0.0.0
```

Desde otra terminal, dentro del contenedor o desde el host, apuntás a
`http://127.0.0.1:8545` (chain id `31337`).

---

## 3. Qué trae (y en qué clase se usa)

| Herramienta | Clases | Comprobación rápida |
|---|---|---|
| **Foundry** (`forge`, `anvil`, `cast`) | 2, 3, 6, 7 | `cd ethereum && forge test -vv` |
| **solc + SMTChecker** (`z3` en amd64, **Eldarica** en arm64) | 6, 7 | `forge build --force` con el bloque `model_checker` |
| **Slither** | 6, 7 | `cd ethereum && slither src/Vault.sol` |
| **halmos** (con `z3`) | 6, 7 | `cd ethereum && halmos` (1 PASS, 1 FAIL a propósito) |
| **Aiken** (+ stdlib cacheado) | 4, 5, 8, 9 | `cd cardano && aiken check` |
| **Node + Marp** | todas | `marp -s docs/slides` |
| **Material completo** | todas | guiones, decks, código de ambos tracks |

La imagen valida en tiempo de build que `forge build`, `forge test` y `aiken check` pasan:
**si el build termina, el entorno funciona.**

---

## 4. Demos por clase (comandos listos)

```bash
# Clase 3 — taller Foundry
cd ethereum && forge test -vv && anvil --host 0.0.0.0

# Clase 4 — una transacción EUTXO, con el validator decidiendo
./scripts/demo-tx-cardano.sh

# Clase 5 — Cardano
cd cardano && aiken check      # los tests del escrow
aiken build                    # genera plutus.json

# Clase 6 — estático + invariantes
cd ethereum && slither src/Vault.sol
forge test --match-contract VaultInvariantTest -vv

# Clase 6 — SMTChecker (forge cachea: sin --force no vuelve a analizar)
cd ethereum && forge build --force
```

### El SMTChecker usa un solver distinto en cada arquitectura

Sale solo, no hay que configurar nada, pero **la salida no es idéntica** y conviene saberlo antes
de proyectarla:

| | amd64 (labs, y macOS) | arm64 (Apple Silicon) |
|---|---|---|
| solver | **z3**, adentro de la imagen (`libz3.so.4.12`) | **Eldarica** (`eld`, JVM) |
| tiempo de `forge build --force` | ~26 s | ~110 s |
| hallazgos sobre `Vault.sol` | underflow *happens here* (línea 30), overflow *might happen* (línea 20) | **los mismos** |
| contraejemplo concreto | ✅ `amount = 1` | ❌ sólo dice que el camino existe |
| ruido | — | 1 warning `8158` ("z3 no disponible") + 1 `CHC: Error trying to invoke SMT solver` |

La causa es contraintuitiva y **no** es que "arm64 sea peor": el `solc` de aarch64 se compila
**sin z3 adentro** (0 símbolos `Z3_*`), así que instalar `libz3` no cambia nada — el binario ni
siquiera la referencia. Eldarica en cambio se invoca como **proceso externo**, y por eso funciona.

Lo que lo hace andar es una línea de `ethereum/foundry.toml`, y **es obligatoria**:

```toml
solvers = ["z3", "eld"]   # solc usa el que encuentre: z3 en amd64, eld en arm64
```

> **Si la sacás, en arm64 el análisis no corre**: `forge build` termina bien pero escupe
> `Warning (7649): CHC analysis was not possible since no Horn solver was found`. Ojo con esa
> warning: dice que **no se verificó nada**, no que no encontró problemas.

> **Clases 6 a 9:** las demos de explotación (`VaultVulnerable`, `escrow_vulnerable`) necesitan
> material que **todavía no está en el repo** — se agrega durante el curso. Ver
> `PROXIMAS-CLASES.md`.

---

## 5. Property tests de Aiken (`aiken-lang/fuzz`)

Los property tests de las Clases 5, 8 y 9 están **comentados** en el repo porque requieren la
dependencia `aiken-lang/fuzz`, que no viene declarada en `aiken.toml`. Para habilitarlos dentro
del contenedor (requiere red la primera vez):

```toml
# agregar a cardano/aiken.toml
[[dependencies]]
name = "aiken-lang/fuzz"
version = "main"
source = "github"
```

```bash
cd cardano && aiken check    # ahora descarga fuzz y corre los property tests
```

Si querés que la imagen ya lo traiga completa y offline, agregá esa dependencia **antes** de
construir: el `aiken check` del build la descarga y la deja cacheada.

---

## 6. Distribuir a los labs

Lo más práctico para un aula: **construir la imagen una sola vez** y llevarla armada, así las
máquinas del lab no dependen de internet ni tardan en construir.

### Opción A — archivo (sin registry, va por pendrive/red interna)

```bash
# en tu máquina, una vez
podman save curso-sc:amd64 -o curso-sc-amd64.tar
# (opcional) comprimir: gzip -9 curso-sc-amd64.tar

# en cada máquina del lab
podman load -i curso-sc-amd64.tar
podman run -it --rm curso-sc:amd64
```

### Opción B — registry (si el lab tiene red)

```bash
podman tag curso-sc:amd64 registry.ejemplo.edu/curso-sc:amd64
podman push registry.ejemplo.edu/curso-sc:amd64
# en el lab:
podman pull registry.ejemplo.edu/curso-sc:amd64
```

### Chequeo previo al aula

Este comando es el que se usó para validar la imagen; si pasa, las demos de las 9 clases funcionan:

```bash
podman run --rm curso-sc:arm64 bash -lc '
  which forge aiken slither marp
  cd /curso/ethereum && forge test --no-match-contract AlcanciaTest | tail -1
  forge test | tail -1
  cd /curso/cardano && aiken check -m claim -m cancel 2>&1 | grep -oE "\"passed\": [0-9]+"
'
```

Salida esperada (**verificada en `arm64`** el 2026-09-24, forge 1.7.1):

```text
Ran 4 test suites: 14 tests passed, 0 failed, 0 skipped (14 total tests)
Ran 5 test suites: 15 tests passed, 4 failed, 0 skipped (19 total tests)
"passed": 7
```

Cómo leer esos tres números:

| Comando | Qué mide |
|---|---|
| `forge test --no-match-contract AlcanciaTest` | **la línea base**: 11 de `Vault.t.sol` + 3 de `VaultVulnerable.t.sol`. Tiene que dar **14 / 0**. |
| `forge test` | todo, incluida la actividad de la Clase 3: 14 + el test modelo de `Alcancia` = **15 passed**, y **4 failed**. |
| `aiken check -m claim -m cancel` | **la línea base de Cardano**: los **7** tests de `escrow.ak`. Tiene que dar **7 / 0**. |
| `aiken check` | todo, incluido el taller de la Clase 5: 7 passed y **5 failed** (`vesting.ak`). |

> **Los que fallan son correctos:** son las consignas que el alumno completa y arrancan en rojo
> a propósito — los 4 de la **actividad de la Clase 3** (`test/Alcancia.t.sol`) y los 5
> `unlock_*` del **taller de la Clase 5** (`cardano/validators/vesting.ak`, con `can_unlock`
> sin implementar).
>
> Por eso el build de la imagen filtra en los dos lados (`--no-match-contract AlcanciaTest` y
> `-m claim -m cancel`). Ojo con el filtro de aiken: no tiene flag de exclusión, y `-m escrow`
> **no matchea nada** — corre 0 tests y sale 0, o sea que pasaría sin validar nada. `-m` matchea
> nombres de test.

> Estos números **suben** cuando se agregue el material de las Clases 6 a 9
> (ver `PROXIMAS-CLASES.md`). La imagen se valida sola: si `forge test` o `aiken check`
> fallan, el build no termina.

> **Tip:** `aiken check` imprime **JSON** cuando la salida no es una terminal. Para verlo con el
> formato lindo de siempre, corré el contenedor con `-t` (`podman run -it ...`).

---

## 7. Notas y límites

- **Arquitectura.** Hay una imagen por arquitectura (§1). En `arm64` Aiken se compila desde fuente
  porque no hay binario oficial `aarch64-linux`; en `amd64` se usa el binario de `aikup`.
  Si alguna otra herramienta no publica binario para tu arquitectura, podés forzar
  emulación: `podman build --platform linux/amd64 -t curso-sc:amd64 .` (más lento).
- **Tamaño.** La imagen base ronda los pocos GB; con todos los opcionales (sobre todo Chromium)
  crece bastante. Por eso los opcionales son opt-in.
- **Reproducibilidad.** `AIKEN_VERSION` está fijado (`v1.1.21`, igual que `aiken.toml`). Foundry se
  instala en su versión estable del día del build; la versión concreta queda registrada en
  `~/VERSIONES.txt` dentro de la imagen.
- **Material preparado vs montado.** La imagen trae una copia del repo en `/curso`. Si editás
  material, o montás tu copia con `-v` (ver arriba) o reconstruís la imagen.
