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
FULL=1 ./scripts/build-image.sh amd64   # + Aderyn, Medusa, halmos, Chromium
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
  --build-arg INSTALL_HALMOS=true \
  --build-arg INSTALL_CHROMIUM=true \
  .
```

| Flag | Para qué | Clase |
|---|---|---|
| `INSTALL_ADERYN` | analizador estático alternativo (Rust, Cyfrin) | 6 |
| `INSTALL_MEDUSA` | fuzzer guiado por cobertura (Trail of Bits) | 6 |
| `INSTALL_HALMOS` | testing simbólico sobre tests de Foundry | 6 |
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
cd ethereum && forge test        # → 23 passed + 4 failed (los 4 son la ACTIVIDAD de la Clase 3)
cd ethereum && forge test --no-match-contract AlcanciaTest   # → 23 passed, 0 failed (línea base)
cd ../cardano && aiken check     # → 14 passed
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
| **solc + SMTChecker** (con `z3`) | 6, 7 | `forge build` con el bloque `model_checker` |
| **Slither** | 6, 7 | `cd ethereum && slither src/Vault.sol` |
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
```

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
  cd /curso/cardano && aiken check 2>&1 | grep -oE "\"passed\": [0-9]+"
'
```

Salida esperada (**verificada en `arm64`**, imagen del 2026-08-11):

```text
Ran 2 test suites: 15 tests passed, 0 failed, 0 skipped (15 total tests)
Ran 3 test suites: 16 tests passed, 4 failed, 0 skipped (20 total tests)
"passed": 7
```

Cómo leer esos tres números:

| Comando | Qué mide |
|---|---|
| `forge test --no-match-contract AlcanciaTest` | **la línea base**: 13 de `Vault.t.sol` + 2 de `VaultInvariant.t.sol`. Tiene que dar **15 / 0**. |
| `forge test` | todo, incluida la actividad de la Clase 3: 15 + el test modelo de `Alcancia` = **16 passed**, y **4 failed**. |
| `aiken check` | los **7** tests de `escrow.ak`. |

> **Los 4 que fallan son correctos:** son las consignas de la **actividad de la Clase 3**
> (`test/Alcancia.t.sol`), que arrancan en rojo a propósito y el alumno completa.

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
