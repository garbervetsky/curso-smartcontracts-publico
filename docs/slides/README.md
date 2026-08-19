# Slides

Presentaciones por clase, en **Marp** (Markdown → slides). Una carpeta por clase:
`clase-01/`, `clase-02/`, … Cada una tiene un `slides.md` con frontmatter `marp: true`.

## Principio de diseño (importante)

Los decks son una **expansión fiel y detallada** del guion de cada clase,
**no** un resumen. Reglas:

- El deck debe cubrir **todo** el contenido del guion — nunca menos.
- Cada **segmento** del guion se despliega en **varias** slides (una idea por slide).
- Se **agregan ejemplos** concretos para clarificar (código, números, diagramas) que en el
  guion están condensados o implícitos.
- El guion es el índice; el deck es el desarrollo.

## Estado

Las 9 clases completas (formato Marp, con figuras SVG inline). 269 slides en total.

| Clase | Deck | Slides | Figuras |
|---|---|---|---|
| 1 — Fundamentos | ✅ `clase-01/slides.md` | 35 | sí |
| 2 — Intro Solidity | ✅ `clase-02/slides.md` | 30 | sí |
| 3 — Taller Solidity (Foundry/Vault) | ✅ `clase-03/slides.md` | 31 | sí |
| 4 — Intro Aiken/Plinth | ✅ `clase-04/slides.md` | 34 | sí |
| 5 — Taller Aiken (escrow) | ✅ `clase-05/slides.md` | 28 | sí |
| 6 — Intro análisis Solidity | ✅ `clase-06/slides.md` | 32 | sí |
| 7 — Taller análisis (Ethereum) | ✅ `clase-07/slides.md` | 27 | sí |
| 8 — Intro análisis Cardano | ✅ `clase-08/slides.md` | 27 | sí |
| 9 — Taller análisis (Cardano) | ✅ `clase-09/slides.md` | 25 | sí |

## Cómo renderizar

Las slides son Markdown estándar con separadores `---`. Para verlas/exportarlas hay dos
caminos:

### Opción A — Extensión de VS Code (la más simple)

Instalar **"Marp for VS Code"**. Abrir cualquier `slides.md` y usar el preview (ícono arriba
a la derecha). Desde ahí se exporta a PDF/PPTX/HTML con el comando *"Marp: Export Slide Deck"*.

### Opción B — Marp CLI

```bash
# instalar una vez (requiere Node.js, ya disponible en el entorno)
npm install -g @marp-team/marp-cli

# exportar a PDF (el --html es para el rendering de imagenes)
marp docs/slides/clase-01/slides.md --pdf --html

# exportar a HTML
marp docs/slides/clase-01/slides.md --html

# exportar a PowerPoint
marp docs/slides/clase-01/slides.md --pptx --html

# modo preview con recarga en vivo mientras editás
marp -s docs/slides/clase-01/
```

El archivo de salida queda junto al `slides.md` (ej. `clase-01/slides.pdf`).

> Atajo: `./scripts/slides-export.sh` exporta todas las clases de una
> (`--pdf`, `--pptx`, o `--editable`; o pasá `06` para una sola).

## ¿Editar las slides? Cómo funciona (y el PPTX editable)

**La fuente editable de verdad es el `.md`.** Un deck de Marp se edita en `slides.md` y se re-exporta;
para retocar texto, números u orden es lo más rápido y **100% fiel** (conserva diagramas y estilo).
Cada slide es lo que va entre dos `---`; el preview en vivo se ve con `marp -s docs/slides/`.

Sobre exportar a **PowerPoint editable** (pregunta habitual), hay un trade-off sin solución perfecta,
porque los diagramas y las cajas de estos decks son **SVG/HTML de Marp** que PowerPoint no entiende:

| Objetivo | Herramienta | Resultado (verificado abriendo el archivo) |
|---|---|---|
| Presentar, fiel al diseño | `marp --pptx` | cada slide es una **imagen** — no editable, pero **se ve perfecto** |
| **Editar el contenido** | **editar el `.md`** + re-exportar | fiel al 100%, la fuente es editable |
| ~~PPTX editable~~ | `marp --pptx-editable` | ❌ **no sirve para estos decks:** los **diagramas SVG no renderizan** y el texto queda **fragmentado en un cuadro por oración**. Descartado. |
| ~~PPTX nativo~~ | `pandoc slides.md -o out.pptx` | ❌ los **SVG se pierden** por completo y el layout se descuadra. Descartado. |

**Conclusión (probado):** para un deck con diagramas como estos **no hay una exportación a PowerPoint
editable que valga la pena** — la parte visual (diagramas, cajas) vive en SVG/HTML que ni PowerPoint
ni los conversores reconstruyen bien. Los dos caminos que sí funcionan:

- **Presentar** → `marp --pptx` (imágenes) o el HTML. Se ve exactamente como el diseño.
- **Editar/mantener** → el **`.md`** (la fuente editable) + re-exportar con `./scripts/slides-export.sh`.

> Si en algún momento necesitás *sí o sí* un `.pptx` editable para un tercero, lo más práctico es
> rehacer esa slide puntual a mano en PowerPoint, no convertir el deck entero.

## Convenciones de estilo de los decks

- `<!-- _class: lead -->` centra la slide (portadas, secciones, remates).
- `<!-- _paginate: false -->` oculta el número de página (portada/cierre).
- `header` / `footer` en el frontmatter se repiten en todas las slides.
- Una idea por slide; las tablas comparativas Eth↔Cardano son el recurso recurrente.
- El código va en bloques con fence ` ```solidity ` / ` ```aiken ` para el resaltado.
