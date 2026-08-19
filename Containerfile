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
ARG INSTALL_HALMOS=false
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

# --- Análisis estático Python (Slither, opcionalmente halmos) ---------------
# venv para no chocar con PEP 668 de Debian.
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/venv/bin/pip install --no-cache-dir slither-analyzer \
    && if [ "$INSTALL_HALMOS" = "true" ]; then /opt/venv/bin/pip install --no-cache-dir halmos; fi
ENV PATH=/opt/venv/bin:$PATH

# --- Usuario no root (Podman rootless-friendly) -----------------------------
RUN useradd -m -u 1000 -s /bin/bash curso
USER curso
ENV HOME=/home/curso
WORKDIR /home/curso

# --- Foundry (forge, cast, anvil) — Clases 2,3,6,7 -------------------------
ENV PATH=/home/curso/.foundry/bin:$PATH
RUN curl -L https://foundry.paradigm.xyz | bash \
    && foundryup \
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
# arrancan en rojo a propósito (el alumno los completa). La línea base son los
# 11 tests de `Vault.t.sol`; ésos sí tienen que pasar para que la imagen se
# construya. (No están los de `withdrawAll` ni los de invariantes: se escriben
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
# Línea base: los 7 tests de escrow.ak. Sube cuando se agreguen los validators
# de las Clases 8-9 (ver PROXIMAS-CLASES.md).
RUN cd /curso/cardano \
    && aiken check \
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
# (0 símbolos Z3_*), así que el SMTChecker no puede funcionar. Por eso el paso
# se salta silenciosamente en esa arquitectura.
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
        echo ">>> arm64: el solc de aarch64 no soporta z3; el SMTChecker no estara disponible"; \
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
      echo "node: $(node --version)"; \
      echo "marp: $(marp --version 2>&1 | head -1)"; \
      echo "z3: $(z3 --version)"; \
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
