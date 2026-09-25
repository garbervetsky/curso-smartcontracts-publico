# Containerfile — entorno completo del curso de smart contracts
#
# Compatible con Podman y Docker (formato OCI/Dockerfile).
# Trae TODO el material del curso + las herramientas de las 9 clases,
# con las cachés preparadas para poder trabajar sin internet.
#
# Multi-arquitectura:
#   - linux/amd64 (labs Intel)  -> Aiken se instala con aikup (binario oficial)
#   - linux/arm64 (Apple Silicon) -> aikup no publica binario aarch64-linux,
#                                     así que Aiken se compila desde fuente.
#
#   ./scripts/build-image.sh arm64|amd64                       # via script (recomendado)
#   podman build --platform linux/amd64 -t curso-sc:amd64 .     # para los labs Intel
#
# Ver docs/entorno-contenedor.md · o usar scripts/build-image.sh

# =============================================================================
# Etapa 1 — obtener el binario de Aiken para ESTA arquitectura
# =============================================================================
FROM debian:bookworm-slim AS aiken-fetch

ARG AIKEN_VERSION=v1.1.21
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl git build-essential pkg-config libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Intenta el binario oficial (amd64). Si no hay paquete para la arquitectura
# (caso aarch64-unknown-linux-gnu), compila desde fuente con Rust.
RUN set -eux; \
    mkdir -p /out; \
    export HOME=/root; \
    if curl -sSfL https://install.aiken-lang.org | bash \
       && "$HOME/.aiken/bin/aikup" install "${AIKEN_VERSION}"; then \
        echo ">>> Aiken: binario oficial via aikup"; \
        cp "$HOME/.aiken/bin/aiken" /out/aiken; \
    else \
        echo ">>> Aiken: sin binario para esta arquitectura, compilando desde fuente"; \
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal; \
        . "$HOME/.cargo/env"; \
        cargo install aiken --version "${AIKEN_VERSION#v}" --locked; \
        cp "$HOME/.cargo/bin/aiken" /out/aiken; \
    fi; \
    /out/aiken --version

# =============================================================================
# Etapa 2 — imagen del curso
# =============================================================================
FROM debian:bookworm-slim

