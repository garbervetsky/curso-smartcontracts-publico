# Material que se agrega durante el curso

Este repo arranca con lo necesario para las **Clases 1 a 5** y para construir el
entorno completo. El material de análisis y seguridad se va sumando **a medida que
avanza el curso**: no está acá todavía, y eso es a propósito.

Para traer lo nuevo, desde tu clon:

```bash
git pull
```

## Qué falta y cuándo llega

| Cuándo | Qué se agrega | Dónde va a aparecer |
|---|---|---|
| **Clase 6** | `VaultInvariant.t.sol` — tests de invariantes | `ethereum/test/` |
| **Clases 6–7** | `VaultVulnerable.sol` y sus tests | `ethereum/src/`, `ethereum/test/` |
| **Clases 6–7** | `VaultFixed.sol` y sus tests | `ethereum/src/`, `ethereum/test/` |
| **Clases 8–9** | `escrow_vulnerable.ak` | `cardano/validators/` |
| **Clases 8–9** | `escrow_fixed.ak` | `cardano/validators/` |
| **Cada clase** | Las slides | `docs/slides/clase-NN/slides.md` |

## Por qué no está todo desde el día 1

Las versiones `_vulnerable` y `_fixed` **son** el ejercicio de las Clases 6 a 9:
una tiene el bug que hay que encontrar, la otra es la respuesta. Tenerlas a mano
desde el principio convierte un taller de análisis en una lectura.

El caso base sí está completo desde ahora — `Vault.sol` y `escrow.ak` son el punto
de partida de todo lo demás.

## Qué pasa con la imagen del contenedor

La imagen se construye igual, con lo que haya en el repo en ese momento. Cuando
llegue material nuevo tenés dos opciones:

- **Reconstruir la imagen** — `./scripts/build-image.sh` (ver `docs/entorno-contenedor.md`)
- **No reconstruir nada** — montá tu clon actualizado sobre el contenedor:

  ```bash
  podman run --rm -it -v "$PWD":/curso:z curso-sc:local bash
  ```

  La segunda es más rápida y suele ser lo que querés durante el curso: las
  herramientas ya están adentro, sólo cambia el material.

> La validación del build (`forge test`, `aiken check`) usa los tests que existan
> en ese momento. Hoy la línea base es **11 tests en Ethereum** y **7 en Cardano**;
> con el material nuevo esos números suben.

## Lo que se escribe en clase, no se agrega después

Distinto de lo de arriba: esto **no va a llegar por `git pull`** — lo escribís vos
durante el taller de la Clase 3. Están en el repo como **TODO**, con la consigna en el comentario:

| Dónde | Qué falta |
|---|---|
| `ethereum/src/Vault.sol` | `withdrawAll()` — el cuerpo está vacío |
| `ethereum/test/Vault.t.sol` | los **dos** tests de `withdrawAll` (el camino feliz y el borde) |
| `ethereum/src/Alcancia.sol` | `retirar()` — es la actividad de cierre |
| `ethereum/test/Alcancia.t.sol` | 4 tests de la `Alcancia`, que arrancan en rojo |
