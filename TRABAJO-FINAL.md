# Trabajo final — "Explicá una vulnerabilidad"

**Formato.** En grupos de 2, o individual. A cada grupo se le asigna **un par** de vulnerabilidades
del catálogo de abajo: **una de Ethereum y una de Cardano**. El par lo asigna el docente.

**Entrega.** Tres cosas:

1. Una **presentación de 12 minutos**, más 3 de preguntas.
2. Un **documento breve** (2 a 3 páginas).
3. Un **repo con código que compile y corra**: una carpeta `ethereum/` que pase `forge test` y una
   `cardano/` que pase `aiken check`. Pueden partir de una copia de este repo.

**Fecha:** se confirma en clase.

**Por qué un par y no una sola.** Las dos vulnerabilidades de cada par son **la misma idea de fondo
en los dos modelos de ejecución**. Explicar las dos obliga a compararlas, y esa comparación es la
tesis del curso: cómo se rompe un contrato se deduce del modelo en el que corre.

## Qué hay que entregar, para cada una de las dos vulnerabilidades

1. **Qué es.** En tres oraciones simples, para alguien que no hizo el curso.
2. **Por qué existe en ese modelo.** Qué característica del modelo de ejecución la hace posible.
3. **Un ejemplo mínimo que la exhibe.** Código **propio**: Solidity para Ethereum, Aiken para
   Cardano. Tiene que compilar. Lo más chico que muestre el problema, sin adornos.
4. **Un test que la demuestra.** En Foundry o en Aiken. Vale la forma de la Clase 7 (un test que
   explota) o la de la Clase 9 (un test que **pasa** mostrando una aprobación indebida).
   **Sin test, la vulnerabilidad es una opinión.**
5. **El fix.** Código, y una oración sobre **qué le cuesta**: ¿prohíbe algún caso de uso legítimo?
   ¿cuánto gas o cuántas ExUnits agrega? No existe el fix gratis. El test del punto 4, apuntado al
   fix, tiene que dar vuelta el resultado.
6. **¿Alguna herramienta lo detecta?** Correr Slither sobre el ejemplo de Ethereum, y lo que
   corresponda sobre el de Cardano (property tests, el checklist de la Clase 8), **antes y después**
   del fix, y **pegar la salida real**. Hay tres respuestas posibles y las tres valen, si están
   argumentadas:
   - *La detecta.* ¿Con qué detector, con qué severidad, y qué ruido hay alrededor?
   - *No la detecta.* **¿Por qué no?** ¿Es un patrón sintáctico que la herramienta no tiene, o es
     una propiedad de la intención que ninguna herramienta puede ver?
   - *Detecta otra cosa.* El caso más interesante: la herramienta opina, pero de lo irrelevante.

**Regla que se aplica sin excepción:** toda salida de herramienta que aparezca en el informe tiene
que haber sido **corrida por el grupo**, sobre **su** código. Nada de transcribir lo que dice un
blog. Es la misma regla con la que se armó el material de la materia.

**Lo que más pesa**, en las tres entregas: que el test **demuestre** y no describa, que el fix diga
qué sacrifica, que la lectura de la herramienta sea honesta (un "no la detecta" bien explicado vale
más que un "la detecta" sin decir por qué), y **la comparación entre los dos modelos**, que es el
punto del par.

## Cómo organizar los 12 minutos

Una sugerencia, no una obligación: 1 minuto para la idea común del par; 4 para cada vulnerabilidad
(qué es, el ejemplo, el test corriendo, el fix y su costo, qué dijo la herramienta); 3 para la
comparación: por qué la misma idea toma dos formas distintas. El código se muestra corriendo, no en
capturas.

---

# Catálogo de pares

## Par 1 — Autenticar lo que no producís vos

> **La idea común:** el contrato recibe un dato que **no generó** —una firma, un datum— y lo trata
> como si fuera confiable. En los dos modelos el fix es el mismo en espíritu: atar el dato a algo
> que el atacante no controla.

### 1-E · Ethereum: *signature replay*

Un contrato acepta una operación firmada off-chain (`ecrecover`, permits, meta-transacciones). Si la
firma no incluye un **nonce**, la misma firma se puede reenviar N veces. Si no incluye el `chainId`
o la dirección del contrato, sirve en **otra cadena u otro contrato**.

- **Fuente:** *Mastering Ethereum* 2ª ed., cap. 9, sección *Signature Replay Attack*, con el caso
  del token **TCH**.
- **Para el fix:** EIP-712 (dominio tipado) y los contratos `ECDSA` / `EIP712` de OpenZeppelin.
- **Pregunta guía para el punto 6:** "¿esta firma ya se usó?" ¿es algo que se ve en el código, o
  en el protocolo?

### 1-C · Cardano: *missing UTxO authentication*