# --- Versiones / opcionales -------------------------------------------------
# Las herramientas pesadas quedan detrás de flags para no inflar la imagen.
# LTS "Jod". Hardhat 3 exige >= 22.13
ARG NODE_VERSION=v22.23.2
ARG INSTALL_ADERYN=false
ARG INSTALL_MEDUSA=false
ARG INSTALL_CHROMIUM=false
# +372 MB: bonus off-chain de la Clase 3
ARG INSTALL_HARDHAT=false

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# --- Dependencias base ------------------------------------------------------
# z3: solver SMT que usa el SMTChecker de solc (Clases 6 y 7).
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl git unzip xz-utils jq make \
        python3 python3-venv \
        z3 \
        bash-completion less vim-tiny \
    && rm -rf /var/lib/apt/lists/*

# --- Aiken (desde la etapa 1) — Clases 4,5,8,9 -----------------------------
COPY --from=aiken-fetch /out/aiken /usr/local/bin/aiken
RUN aiken --version

# --- Node.js (Marp para las slides + off-chain de Cardano) ------------------
RUN set -eux; \
    case "$(dpkg --print-architecture)" in \
        amd64) NARCH=x64 ;; \
        arm64) NARCH=arm64 ;; \
        *) echo "arquitectura no soportada" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-${NARCH}.tar.xz" -o /tmp/node.tar.xz; \
    tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1; \
    rm /tmp/node.tar.xz; \
    node --version; npm --version

# Marp CLI: sirve/exporta los decks de docs/slides/
RUN npm install -g @marp-team/marp-cli && npm cache clean --force

# Chromium (opcional): sólo hace falta para exportar a PDF/PPTX.
# El modo servidor/HTML de Marp (para dar la clase) NO lo necesita.
RUN if [ "$INSTALL_CHROMIUM" = "true" ]; then \
        apt-get update && apt-get install -y --no-install-recommends chromium && \
        rm -rf /var/lib/apt/lists/*; \
    fi
ENV CHROME_PATH=/usr/bin/chromium

# --- Análisis Python: Slither y halmos --------------------------------------
# venv para no chocar con PEP 668 de Debian.
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/venv/bin/pip install --no-cache-dir slither-analyzer
ENV PATH=/opt/venv/bin:$PATH

# halmos (a16z): verificación simbólica acotada sobre tests de Foundry (Clases 6
# y 7; ethereum/test/halmos/). ~150 MB, casi todo el wheel de z3.
#
# NO se instala con un `pip install halmos` pelado, porque en arm64 no anda:
# halmos 0.3.3 fija `z3-solver==4.12.6.0`, que no tiene wheel para Linux
# aarch64 (pip intenta compilar z3 y falla por cmake), y además pide
# `eth_hash[pysha3]` (safe-pysha3, que hay que compilar con gcc) y
# `yices-solver` (sin wheel aarch64). Por eso las dependencias se instalan a
# mano, sólo en binario, y halmos con --no-deps:
#   - z3-solver 4.13.0.0: el primero con wheel manylinux2014 para aarch64.
#   - eth-hash con backend pycryptodome en lugar de pysha3.
#   - sin yices: ethereum/halmos.toml elige `solver = "z3"`.
# Es la misma receta en las dos arquitecturas, para que haya un solo camino.
# Verificado en arm64 el 2026-09-24: VaultVulnerableHalmos FAIL con
# contraejemplo y VaultHalmos PASS.
#
# El wheel de z3 deja un binario `z3` en /opt/venv/bin, que tapa al /usr/bin/z3
# de Debian (4.8.12). No afecta al SMTChecker: en amd64 solc carga libz3.so.4.12
# desde /usr/lib (más abajo), y en arm64 usa Eldarica.
ARG HALMOS_VERSION=0.3.3
RUN /opt/venv/bin/pip install --no-cache-dir --only-binary=:all: \
        "z3-solver==4.13.0.0" "eth-hash[pycryptodome]>=0.7.0" \
        "sortedcontainers>=2.4.0" "toml>=0.10.2" "rich>=14.0.0,<14.1.0" \
        "xxhash>=3.5.0" "psutil>=6.1.0" "requests>=2.32.3" "python-dotenv>=1.1.0" \
    && /opt/venv/bin/pip install --no-cache-dir --no-deps "halmos==${HALMOS_VERSION}" \
    && /opt/venv/bin/halmos --version

# --- Usuario no root (Podman rootless-friendly) -----------------------------
RUN useradd -m -u 1000 -s /bin/bash curso
USER curso
ENV HOME=/home/curso
WORKDIR /home/curso

# --- Foundry (forge, cast, anvil) — Clases 2,3,6,7 -------------------------
# Versión FIJA: un `foundryup` pelado instala la última, y con la 1.8.3 (build
# del 2026-09-24) pasaron dos cosas: halmos 0.3.3 deja de andar ("Unsupported
# cheat code: deployCode(string)" en el setUp) y forge cuenta los dos invariantes
# de VaultInvariantTest como un solo test, así que la línea base que cita el
# material (23) pasa a 22. Con la 1.7.1 las dos cosas vuelven. Lo de halmos se
# arregla también en 1.8 con `dynamic_test_linking = false`, que ya está en
# ethereum/foundry.toml; lo del conteo no tiene opción de configuración. Antes de
# subir la versión, correr `halmos` y `forge test` en ethereum/.
ARG FOUNDRY_VERSION=v1.7.1
ENV PATH=/home/curso/.foundry/bin:$PATH
RUN curl -L https://foundry.paradigm.xyz | bash \
    && foundryup --install "${FOUNDRY_VERSION}" \
    && forge --version && anvil --version

# --- Aderyn (opcional, analizador estático alternativo — Clase 6) ----------
RUN if [ "$INSTALL_ADERYN" = "true" ]; then \
        curl -L https://raw.githubusercontent.com/Cyfrin/aderyn/dev/cyfrinup/install | bash && \
        "$HOME/.cyfrin/bin/cyfrinup" || echo "WARN: aderyn no se pudo instalar (seguí sin él)"; \
    fi
ENV PATH=/home/curso/.cyfrin/bin:$PATH

# --- Medusa (opcional, fuzzer guiado por cobertura — Clase 6) --------------
RUN if [ "$INSTALL_MEDUSA" = "true" ]; then \
        set -eux; \
        case "$(dpkg --print-architecture)" in amd64) MARCH=x86_64 ;; arm64) MARCH=arm64 ;; esac; \
        mkdir -p "$HOME/.local/bin"; \
        curl -fsSL "https://github.com/crytic/medusa/releases/latest/download/medusa-linux-${MARCH}.tar.gz" \
            -o /tmp/medusa.tar.gz && \
        tar -xzf /tmp/medusa.tar.gz -C "$HOME/.local/bin" && \
        chmod +x "$HOME/.local/bin/medusa" && rm /tmp/medusa.tar.gz || \
        echo "WARN: medusa no se pudo instalar (seguí sin él)"; \
    fi
ENV PATH=/home/curso/.local/bin:$PATH

# --- Material del curso -----------------------------------------------------
# Se prepara el repo completo: slides, scripts y código de ambos tracks.
COPY --chown=curso:curso . /curso
WORKDIR /curso

# --- Precalentado de cachés (y validación de la imagen) --------------------
# Compila el track Ethereum: baja y cachea solc en ~/.svm, deja out/ listo.
# Si esto falla, la imagen NO se construye: es la verificación de que sirve.
#
# Se excluye AlcanciaTest: son los tests de la ACTIVIDAD de la Clase 3, que
# arrancan en rojo a propósito (el alumno los completa). La línea base son 14
# tests (11 de `Vault.t.sol`, 3 de `VaultVulnerable.t.sol`); ésos sí tienen que
# pasar para que la imagen se construya. test/halmos/ no entra: lo excluye
# `no_match_path` en foundry.toml, y se corre con `halmos`. (No están los de `withdrawAll` ni los de invariantes: se escriben
# en clase — ver PROXIMAS-CLASES.md.)
#
# Cuando se agregue el material de las Clases 6-9 (ver PROXIMAS-CLASES.md), ese
# número sube. Actualizalo acá si lo cambiás, pero no hace falta: el `forge test`
# falla solo si algo se rompe, el número del comentario es documentación.
#
# forge-std es un submódulo git. El contexto de build excluye .git/.gitmodules,
# así que normalmente viaja ya poblado desde el host. Si el clon del host no
# inicializó el submódulo, lib/forge-std llega vacío: en ese caso lo clonamos
# acá (versión fijada) para que la imagen se construya igual.
ARG FORGE_STD_VERSION=v1.16.1
RUN cd /curso/ethereum \
    && if [ ! -f lib/forge-std/src/Test.sol ]; then \
         echo ">>> forge-std ausente (submódulo sin inicializar en el host): clonando ${FORGE_STD_VERSION}"; \
         rm -rf lib/forge-std; \
         git clone --depth 1 --branch "${FORGE_STD_VERSION}" \
             https://github.com/foundry-rs/forge-std lib/forge-std; \
       fi \
    && forge build \
    && forge test --no-match-contract AlcanciaTest -vv

# Compila el track Cardano: baja stdlib a cardano/build/packages.
# `build` además regenera plutus.json (el blueprint), que es lo que consume el
# off-chain de la Clase 4: así la imagen nunca queda con un blueprint viejo.
#
# Línea base: los 7 tests de escrow.ak (los `claim_*` y `cancel_*`). Sube cuando
# se agreguen los validators de las Clases 8-9 (ver PROXIMAS-CLASES.md).
#
# Se filtra por nombre igual que el --no-match-contract AlcanciaTest de Ethereum,
# y por el mismo motivo: `vesting.ak` es el TALLER de la Clase 5 (`can_unlock` sin
# implementar) y sus 5 tests `unlock_*` arrancan en rojo a propósito. Un `aiken
# check` pelado sale con exit 1 y el build de la imagen no termina.
#
# OJO al filtrar: aiken no tiene flag de exclusión, y `-m escrow` (el módulo) NO
# matchea nada — corre 0 tests y sale 0, o sea que pasaría sin validar nada. `-m`
# matchea NOMBRES DE TEST, así que hay que nombrarlos como acá.
RUN cd /curso/cardano \
    && aiken check -m claim -m cancel \
    && aiken build

# --- Off-chain de Cardano (Mesh) — transacciones reales, Clase 4 -------------
# Deja node_modules preparado para que la demo arranque sin bajar nada.
# El devnet (Yaci) NO vive acá: corre aparte, con scripts/devnet.sh.
RUN cd /curso/cardano/offchain \
    && npm ci --no-audit --no-fund \
    && npm cache clean --force

# Desde adentro del contenedor, el devnet del host no es "localhost". Estos son
# los defaults para Podman; con Docker hay que pasar host.docker.internal.
ENV YACI_API=http://host.containers.internal:8080/api/v1/ \
    YACI_ADMIN=http://host.containers.internal:10000/local-cluster/api/

# libz3 para el SMTChecker de solc (Clase 6).
# El solc de linux-amd64 NO trae z3 adentro: lo carga dinámicamente y pide una
# versión EXACTA (`libz3.so.4.12`), que Debian bookworm no empaqueta (trae 4.8.12).
# Se baja la 4.12 oficial de Z3Prover y se instala con ese nombre.
#
# En arm64 esto NO sirve: el solc de aarch64 se compila SIN soporte de z3
# (0 símbolos Z3_*), así que el paso se salta en esa arquitectura y el SMTChecker
# usa Eldarica, que se instala más abajo.
#
# Escribe en /usr/lib y corre ldconfig, así que necesita root: a esta altura del
# Containerfile ya estamos como `curso` (desde la línea del USER más arriba), y
# sin este cambio de usuario el paso falla con "Permission denied".
ARG Z3_VERSION=4.12.2
USER root
RUN set -eux; \
    if [ "$(dpkg --print-architecture)" = "amd64" ]; then \
        curl -fsSL -o /tmp/z3.zip \
          "https://github.com/Z3Prover/z3/releases/download/z3-${Z3_VERSION}/z3-${Z3_VERSION}-x64-glibc-2.31.zip"; \
        cd /tmp && unzip -q z3.zip; \
        cp z3-*/bin/libz3.so /usr/lib/x86_64-linux-gnu/libz3.so.4.12; \
        ldconfig; rm -rf /tmp/z3.zip /tmp/z3-*; \
        echo ">>> libz3 4.12 instalada: el SMTChecker de solc funciona en esta imagen"; \
    else \
        echo ">>> arm64: el solc de aarch64 no soporta z3; el SMTChecker usa Eldarica"; \
    fi

