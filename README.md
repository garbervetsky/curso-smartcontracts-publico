# Curso de programación y análisis de smart contracts: Ethereum y Cardano

Repositorio de trabajo del curso: el **entorno**, el **código de ejemplo** y la **base de los
talleres**. Las slides se publican acá antes de cada clase.

Son 9 clases que recorren el desarrollo y la **seguridad** de smart contracts en las dos cadenas,
contrastando el modelo de cuentas de Ethereum con el modelo EUTXO de Cardano.

> **Tesis del curso:** cómo se escribe y cómo se rompe un contrato es una consecuencia directa del
> modelo de ejecución de la cadena. Todo lo demás —Solidity, Aiken, las vulnerabilidades, las
> herramientas— cuelga de esa distinción.

## Empezar

### 1. Clonar (con el submódulo)

`forge-std` viaja como submódulo de git. Sin `--recurse-submodules` los tests de Ethereum no
compilan:

```bash
git clone --recurse-submodules <URL-DE-ESTE-REPO>
cd curso-smartcontracts-alumnos
```

¿Ya clonaste sin eso? Se arregla con:

```bash
git submodule update --init --recursive
```

### 2. Construir la imagen del entorno

Incluye **todas** las herramientas de las 9 clases ya preparadas con cachés listas, para que la clase no se frene por problemas de instalación. El entorno funciona con Podman o con Docker, pero
en los laboratorios se prefiere **Podman**.

Opcional: si no tenés Podman, Docker también sirve; la idea es la misma. La recomendación del curso
es usar Podman en local y en el laboratorio.

Instalación rápida de Podman (Ubuntu/Debian):

```bash
sudo apt update
sudo apt install -y podman
podman --version
```

Si usás macOS, también podés instalarlo con Homebrew:

```bash
brew install podman
```


```bash
./scripts/build-image.sh arm64      # Apple Silicon
./scripts/build-image.sh amd64      # labs Intel
```

Y para entrar:

(si tenes arm)
```bash
podman run -it --rm --userns=keep-id -v "$PWD":/curso:z curso-sc:arm64
```

(si tenes amd64)
```bash
podman run -it --rm --userns=keep-id -v "$PWD":/curso:z curso-sc:amd64
```


El -v monta **tu clon** del repositorio dentro del contenedor en /curso. De esta forma, los cambios que hagas se guardan en tu directorio local y, cuando haya material nuevo, podés actualizarlo con git pull sin necesidad de reconstruir la imagen.
Agregamos **--userns=keep-id** al ejecutar el contenedor para preservar los permisos de tu usuario sobre el directorio montado.

Guía completa —opcionales, servir las slides, `anvil`, demos— en **`docs/entorno-contenedor.md`**.

### 3. Verificar que quedó bien

```bash
cd /curso/ethereum && forge test --no-match-contract AlcanciaTest    # 11 tests en verde
cd /curso/cardano  && aiken check                                    # 7 tests en verde
```

> `AlcanciaTest` se excluye a propósito: son los tests de la **actividad de la Clase 3** y arrancan
> en rojo. Completarlos es el ejercicio.

### Instalación manual (sin contenedor)

- **Ethereum:** [Foundry](https://book.getfoundry.sh/) (`forge`, `anvil`) — ver `ethereum/README.md`
- **Cardano:** [Aiken](https://aiken-lang.org/) — ver `cardano/README.md`

## Qué hay acá

```
.
├── Containerfile              # La imagen del entorno (Podman/Docker)
├── Containerfile.devnet       # Devnet local de Cardano (Yaci)
├── PROXIMAS-CLASES.md         # Qué material falta y cuándo llega
├── docs/
│   ├── entorno-contenedor.md  # Guía completa del entorno
│   └── slides/clase-NN/       # Diapositivas (placeholders hasta cada clase)
├── ethereum/                  # Proyecto Foundry
│   ├── src/Vault.sol          # Se construye en la Clase 3, se audita en la 7
│   ├── src/Alcancia.sol       # La actividad de la Clase 3 (con TODOs)
│   └── offchain/              # Bonus: Hardhat + ethers + chai
├── cardano/                   # Proyecto Aiken
│   ├── validators/escrow.ak   # Se construye en la Clase 5, se audita en la 9
│   └── offchain/              # Mesh: transacciones reales contra un devnet local
└── scripts/                   # build-image, devnet, demos, exportar slides
```

**Ojo:** el material de las Clases 6 a 9 —las versiones vulnerables y arregladas— **no está todavía**
y se agrega a medida que avanza el curso. Ver **`PROXIMAS-CLASES.md`**.

## Los dos hilos conductores

- **Vault (Ethereum):** se construye en la Clase 3 → se audita y explota en la Clase 7
- **Escrow (Cardano):** se construye en la Clase 5 → se audita en la Clase 9

## Ver una transacción EUTXO en vivo (Clase 4)

```bash
./scripts/demo-tx-cardano.sh                          # el validator decidiendo, sin tocar la red
./scripts/devnet.sh up                                # un devnet local de Cardano (Yaci)…
cd cardano/offchain && npm install && npm run demo    # …y transacciones de verdad
```

## Mantenerse al día

Las slides y el material de las clases de análisis se van sumando. Antes de cada clase:

```bash
git pull
```

## Referencias principales

- *Mastering Ethereum*, **2ª edición (2025)** — Antonopoulos, Wood et al.
- *"I Can Aiken"* (John Greene) — Aiken hands-on, sin Haskell
- *Cyfrin Updraft* (`updraft.cyfrin.io`) — auditoría, seguridad y verificación formal
- *Mastering Cardano* (IOG) — `https://github.com/input-output-hk/mastering-cardano`
- Cardano Developer Portal y documentación de Aiken

## Licencia

Pendiente de elegir. Sugerencia habitual para material educativo: código bajo MIT y contenido
(slides) bajo CC BY-SA 4.0.