**Cualquiera puede crear un UTXO en la dirección de un script y ponerle el datum que quiera.** Si el
validator no verifica **cuál** UTXO es el legítimo, se lo engaña con uno falso. El caso canónico es
un oráculo: un validator lee "el UTXO con el precio" y el atacante planta uno propio con el precio
que le conviene.

- **Fuente:** *Mastering Cardano*, cap. 8, sección *Smart contract security*, ítem **missing UTXO
  authentication**. Ataque y mitigación en detalle: MLabs, *Common Plutus Security Vulnerabilities*.
  Es el ítem 1c de la Clase 8 y el #3 de la serie de Vacuumlabs ("Trust no UTxO").
- **El fix idiomático de EUTXO:** marcar los UTXOs legítimos con un **token de autenticación** que
  sólo el protocolo puede acuñar. El validator no confía en la dirección: confía en el token.
- **Práctica:** los niveles de oráculo y datum del **Cardano CTF**.

## Par 2 — El código correcto ejecutado en el contexto equivocado

> **La idea común:** la lógica es correcta, pero corre con un `storage`, un propósito o un
> privilegio que no le corresponde. No hay una línea "mal escrita" que señalar.

### 2-E · Ethereum: `delegatecall` y colisión de storage en proxies

`delegatecall` ejecuta código ajeno **sobre el storage propio**. Si el layout del proxy y el de la
implementación no coinciden, escribir una variable pisa otra. Y una implementación sin inicializar
puede ser tomada por cualquiera.

- **Fuente:** *Mastering Ethereum* 2ª ed., cap. 9, sección *DELEGATECALL*, con el caso **Parity
  multisig wallet (second hack)**.
- **Pregunta guía para el punto 6:** Slither tiene detectores alrededor de `delegatecall`. ¿Cuáles
  disparan sobre su ejemplo, y ven **la colisión de storage** o sólo el `delegatecall`?

### 2-C · Cardano: *other redeemer*

El validator asume implícitamente **con qué redeemer lo están invocando**. El atacante gasta el UTXO
con **otro** constructor del redeemer, cuyo camino de validación es más débil, y saltea los chequeos
que protegían la operación que quería hacer. MLabs lo ejemplifica con un protocolo donde se consume
un UTXO usando `AddRewards` en vez de `UpdatePosition`.

- **Fuente:** *Mastering Cardano*, cap. 8, ítem **other redeemer**. Descripción y mitigación: MLabs,
  *Common Plutus Security Vulnerabilities*.
- **Lo que tiene que tener el ejemplo:** un validator con **estado** (un datum que cambia entre
  transacciones) y al menos dos redeemers con reglas distintas, donde el camino débil permita lo
  que el fuerte prohíbe. El `Cancel` del taller de la Clase 9 **no vale**: ése ya lo hicimos.
- **Mitigación:** exigir **explícitamente** el redeemer bajo el cual vive la lógica esperada, en vez
  de asumirlo. Se conecta con el `else(_) { fail }` de la Clase 4.
- **Para el punto 6:** un property test que recorra todos los constructores del redeemer y verifique
  que sólo el esperado aprueba.

## Par 3 — Romper la disponibilidad sin robar nada

> **La idea común:** el atacante no se lleva fondos: **impide que los demás operen**. En los dos
> modelos el costo del ataque es bajo y el daño es de diseño, no de una línea de código.

### 3-E · Ethereum: DoS por gas

Un loop sobre un array que crece sin límite termina excediendo el gas del bloque. Un pago dentro de
un loop a una dirección que revierte a propósito bloquea la función para todos.

- **Fuente:** *Mastering Ethereum* 2ª ed., cap. 9, sección *Denial of Service*, con el caso **ZKsync
  Era Gemholic** (fondos bloqueados). Patrón de fix: *pull over push*.
- **Pregunta guía para el punto 6:** Slither tiene varios detectores sobre loops. ¿Cuáles disparan,
  con qué severidad, y cuáles son ruido en su ejemplo? Es un ejercicio de triage.

### 3-C · Cardano: contención de UTXO y *cheap spam*

Un diseño que concentra el estado en **un solo UTXO** crea un cuello de botella: dos usuarios que
quieren operar compiten por el mismo input y uno falla. Un atacante puede sostener esa contención
barato, o llenar el script de UTXOs basura.

- **Fuente:** *Mastering Cardano*, cap. 8, ítems **UTXO contention** y **cheap spam**. Se conecta con
  min-ADA y dust (Clase 8, 1d).
- **Cómo se demuestra sin herramienta:** modelando el flujo de transacciones. Dos transacciones que
  quieren el mismo UTXO en el mismo bloque: una entra, la otra no. El "test" acá es el modelo.
- **Fix típico:** partir el estado en varios UTXOs, o tokens de estado. Decir qué cuesta.
- **Variante que pueden sumar:** *arbitrary datum*: bloquear UTXOs con un datum **malformado**, de
  un tipo que el validator no espera. No sirve para robar: sirve para que esos UTXOs **no se puedan
  gastar nunca más**. No confundir con 1-C: ahí el datum es *válido pero falso*; acá es *malformado*.