# Eldarica — el solver del SMTChecker en arm64 (Clase 6).
#
# El otro solver que solc acepta para `chc`, y la única salida en aarch64: a
# Eldarica la invoca como PROCESO EXTERNO (busca `eld` en el PATH), así que no
# depende de cómo se compiló el binario de solc. Verificado sobre Vault.sol:
# reporta lo mismo que z3 (underflow "happens here" en la linea 30, overflow
# "might happen" en la 20) en ~110 s. Dos diferencias con z3, y ninguna se
# arregla: NO imprime el contraejemplo concreto (z3 dice `amount = 1`, Eldarica
# sólo dice que el camino existe), y una consulta termina en
# "CHC: Error trying to invoke SMT solver".
#
# Sólo se instala en arm64: son ~250 MB (Eldarica es JVM) y en amd64 no hace
# falta, porque ahí z3 anda y además da el contraejemplo. Que `eld` NO exista en
# la imagen amd64 es inofensivo: con `solvers = ["z3", "eld"]` en ethereum/foundry.toml
# solc usa z3, y sólo agrega un `Warning (4458): Solver Eldarica was selected ...
# but it was not found` (verificado en macOS el 2026-09-24). Esa línea es OBLIGATORIA: sin ella
# solc elige z3 aunque `eld` esté en el PATH, y en arm64 no analiza nada.
ARG ELDARICA_VERSION=2.3
RUN set -eux; \
    if [ "$(dpkg --print-architecture)" = "arm64" ]; then \
        apt-get update; \
        apt-get install -y --no-install-recommends default-jre-headless; \
        rm -rf /var/lib/apt/lists/*; \
        cd /opt; \
        curl -fsSL -o eld.zip \
          "https://github.com/uuverifiers/eldarica/releases/download/v${ELDARICA_VERSION}/eldarica-bin-${ELDARICA_VERSION}.zip"; \
        unzip -q eld.zip; rm eld.zip; \
        chmod +x "/opt/eldarica-bin-${ELDARICA_VERSION}/eld"; \
        ln -s "/opt/eldarica-bin-${ELDARICA_VERSION}/eld" /usr/local/bin/eld; \
        eld -h > /dev/null 2>&1 || true; \
        echo ">>> Eldarica ${ELDARICA_VERSION} instalada: el SMTChecker funciona en arm64"; \
    else \
        echo ">>> amd64: el SMTChecker usa z3, Eldarica no hace falta"; \
    fi
USER curso

# Bonus off-chain de la Clase 3 (opcional, +372 MB): Hardhat + ethers + chai.
# No entra por defecto porque es material optativo y pesa un tercio de la imagen.
# Para tenerlo listo:  podman build --build-arg INSTALL_HARDHAT=true ...
RUN if [ "$INSTALL_HARDHAT" = "true" ]; then \
        cd /curso/ethereum/offchain \
        && npm install --no-fund --no-audit \
        && npx hardhat test; \
    else \
        echo ">>> Hardhat NO preparado (INSTALL_HARDHAT=false). Se instala con: cd ethereum/offchain && npm install"; \
    fi

# Deja constancia de las versiones exactas preparadas.
RUN { \
      echo "# Versiones de esta imagen"; \
      echo "arquitectura: $(dpkg --print-architecture)"; \
      echo "fecha_build: $(date -u +%Y-%m-%dT%H:%M:%SZ)"; \
      echo "forge: $(forge --version | head -1)"; \
      echo "anvil: $(anvil --version | head -1)"; \
      echo "aiken: $(aiken --version)"; \
      echo "slither: $(slither --version 2>&1 | head -1)"; \
      echo "halmos: $(halmos --version 2>&1 | head -1)"; \
      echo "node: $(node --version)"; \
      echo "marp: $(marp --version 2>&1 | head -1)"; \
      echo "z3 (Debian): $(/usr/bin/z3 --version)"; \
      echo "z3 (wheel de halmos): $(/opt/venv/bin/z3 --version)"; \
    } > /home/curso/VERSIONES.txt

# --- PATH también para login shells -----------------------------------------
# `ENV PATH` no sobrevive a un login shell (`bash -l`, `podman run ... bash -lc`),
# porque /etc/profile lo reescribe. Sin esto, `forge` "no se encuentra".
USER root
RUN printf '%s\n' \
      'export PATH="/opt/venv/bin:/home/curso/.foundry/bin:/home/curso/.local/bin:/home/curso/.cyfrin/bin:$PATH"' \
      > /etc/profile.d/10-curso.sh \
    && chmod 644 /etc/profile.d/10-curso.sh
USER curso

WORKDIR /curso
CMD ["/bin/bash"]
