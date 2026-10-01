## Taller de la Clase 7

**Entregable, en pares: un reporte corto de hallazgos y un fix verificado.** Todo se corre desde
`ethereum/`. Para `halmos` hace falta la imagen reconstruida después de este cambio
(`./scripts/build-image.sh`). También podes bajar la imagen de este [repo](https://drive.google.com/drive/folders/1_lzZMsTSA2rjcV9YkzBjaUYWqbT3g0EY?usp=drive_link).

1. **Análisis estático y triage.** Correr `slither src/VaultVulnerable.sol` y clasificar cada
   hallazgo como real o ruido, con una frase que lo justifique. Después correr
   `slither src/VaultVulnerable.sol --print vars-and-auth`: ¿qué fila delata un bug que el triage
   de los hallazgos no encontró?

2. **El atacante y los PoCs.** En `test/VaultVulnerable.t.sol`, escribir `ReentrancyAttacker`
   y los dos tests (`test_Reentrancy_DrenaElVault` y
   `test_AccessControl_ExtranioSeQuedaConLosFondos`), cada uno según la consigna de su
   comentario, y borrarles el `vm.skip(true)`. Correr
   `forge test --match-test test_Reentrancy_DrenaElVault -vvvv` y 
   `forge test --match-test test_AccessControl_ExtranioSeQuedaConLosFondos -vvvv`
    y leer los traces (con `-vvv` no
   salen: forge sólo muestra la traza de los tests que fallan). En el de la
   reentrancy, contar las llamadas anidadas a `withdraw`.

3. **Invariantes y halmos.** Con su atacante andando, descomentar el `assertGe` de
   `invariant_solvency_DEMO` y correr
   `forge test --match-contract VaultVulnerableInvariantTest -vv`. ¿El fuzzer rompe la
   solvencia? ¿A cuántas llamadas reduce la secuencia? Volver a comentarlo al terminar.
   Después correr `halmos --contract VaultVulnerableHalmos`: con `AtacanteUnaVez` vacío da
   `[PASS]`. ¿Por qué? Escribirlo (consigna en su comentario) y volver a correr: ¿qué secuencia
   devuelve? ¿Qué afirma ese `FAIL` que no afirmaba el del fuzzer? Correrlo también con
   `--invariant-depth 1`: ¿qué da, y por qué?

   halmos imprime, debajo de cada llamada de la secuencia, su traza completa. Para ver sólo los
   valores y las llamadas:

   ```bash
   halmos --contract VaultVulnerableHalmos 2>&1 | sed 's/\x1b\[[0-9;]*m//g' \
     | grep -E '^    (p_|CALL)|^\[' | sed -E 's/ \(value:.*//'
   ```

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