## Par 4 — Confiar en un número que no controlás

> **La idea común:** el contrato toma una decisión con valor de dinero basándose en un dato del
> entorno —aleatoriedad, precio, cantidad— que alguien más puede inclinar a su favor.

### 4-E · Ethereum: aleatoriedad on-chain y manipulación de precio

Todo lo que está on-chain es público y, en parte, influenciable: `block.timestamp`, `blockhash`,
`PREVRANDAO`. Un sorteo basado en eso es predecible o manipulable por quien propone el bloque. La
variante con dinero grande es tomar el precio de un AMM como oráculo.

- **Fuente:** *Mastering Ethereum* 2ª ed., cap. 9, secciones *Entropy Illusion* (caso **Fomo3D**) y
  *Price Manipulation* (caso **Mango Markets**).
- **Pregunta guía para el punto 6:** ¿qué dice Slither de la fuente de aleatoriedad? ¿Y del oráculo?
  Comparar con lo que pasó en el par 1.

### 4-C · Cardano: minting policy que no valida el *token name* ni la cantidad

Una política que autoriza acuñar sin verificar **qué** se acuña (el asset name) o **cuánto**, o que
no distingue acuñar de quemar por el signo, deja emitir tokens fuera de las reglas.

- **Fuente:** *Mastering Cardano*, cap. 8, ítems **other token name** y **unbounded value**.
  Vacuumlabs, *Cardano Vulnerabilities #5: Token Security*.
- **Se apoya en:** la Clase 4 (tokens nativos, `mint` con cantidad negativa es quemar) y la policy
  `token_fragil` de la Clase 8, que es el punto de partida.
- **Para el punto 6:** property tests sobre el campo `mint` del contexto.

## Par 5 — Contar mal

### 5-E · Ethereum: precisión, redondeo y el *inflation attack* de ERC-4626

División entera que trunca, dividir antes de multiplicar, redondeo que siempre favorece al mismo
lado. El caso canónico es el ataque de inflación al primer depositante de un vault ERC-4626.

- **Fuente:** *Mastering Ethereum* 2ª ed., cap. 9, sección *Floating Point and Precision*, con el
  caso **ERC-4626 inflation attack**.
- **Pregunta guía para el punto 6:** ¿lo que marca Slither es el problema, o un síntoma del
  problema? ¿Quién entiende que el ataque es económico?

### 5-C · Cardano: *unbounded inputs* (fragmentación del estado)

Un validator que **no restringe la forma de los outputs** deja que el estado se fragmente en muchos
UTXOs chicos. Después, una operación legítima necesita consumirlos todos, y la transacción termina
excediendo el límite de tamaño y el presupuesto de ExUnits: el protocolo se vuelve inusable. El
ejemplo de MLabs es un faucet.

- **Fuente:** *Mastering Cardano*, cap. 8, ítem **unbounded inputs**. Detalle: MLabs, *Common Plutus
  Security Vulnerabilities*.
- **Mitigación:** imponer restricciones estructurales sobre los outputs, típicamente **un input de
  script y un output**. Es el mismo fix que vimos contra la double satisfaction en la Clase 8, por
  otra razón: allá era corrección, acá es disponibilidad. Buen material para "qué le cuesta al fix".
- **Para el punto 6:** `aiken check` imprime las ExUnits de cada test. Midan las dos versiones y
  muestren los números: es el único par del catálogo donde la herramienta da un valor duro y
  comparable.

---

## Fuentes

- *Mastering Ethereum*, 2ª ed., **capítulo 9**: <https://masteringethereum.xyz/chapter_9.html>
- *Mastering Cardano*, **capítulo 8**, sección *Smart contract security*:
  <https://github.com/input-output-hk/mastering-cardano/blob/main/chapters/chapter-08-writing-smart-contracts-plutusv3.adoc>
- MLabs, *Common Plutus Security Vulnerabilities*:
  <https://www.mlabs.city/blog/common-plutus-security-vulnerabilities>
- Cardano Developer Portal, *Smart Contract Security* (el catálogo oficial):
  <https://developers.cardano.org/docs/developers/curriculum/smart-contracts/security/>
- Vacuumlabs / Invariant0, serie *Cardano Vulnerabilities* (#1 a #6) y el **Cardano CTF**:
  <https://github.com/Invariant-0/cardano-ctf>
- Reportes de auditoría públicos, para ver el formato real de un hallazgo:
  <https://github.com/tweag/tweag-audit-reports> y <https://github.com/vacuumlabs/audits>
- El material del curso: las consignas de los talleres (`ethereum/Taller-Clase7.md`,
  `cardano/Taller-Clase9.md`) tienen el formato de hallazgo que se espera en el documento.
