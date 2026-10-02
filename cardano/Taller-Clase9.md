## Taller de la Clase 9

**Entregable, en pares: un reporte corto de hallazgos y un fix verificado.** Todo se corre desde
`cardano/`. La primera vez, `aiken check` baja `aiken-lang/fuzz` de GitHub (hace falta internet;
la imagen reconstruida después de este cambio ya lo trae).

El validator a auditar es `validators/vesting_vulnerable.ak`: el vesting de la Clase 5, "versión
2", con un owner que puede cancelar, validación del output y protección contra double
satisfaction. Lo que dice que hace está en el comentario de arriba del archivo. Hace dos cosas
mal.

1. **Checklist y triage.** Aplicar el checklist de la Clase 8 a `vesting_vulnerable.ak`, ítem por
   ítem, ✅/❌ con una frase que lo justifique. Dos ❌ son bugs. Para cada ✅ que puedan, citar el
   test `v2_*` que lo demuestra (y si no hay test, escribirlo). Una pregunta guía: ¿qué campo del
   datum no se lee en ningún lado?

2. **Los PoCs: la tx-dato que aprueba.** En `vesting_vulnerable.ak`, escribir
   `poc_unlock_antes_del_deadline_se_aprueba` y `poc_cualquiera_se_lleva_los_fondos`, cada uno
   según la consigna de su comentario, y borrarles el `todo`. Correr `aiken check -m poc_`. Los
   dos tienen que **pasar**: en EUTXO el exploit es una transacción construida como dato, y el
   test afirma que el validator la aprueba. Probar el primero también con `interval.everything`:
   ¿qué significa que pase?

3. **Las propiedades de seguridad.** Escribir el cuerpo de
   `prop_unlock_rechaza_todo_rango_que_empieza_antes` y de `prop_solo_el_owner_recupera` (el
   generador del rango viene hecho). Correr `aiken check -m prop_`: contra este validator tienen
   que **fallar**. Leer el contraejemplo: ¿qué rango encontró? ¿Cruza el deadline? ¿Por qué dice
   `after 1 test` y no `after 100 tests`? Volver a correr con el `--seed=<n>` que imprime: ¿da el
   mismo contraejemplo?

4. **Dos hallazgos**, uno por bug, con este formato:

   ```markdown
   ## [SEVERIDAD] Título corto

   **Ubicación:** archivo y función
   **Descripción:** qué está mal y por qué es explotable
   **Impacto:** qué se pierde, cuantificado
   **Prueba de concepto:** el test que lo demuestra
   **Recomendación:** el cambio concreto
   **Estado:** dónde está corregido y qué test lo verifica
   ```

5. **El fix.** Copiar `validators/vesting_vulnerable.ak` a `validators/mi_vesting_fixed.ak`,
   renombrar el validator a `mi_vesting_fixed` y arreglar los dos bugs con el cambio más chico
   que los cierre. Conservar el `Datum` y el `Redeemer` como están. Verificarlo dos veces:
   - **Con las propiedades.** Las dos de la consigna 3, copiadas a `mi_vesting_fixed.ak`, tienen
     que pasar `[after 100 tests]`.
   - **Con los PoCs.** Los dos de la consigna 2, copiados y dados vuelta (`!can_unlock`,
     `!can_cancel`), tienen que pasar; y los `v2_*` tienen que seguir pasando.

   En `vesting_vulnerable.ak` las `prop_*` van a seguir en rojo, y está bien: documentan el bug.
   Si quieren `aiken check` en verde, muévanlas a su archivo en vez de copiarlas.

   Discutir: ¿su fix de `Cancel` sigue sirviendo si mañana le sacan el campo `quien` al redeemer?
   ¿Y el del tiempo, si el off-chain manda un rango sin cota inferior?

6. **Opcional: un LLM como auditor.** Pedirle una auditoría de `vesting_vulnerable.ak`. ¿Encuentra
   los dos bugs? ¿Inventa alguno que no existe? Confirmar o descartar **cada** hallazgo con un
   test.
