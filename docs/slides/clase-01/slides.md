---
marp: true
theme: default
paginate: true
header: 'Smart Contracts — Clase 1'
footer: 'Fundamentos: cuentas (Ethereum) vs EUTXO (Cardano)'
style: |
  section { font-size: 25px; }
  section.lead { justify-content: center; text-align: center; }
  section.lead h1 { font-size: 52px; }
  section.lead h2 { font-size: 34px; color: #475569; }
  section.small { font-size: 22px; }
  table { font-size: 21px; }
  th { background: #f1f5f9; }
  svg { display: block; margin: 0.3em auto; }
  pre { font-size: 18px; }
  .key { background: #fef9c3; border-left: 6px solid #ca8a04; padding: 0.3em 0.7em; }
  .seg { color: #64748b; font-size: 20px; letter-spacing: 2px; }
  .nota { color: #b45309; font-weight: 700; }
---

<!-- _class: lead -->
<!-- _paginate: false -->

# Clase 1
## Fundamentos de blockchain y comparación de modelos

## Profesor: Diego Garbervetsky


### Cuentas (Ethereum) vs EUTXO (Cardano)

---

<!-- _class: lead -->

## Idea de la clase — y del curso

> Cómo se **escribe** y cómo se **rompe** un contrato
> es una consecuencia directa del
> **modelo de ejecución** de la blockchain.


---

## Objetivos de aprendizaje

Al terminar, vas a poder:

- Explicar **qué problema resuelve** una blockchain y por qué necesita **consenso**
- Describir la **anatomía** de una transacción y un bloque
- **Distinguir el modelo de cuentas del modelo (E)UTXO**
- Anticipar por qué cada uno genera **clases de bugs distintas**
- Identificar **dónde corre el código**: EVM vs UPLC, on-chain vs off-chain

---

<!-- _class: lead -->

<span class="seg">SEGMENTO 1 · ~25 min</span>

# ¿Qué problema resuelve
# una blockchain?

---

## Un libro de cuentas (*ledger*) compartido

Replicado entre partes que **no confían** entre sí, **sin autoridad central**.

<svg viewBox="0 0 880 210" width="760">
  <g font-family="sans-serif" font-size="14" text-anchor="middle">
    <rect x="40"  y="40" width="150" height="150" rx="10" fill="#f1f5f9" stroke="#334155"/>
    <text x="115" y="32" font-size="13">Nodo A</text>
    <line x1="60" y1="70" x2="170" y2="70" stroke="#94a3b8"/>
    <line x1="60" y1="100" x2="170" y2="100" stroke="#94a3b8"/>
    <line x1="60" y1="130" x2="170" y2="130" stroke="#94a3b8"/>
    <line x1="60" y1="160" x2="170" y2="160" stroke="#94a3b8"/>
    <rect x="365" y="40" width="150" height="150" rx="10" fill="#f1f5f9" stroke="#334155"/>
    <text x="440" y="32" font-size="13">Nodo B</text>
    <line x1="385" y1="70" x2="495" y2="70" stroke="#94a3b8"/>
    <line x1="385" y1="100" x2="495" y2="100" stroke="#94a3b8"/>
    <line x1="385" y1="130" x2="495" y2="130" stroke="#94a3b8"/>
    <line x1="385" y1="160" x2="495" y2="160" stroke="#94a3b8"/>
    <rect x="690" y="40" width="150" height="150" rx="10" fill="#f1f5f9" stroke="#334155"/>
    <text x="765" y="32" font-size="13">Nodo C</text>
    <line x1="710" y1="70" x2="820" y2="70" stroke="#94a3b8"/>
    <line x1="710" y1="100" x2="820" y2="100" stroke="#94a3b8"/>
    <line x1="710" y1="130" x2="820" y2="130" stroke="#94a3b8"/>
    <line x1="710" y1="160" x2="820" y2="160" stroke="#94a3b8"/>
    <line x1="190" y1="115" x2="365" y2="115" stroke="#2563eb" stroke-width="2" stroke-dasharray="6 4"/>
    <line x1="515" y1="115" x2="690" y2="115" stroke="#2563eb" stroke-width="2" stroke-dasharray="6 4"/>
    <text x="277" y="105" font-size="12" fill="#2563eb">mismo libro</text>
    <text x="602" y="105" font-size="12" fill="#2563eb">mismo libro</text>
  </g>
</svg>

Cada nodo guarda una copia idéntica; todos tienen que **acordar** qué dice el libro.

---

## Blockchain vs BD tradicional

Una blockchain **es** una base de datos — pero con **muchas más restricciones**.

| | BD tradicional | Blockchain |
|---|---|---|
| Operaciones | CRUD: `INSERT` / `UPDATE` / `DELETE` | **sólo agregar** (append-only) |
| Quién escribe | quien autoriza el **admin** | cualquiera con una clave, si cumple las reglas |
| Quién valida | el servidor — le **creés** | **todos los nodos** re-ejecutan |
| Rendimiento | decenas de miles de ops/s | **decenas de tx/s** |
| Costo | barato | caro: se replica **en todos** |
| ¿Te pueden apagar o censurar? | sí, el dueño | no hay dueño a quien pedirle permiso |

<div class="key">

Más lenta, más cara y con menos operaciones. Todo ese sacrificio compra **una sola cosa**:
que no haga falta **confiar en un administrador**.

</div>

> Ese "y aún así todos acuerdan" es **todo el problema**. De ahí salen tres preguntas.

---

## Problema 1 — Ordenar las transacciones

Si dos personas mandan transacciones "al mismo tiempo", ¿cuál va primero?

<div class="key">

No hay un reloj global ni un árbitro. Hay que **acordar un orden** entre nodos
que no confían entre sí → eso es el **consenso**.

</div>

El orden no es un detalle: como veremos, **quién decide el orden** puede explotarlo
(front-running, MEV).

---

## Problema 2 — Evitar el doble gasto

Ejemplo concreto:

<svg viewBox="0 0 880 165" width="780">
  <g font-family="sans-serif" font-size="13" text-anchor="middle">
    <rect x="330" y="20" width="220" height="40" rx="8" fill="#f1f5f9" stroke="#334155"/>
    <text x="440" y="45">Alice tiene 10 monedas</text>
    <line x1="420" y1="60" x2="250" y2="95" stroke="#dc2626" stroke-width="2" marker-end="url(#a)"/>
    <line x1="460" y1="60" x2="630" y2="95" stroke="#dc2626" stroke-width="2" marker-end="url(#a)"/>
    <rect x="120" y="98" width="260" height="50" rx="8" fill="#fee2e2" stroke="#dc2626"/>
    <text x="250" y="120">tx 1: paga 10 a Bob</text>
    <text x="250" y="138" font-size="11">enviada a unos nodos</text>
    <rect x="500" y="98" width="260" height="50" rx="8" fill="#fee2e2" stroke="#dc2626"/>
    <text x="630" y="120">tx 2: paga 10 a Carol</text>
    <text x="630" y="138" font-size="11">enviada a otros nodos</text>
    <defs><marker id="a" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto"><path d="M0,0 L9,3 L0,6" fill="#dc2626"/></marker></defs>
  </g>
</svg>

Sin acuerdo, **ambas** podrían aceptarse: Alice gastó **20** monedas que no tenía.
El consenso + el orden garantizan que **sólo una** sea válida.

---

## Problema 3 — Que el pasado no se reescriba

**Inmutabilidad / finalidad**: una vez que una transacción es vieja, debe ser
prácticamente imposible borrarla o cambiarla.

- Si cualquiera pudiera reescribir el pasado, podría "des-gastar" sus monedas
- La blockchain está diseñada para que **alterar el pasado sea muy costoso**
  (lo vemos en la anatomía, con el encadenamiento por hash)

> Tres problemas, una misma raíz: **acordar sin confiar**.
> (El nombre clásico del problema: tolerancia a **fallas bizantinas** —
> algunos participantes pueden mentir activamente, y el conjunto igual converge.)

---

## Qué NO resuelve una blockchain

Para calibrar expectativas desde el día uno:

| No resuelve | Por qué |
|---|---|
| **Privacidad** | Al contrario: el libro es **público por diseño** — cualquiera ve cada tx de cada dirección |
| **Veracidad de datos externos** | La blockchain garantiza *consistencia interna*, no que "el dólar cotiza a X" sea cierto → **oráculos** (Clase 6) |
| **Escala barata** | Replicar todo en todos los nodos es lo opuesto a eficiente — es el precio de no tener admin |

<div class="key">

Los oráculos —el puente con el mundo real— son a su vez una **superficie de ataque**.
Se ven en la Clase 6.

</div>

---

## ¿Cuándo NO usar blockchain?

<div class="key">

Si existe un tercero en quien **todas** las partes pueden confiar → **usá una base de datos**.
Va a ser más rápida, más barata y más simple.

</div>

Una blockchain recién se justifica cuando el **costo de confiar** en alguien supera al
**costo de replicar todo en todos**: partes que no se conocen, que compiten entre sí,
o un árbitro que podría hacer trampa.

> El error más común del rubro es exactamente ese: usar una blockchain como base de
> datos lenta para un problema que no la necesitaba.

---

<!-- _class: lead -->

<span class="seg">SEGMENTO 2 · ~20 min</span>

# Anatomía
# tx · bloque · hash · estado

---

## Herramienta 1 — Hash criptográfico

Comprime cualquier dato a una **huella de tamaño fijo**:

```text
sha256("hola") = b221d9dbb083a7f33428d7c2a3c3198ae925614d70210e28716ccaa7cd4ddb79
sha256("Hola") = e633f4fc79badea1dc5db970cf397c8248bac47cc3acf9915ba60b5d76b0e88f
```

Tres propiedades que usamos todo el tiempo:

1. **Determinista** — mismo input, misma huella
2. **Avalancha** — un bit distinto cambia TODO (mirá: sólo cambió una mayúscula)
3. **Unidireccional** — de la huella no se recupera el input

<div class="key">

Un hash funciona como **compromiso**: si publico el hash de algo,
no puedo cambiar ese algo sin que se note.

</div>

*(Cada blockchain elige su función: Ethereum keccak256, Cardano blake2b — mismas garantías.)*

---

## Herramienta 2 — Firma digital

Un **par de claves**: con la **privada** se firma, con la **pública** cualquiera verifica.

<svg viewBox="0 0 880 150" width="800">
  <g font-family="sans-serif" font-size="13" text-anchor="middle">
    <rect x="30" y="45" width="180" height="60" rx="8" fill="#fee2e2" stroke="#dc2626"/>
    <text x="120" y="72" font-weight="bold">clave privada</text>
    <text x="120" y="92" font-size="11">sólo Alice la tiene</text>
    <line x1="210" y1="75" x2="320" y2="75" stroke="#334155" stroke-width="2" marker-end="url(#fs)"/>
    <text x="265" y="65" font-size="12">firma la tx</text>
    <rect x="325" y="45" width="200" height="60" rx="8" fill="#f1f5f9" stroke="#334155"/>
    <text x="425" y="72" font-weight="bold">tx + firma</text>
    <text x="425" y="92" font-size="11">la firma cubre TODO el contenido</text>
    <line x1="525" y1="75" x2="635" y2="75" stroke="#334155" stroke-width="2" marker-end="url(#fs)"/>
    <text x="580" y="65" font-size="12">cualquiera verifica</text>
    <rect x="640" y="45" width="210" height="60" rx="8" fill="#dcfce7" stroke="#16a34a"/>
    <text x="745" y="72" font-weight="bold">clave pública</text>
    <text x="745" y="92" font-size="11">si alteran un campo, no verifica</text>
    <defs><marker id="fs" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto"><path d="M0,0 L9,3 L0,6" fill="#334155"/></marker></defs>
  </g>
</svg>

- Una tx "de Alice" = una tx **firmada con la clave privada de Alice**. La red no sabe quién es Alice: sabe que la firma verifica.

<div class="key">

**Tu clave privada ES tu identidad.** No hay "recuperar contraseña".
Quien tiene la clave, tiene los fondos. *(Modelo de amenazas — Clase 6.)*

</div>

---

## La transacción: unidad de cambio de estado

Una **transacción** es la instrucción que pide modificar el libro.

```text
tx:
  de:      Alice
  a:       Bob
  monto:   3 monedas
  fee:     0.01           ← se paga por procesarla
  firma:   <firma de Alice>
```

Nada cambia en el libro hasta que una tx **válida y firmada** se incluye en un bloque.

---

## Una tx real en cada blockchain (anticipo)

No hace falta entender cada campo — sólo reconocer la **forma**: <span class="nota">*</span>

```text
Ethereum                              Cardano
─────────────────────────            ─────────────────────────
nonce:     7                         inputs:   [UTXO#a, UTXO#b]   ← qué consume
to:        0xAB...                   outputs:  [8 → Bob, 1.8 → Alice]
value:     3 ETH                     fee:      0.17 ADA
data:      (llamada a función)       validez:  slot < 12345678
gasLimit / maxFeePerGas              firmas:   [vkey de Alice]
firma:     <firma de Alice>
```

Dos cosas para señalar (se retoman en el Segmento 4):

- Ethereum dice **a quién llamar**; Cardano dice **qué consume y qué crea**
- El `nonce` (contador anti-replay por cuenta) en Cardano **no existe**:
  consumir los inputs *ya* hace la tx irrepetible — anti-replay **por diseño**

---

## El bloque: un lote ordenado de tx

<svg viewBox="0 0 880 175" width="700">
  <g font-family="sans-serif" font-size="13" text-anchor="middle">
    <rect x="300" y="20" width="280" height="145" rx="10" fill="#f8fafc" stroke="#334155" stroke-width="2"/>
    <text x="440" y="42" font-weight="bold">Bloque</text>
    <rect x="320" y="55" width="240" height="28" rx="4" fill="#dbeafe" stroke="#2563eb"/>
    <text x="440" y="74">tx 1</text>
    <rect x="320" y="89" width="240" height="28" rx="4" fill="#dbeafe" stroke="#2563eb"/>
    <text x="440" y="108">tx 2</text>
    <rect x="320" y="123" width="240" height="28" rx="4" fill="#dbeafe" stroke="#2563eb"/>
    <text x="440" y="142">tx 3   (en ESTE orden)</text>
  </g>
</svg>

El bloque fija **cuáles** transacciones entran y **en qué orden** — el output del consenso.

---

## Encadenamiento por hash

Cada bloque incluye el **hash** del bloque anterior:

<svg viewBox="0 0 880 150" width="820">
  <g font-family="sans-serif" font-size="12" text-anchor="middle">
    <rect x="30"  y="40" width="240" height="80" rx="8" fill="#f8fafc" stroke="#334155"/>
    <text x="150" y="65" font-weight="bold">Bloque N</text>
    <text x="150" y="90" font-size="11">hash = a1b2c3...</text>
    <line x1="270" y1="80" x2="320" y2="80" stroke="#334155" stroke-width="2" marker-end="url(#ah)"/>
    <rect x="325" y="40" width="240" height="80" rx="8" fill="#f8fafc" stroke="#334155"/>
    <text x="445" y="62" font-weight="bold">Bloque N+1</text>
    <text x="445" y="84" font-size="11">prev = a1b2c3...</text>
    <text x="445" y="104" font-size="11">hash = d4e5f6...</text>
    <line x1="565" y1="80" x2="615" y2="80" stroke="#334155" stroke-width="2" marker-end="url(#ah)"/>
    <rect x="620" y="40" width="240" height="80" rx="8" fill="#f8fafc" stroke="#334155"/>
    <text x="740" y="62" font-weight="bold">Bloque N+2</text>
    <text x="740" y="84" font-size="11">prev = d4e5f6...</text>
    <text x="740" y="104" font-size="11">hash = 778899...</text>
    <defs><marker id="ah" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto"><path d="M0,0 L9,3 L0,6" fill="#334155"/></marker></defs>
  </g>
</svg>

Si alguien cambia una tx vieja → cambia el hash de ese bloque → **se rompe la cadena**
de todos los bloques siguientes. Por eso reescribir el pasado es carísimo.

---

## Fees / gas: el recurso económico

- Procesar una tx **cuesta** (cómputo, almacenamiento)
- Se paga con **fees** (Cardano) / **gas** (Ethereum)
- Sirve para dos cosas:
  - Compensar a quien produce bloques
  - **Evitar el spam** (atacar la red cuesta dinero)

> En Ethereum, cada operación de la EVM tiene un precio en gas — lo veremos en la Clase 2.
> *Cómo se calcula* difiere entre blockchains — lo vemos en el Segmento 5.

---

## Mini-demo — un bloque real en el explorador

Exploradores de bloques: la blockchain, en vivo.
`etherscan.io` · `cardanoscan.io`

Vamos a abrir **los dos bloques del Merge** (15/09/2022) y buscar tres cosas:
las **transacciones**, el **hash**, y el **prev** que los encadena.

```text
Bloque 15537393  ← último bloque Proof of Work
  Hash        0x55b11b91...bb286
  Difficulty  11.055.787.484.078.698

Bloque 15537394  ← primer bloque Proof of Stake
  Parent      0x55b11b91...bb286   ← el hash del anterior. Eso ES la cadena.
  Difficulty  0                    ← el Merge, en un solo número
  Txs         80 · Gas 29.983.006 / 30.000.000  (99,9% lleno)
```

---

## La misma pieza en Cardano: entradas y salidas

Una transacción real, en el explorador:

```text
INPUTS  (2)  misma billetera         OUTPUTS (2)
  20,000000 ADA                       30,000000 ADA  → otra dirección (el pago)
  20,000000 ADA                        9,830099 ADA  → a sí mismo    (el vuelto)
  ─────────────                      ─────────────
  40,000000             =            39,830099    +   0,169901 de fee
```

**Cierra exacta, hasta el último lovelace** — es una regla que el ledger
**verifica**: si no cierra, la tx no entra.

- Quería pagar **30** y tenía dos UTXOs de **20**: ninguno alcanzaba solo
- Cada input dice **de qué transacción viene** — un UTXO no es un saldo
- Los inputs se consumen **enteros** → por eso hay vuelto
- **En ningún lado hay un campo "saldo"**: es la suma de tus UTXOs

> Nada de esto es un diagrama teórico: es un sistema corriendo **ahora mismo**.

---

<!-- _class: lead -->

## La pregunta que vamos a perseguir
## toda la clase

# ¿Dónde vive el estado?

La respuesta es **distinta** en cada blockchain —
y de ahí sale **todo** lo demás.

---

<!-- _class: lead -->

<span class="seg">SEGMENTO 3 · ~15 min</span>

# Consenso, sin perderse

---

## PoW vs PoS, a alto nivel

<svg viewBox="0 0 880 150" width="780">
  <g font-family="sans-serif" font-size="14" text-anchor="middle">
    <rect x="40"  y="30" width="360" height="100" rx="10" fill="#f1f5f9" stroke="#334155"/>
    <text x="220" y="62" font-weight="bold">Proof of Work</text>
    <text x="220" y="90" font-size="13">gastar cómputo (energía)</text>
    <text x="220" y="112" font-size="13">para ganar el derecho a proponer</text>
    <rect x="480" y="30" width="360" height="100" rx="10" fill="#dcfce7" stroke="#16a34a"/>
    <text x="660" y="62" font-weight="bold">Proof of Stake</text>
    <text x="660" y="90" font-size="13">poner capital en juego (stake)</text>
    <text x="660" y="112" font-size="13">si hacés trampa, lo perdés</text>
  </g>
</svg>

Ambos resuelven lo mismo: **quién** propone el próximo bloque, de forma que hacer trampa
sea caro.

---

<!-- _class: lead -->

## Hoy **ambas** blockchains son Proof of Stake

| Ethereum | Cardano |
|---|---|
| PoS desde el **Merge** (2022) | PoS desde el inicio (**Ouroboros**) |

La diferencia entre las dos **no** está en el consenso.
Está en el **modelo de estado** (lo que viene ahora).

---

## Cadencia y finalidad (para que los números no floten)

| | Ethereum | Cardano |
|---|---|---|
| Un bloque cada... | 12 segundos | ~20 segundos (promedio) |
| Finalidad | **Explícita** por checkpoints: a los ~13 min el bloque queda finalizado | **Probabilística**: cada bloque encima hace exponencialmente más improbable revertir |
| ¿Quién decide cuándo confiar? | **El protocolo**: esperás el flag de *finalizado* | **Vos**: elegís cuántos bloques esperar — más monto, más espera |

<div class="key">

Lo que hay que retener: **"apareció en un bloque" ≠ "es final"**.
Recién después de un rato una tx es irreversible. <span class="nota">*</span>

</div>

---

## El orden importa para la seguridad

El consenso decide **qué** tx entran y **en qué orden**. Eso tiene consecuencias:

<svg viewBox="0 0 880 150" width="800">
  <g font-family="sans-serif" font-size="12.5" text-anchor="middle">
    <rect x="20"  y="50" width="200" height="50" rx="8" fill="#dcfce7" stroke="#16a34a"/>
    <text x="120" y="72">ves una orden grande</text>
    <text x="120" y="90" font-size="11">esperando en el mempool</text>
    <line x1="220" y1="75" x2="290" y2="75" stroke="#dc2626" stroke-width="2" marker-end="url(#am)"/>
    <rect x="295" y="50" width="240" height="50" rx="8" fill="#fee2e2" stroke="#dc2626"/>
    <text x="415" y="72">metés la tuya ANTES</text>
    <text x="415" y="90" font-size="11">pagando más fee</text>
    <line x1="535" y1="75" x2="605" y2="75" stroke="#dc2626" stroke-width="2" marker-end="url(#am)"/>
    <rect x="610" y="50" width="250" height="50" rx="8" fill="#fee2e2" stroke="#dc2626"/>
    <text x="735" y="72">te beneficiás del movimiento</text>
    <text x="735" y="90" font-size="11">front-running / MEV</text>
    <defs><marker id="am" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto"><path d="M0,0 L9,3 L0,6" fill="#dc2626"/></marker></defs>
  </g>
</svg>

Lo retomamos en la **Clase 6** (modelo de amenazas).

---

<!-- _class: lead -->

<span class="seg">SEGMENTO 4 · ~50 min · EL NÚCLEO</span>

# Modelo de cuentas
# vs EUTXO

---

## La idea: dibujar el estado antes y después

La **misma** operación —cambiar quién tiene qué— se modela de forma
**radicalmente distinta** en cada blockchain.

Vamos a ver, en cada modelo:

1. **Dónde** vive el estado
2. **Qué hace** una transacción con él
3. **Quién valida** y con qué información

> Estas tres preguntas ordenan **el resto del curso**: cada bug que veamos va a ser
> consecuencia de cómo las responde cada modelo.

---

## Ethereum: dos tipos de cuenta

La distinción reaparece en **cada** clase de Ethereum:

| | EOA (externally owned account) | Cuenta-contrato |
|---|---|---|
| Controlada por | Un par de claves (persona/wallet) | **Su propio código** |
| Tiene código | No | Sí (inmutable una vez deployado) |
| Tiene storage | No | Sí (estado mutable persistente) |
| Puede iniciar una tx | **Sí** — toda tx nace en una EOA | No (sólo reacciona a llamadas) |
| Tiene balance de ETH | Sí | Sí |

<div class="key">

Un contrato es **una cuenta con código y storage**.

</div>

---

## Ethereum: modelo de cuentas

Cuentas con **balance**, y si son contratos, con **storage** (estado mutable
persistente) y **código**.

```solidity
contract Banco {
    mapping(address => uint256) balances;   // ← el estado, mutable

    function depositar() public payable {
        balances[msg.sender] += msg.value;  // muta el estado global
    }
}
```

Una tx **llama a una función** que **muta el estado global compartido**.

---

## Ethereum: el estado antes y después

<svg viewBox="0 0 880 225" width="800">
  <g font-family="sans-serif" font-size="13" text-anchor="middle">
    <text x="160" y="25" font-size="14" font-weight="bold">Antes</text>
    <rect x="40" y="35" width="240" height="160" rx="10" fill="#dbeafe" stroke="#2563eb"/>
    <text x="160" y="62">Contrato (cuenta)</text>
    <rect x="60" y="80" width="200" height="44" rx="4" fill="#fff" stroke="#2563eb"/>
    <text x="160" y="107" font-family="monospace">balances[Alice] = 5</text>
    <rect x="60" y="134" width="200" height="44" rx="4" fill="#fff" stroke="#2563eb"/>
    <text x="160" y="161" font-family="monospace">código</text>
    <line x1="285" y1="115" x2="395" y2="115" stroke="#dc2626" stroke-width="2.5" marker-end="url(#ab)"/>
    <text x="340" y="105" font-size="13" fill="#dc2626">depositar(3)</text>
    <text x="340" y="133" font-size="11" fill="#dc2626">muta storage</text>
    <text x="520" y="25" font-size="14" font-weight="bold">Después</text>
    <rect x="400" y="35" width="240" height="160" rx="10" fill="#dbeafe" stroke="#2563eb"/>
    <text x="520" y="62">Contrato (cuenta)</text>
    <rect x="420" y="80" width="200" height="44" rx="4" fill="#fff" stroke="#16a34a" stroke-width="2"/>
    <text x="520" y="107" font-family="monospace" fill="#16a34a">balances[Alice] = 8</text>
    <rect x="420" y="134" width="200" height="44" rx="4" fill="#fff" stroke="#2563eb"/>
    <text x="520" y="161" font-family="monospace">código</text>
    <text x="765" y="105" font-size="13">mismo objeto,</text>
    <text x="765" y="127" font-size="13">estado mutado</text>
    <defs><marker id="ab" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto"><path d="M0,0 L9,3 L0,6" fill="#dc2626"/></marker></defs>
  </g>
</svg>

El contrato es **persistente**: vive en la blockchain y su storage cambia con cada tx.

---

## Ethereum: consecuencias del modelo

Ejecución **secuencial** sobre **estado común y mutable**:

- El storage **persiste** entre transacciones
- Una función puede **llamar a otro contrato** en el medio de su ejecución
- Ese contrato puede **volver a llamar** (re-entrar) antes de que la primera termine
- El **orden** de las tx puede cambiar el resultado

<div class="key">

→ De acá nacen **reentrancy**, condiciones de **carrera**, y dependencia del **orden** (MEV).

</div>

---

## Cardano, paso 1 — UTXO "a secas" (el modelo de Bitcoin)

Construimos EUTXO en dos pasos, porque la "E" sólo se aprecia contra el modelo base.

- **No hay cuentas ni balances** como dato primario: hay **outputs no gastados** (UTXOs),
  cada uno con un valor y una **condición de gasto** (típicamente: "firma de tal clave")
- "Tu balance" es un concepto **derivado**: la suma de los UTXOs que podés gastar
- Una tx **consume inputs enteros** y **crea outputs nuevos**

> Vocabulario: "output" e "input" son **el mismo UTXO en dos momentos de su vida** —
> nace como output de una tx, flota como "no gastado", muere como input de otra.
> *(Se desarrolla a fondo en la Clase 4.)*

---

## Cardano: consumir y crear

El estado vive en los **outputs no gastados** (UTXOs). No hay un "objeto contrato"
que se mute: una tx **consume inputs** y **crea outputs**.

<svg viewBox="0 0 880 215" width="800">
  <g font-family="sans-serif" font-size="13" text-anchor="middle">
    <text x="110" y="22" font-size="13" font-weight="bold">Inputs (se consumen)</text>
    <rect x="40" y="35" width="150" height="52" rx="8" fill="#dcfce7" stroke="#16a34a"/>
    <text x="115" y="57">UTXO #1</text>
    <text x="115" y="76" font-size="11">5 ADA · de Alice</text>
    <rect x="40" y="103" width="150" height="52" rx="8" fill="#dcfce7" stroke="#16a34a"/>
    <text x="115" y="125">UTXO #2</text>
    <text x="115" y="144" font-size="11">3 ADA · de Alice</text>
    <rect x="330" y="50" width="180" height="105" rx="10" fill="#f8fafc" stroke="#334155" stroke-width="2"/>
    <text x="420" y="98" font-weight="bold">Transacción</text>
    <text x="420" y="120" font-size="11">consume / crea</text>
    <line x1="190" y1="61"  x2="330" y2="90"  stroke="#334155" stroke-width="2" marker-end="url(#ai)"/>
    <line x1="190" y1="129" x2="330" y2="118" stroke="#334155" stroke-width="2" marker-end="url(#ai)"/>
    <text x="700" y="22" font-size="13" font-weight="bold">Outputs (se crean)</text>
    <line x1="510" y1="90"  x2="640" y2="61"  stroke="#16a34a" stroke-width="2" marker-end="url(#ig)"/>
    <line x1="510" y1="118" x2="640" y2="129" stroke="#16a34a" stroke-width="2" marker-end="url(#ig)"/>
    <rect x="640" y="35" width="150" height="52" rx="8" fill="#dcfce7" stroke="#16a34a"/>
    <text x="715" y="57">UTXO #3</text>
    <text x="715" y="76" font-size="11">6 ADA → Bob</text>
    <rect x="640" y="103" width="150" height="52" rx="8" fill="#dcfce7" stroke="#16a34a"/>
    <text x="715" y="125">UTXO #4</text>
    <text x="715" y="144" font-size="11">2 ADA → Alice (cambio)</text>
    <defs>
      <marker id="ai" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto"><path d="M0,0 L9,3 L0,6" fill="#334155"/></marker>
      <marker id="ig" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto"><path d="M0,0 L9,3 L0,6" fill="#16a34a"/></marker>
    </defs>
  </g>
</svg>

5 + 3 entran, 6 + 2 salen. Los UTXOs viejos **dejan de existir**; nacen otros.
No se muta: **se reemplaza**. *(En la práctica una parte se va en fee.)*

---

## Cardano, paso 2 — la "E" de Extended

El UTXO de Bitcoin sólo exige condiciones muy simples.
Cardano lo **extiende en tres direcciones** — y eso habilita los smart contracts:

| | UTXO (Bitcoin) | EUTXO (Cardano) |
|---|---|---|
| Condición de gasto | Script simple (casi siempre: una firma) | **Validator**: lógica arbitraria |
| Estado pegado al output | No | **Datum** (dato arbitrario adjunto) |
| Qué ve la condición al validar | Casi nada | **El contexto completo de la tx** (inputs, outputs, firmas, rango de validez) |

<div class="key">

EUTXO = UTXO + **datum** + **validator arbitrario** + **visión de toda la tx**.

</div>

---

## Cardano: el validator decide sí/no

Para gastar un output **protegido por un script**, un **validator** responde `True`/`False`
a partir de tres entradas:

<svg viewBox="0 0 880 200" width="780">
  <g font-family="sans-serif" font-size="13" text-anchor="middle">
    <rect x="20"  y="25" width="200" height="40" rx="6" fill="#dcfce7" stroke="#16a34a"/>
    <text x="120" y="50" font-size="12">datum — dato pegado al output</text>
    <rect x="20"  y="80" width="200" height="40" rx="6" fill="#dbeafe" stroke="#2563eb"/>
    <text x="120" y="105" font-size="12">redeemer — arg. de quien gasta</text>
    <rect x="20"  y="135" width="200" height="40" rx="6" fill="#fef9c3" stroke="#ca8a04"/>
    <text x="120" y="160" font-size="12">contexto de la tx</text>
    <line x1="220" y1="45"  x2="350" y2="90" stroke="#334155" stroke-width="2" marker-end="url(#iv)"/>
    <line x1="220" y1="100" x2="350" y2="100" stroke="#334155" stroke-width="2" marker-end="url(#iv)"/>
    <line x1="220" y1="155" x2="350" y2="110" stroke="#334155" stroke-width="2" marker-end="url(#iv)"/>
    <rect x="355" y="70" width="170" height="60" rx="10" fill="#1e293b"/>
    <text x="440" y="98" fill="#fff" font-weight="bold">validator</text>
    <text x="440" y="118" fill="#cbd5e1" font-size="11">función pura</text>
    <line x1="525" y1="100" x2="615" y2="100" stroke="#334155" stroke-width="2" marker-end="url(#iv)"/>
    <rect x="620" y="58" width="220" height="38" rx="8" fill="#dcfce7" stroke="#16a34a"/>
    <text x="730" y="82" fill="#16a34a" font-weight="bold">True → se gasta</text>
    <rect x="620" y="104" width="220" height="38" rx="8" fill="#fee2e2" stroke="#dc2626"/>
    <text x="730" y="128" fill="#dc2626" font-weight="bold">False → la tx falla entera</text>
    <defs><marker id="iv" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto"><path d="M0,0 L9,3 L0,6" fill="#334155"/></marker></defs>
  </g>
</svg>

Ejemplo de condición: *"apruebo sólo si la tx está firmada por el dueño guardado en el datum"*.

Punto fino: el validator **no decide a dónde van los fondos** — sólo aprueba o veta que *ese*
input se gaste en *esa* tx. Qué hace la tx con los fondos es responsabilidad de quien la armó
*(se retoma en las Clases 8 y 9)*.

---

## Cardano: validación local y determinista

El validator es una **función pura** que sólo mira **esa** transacción.

<div class="key">

Dada la misma tx, el validator **siempre devuelve lo mismo** → el veredicto y el
costo se pueden calcular **antes** de enviarla.

</div>

Contraste con Ethereum: ahí la tx se ejecuta contra el **estado global del momento**,
que pudo cambiar entre que la armaste y que se incluyó → puede revertir inesperadamente.

> ⚠️ **Determinismo no es garantía de que la tx entre.** Puede ser rechazada igual si
> **otro gastó tu UTXO primero** o si llega **fuera de su `validity_range`**. Lo predecible
> es el **veredicto del script**, no la aceptación de la transacción. <span class="nota">*</span>

---

## Cardano: concurrencia y anti-replay

**Concurrencia explícita:**

<svg viewBox="0 0 880 165" width="800">
  <g font-family="sans-serif" font-size="13" text-anchor="middle">
    <rect x="30" y="25" width="390" height="55" rx="8" fill="#dcfce7" stroke="#16a34a"/>
    <text x="225" y="49">tx A consume UTXO#1 · tx B consume UTXO#2</text>
    <text x="225" y="68" font-size="12" fill="#16a34a">no interfieren en absoluto → paralelas</text>
    <rect x="460" y="25" width="390" height="55" rx="8" fill="#fee2e2" stroke="#dc2626"/>
    <text x="655" y="49">tx A y tx B quieren el MISMO UTXO</text>
    <text x="655" y="68" font-size="12" fill="#dc2626">sólo una entra; la otra falla → contención</text>
    <rect x="130" y="100" width="620" height="50" rx="8" fill="#fef9c3" stroke="#ca8a04"/>
    <text x="440" y="122" font-size="13">un dapp con "todo el estado en un solo UTXO" se serializa</text>
    <text x="440" y="140" font-size="12">→ el diseño EUTXO reparte el estado (se sufre en la Clase 5)</text>
  </g>
</svg>

**Anti-replay estructural:** los inputs consumidos ya no existen → la misma tx
no puede aplicarse dos veces. **No hace falta nonce.**

---

## Los dos modelos, lado a lado

| | Ethereum (cuentas) | Cardano (EUTXO) |
|---|---|---|
| ¿Dónde vive el estado? | Storage global, **mutable** | En los **UTXOs** (se consumen/crean) |
| Rol del contrato | Código que **muta** estado | Validator: **aprueba/rechaza** gastar |
| Entradas a la lógica | Llamada + estado actual | Datum + redeemer + contexto |
| Ejecución | Secuencial, compartida | **Local, determinista** |
| Conocer el resultado | Recién al ejecutar on-chain | **Antes** de enviar |
| Concurrencia | Orden global obligatorio | **Paralela** si no comparten UTXOs |
| Anti-replay | Nonce por cuenta | Consumo de inputs (**estructural**) |
| Lógica off-chain | Mínima | **Mucha** |
| Bugs típicos | Reentrancy, control de acceso | Double satisfaction, validación de outputs |

---

## Anticipo: dos catálogos de bugs

Columna vertebral de la segunda mitad del curso — **vuelve completa en las Clases 6 y 8**.
Hoy alcanza con que suenen los nombres; no hay que entender cada fila todavía: <span class="nota">*</span>

| Ethereum (cuentas) | Cardano (EUTXO) |
|---|---|
| Reentrancy | Double satisfaction |
| Control de acceso | Validación de outputs insuficiente (destino/monto) |
| Overflow en `unchecked` / casts | Datum no autorizado / no validado |
| `delegatecall` / proxies | Dust / min-ADA |
| Front-running / MEV | Seguridad de minting policies |
| Oráculos, DoS por gas | Asunciones sobre el contexto de la tx |

---

## Los bugs no se traducen entre modelos

<svg viewBox="0 0 880 130" width="820">
  <g font-family="sans-serif" font-size="15" text-anchor="middle">
    <rect x="30"  y="25" width="380" height="90" rx="10" fill="#dbeafe" stroke="#2563eb"/>
    <text x="220" y="58" font-weight="bold" fill="#1e3a8a">Reentrancy</text>
    <text x="220" y="84" font-size="13">casi un no-concepto en EUTXO</text>
    <text x="220" y="104" font-size="11">(no hay estado mutable que re-entrar)</text>
    <rect x="470" y="25" width="380" height="90" rx="10" fill="#dcfce7" stroke="#16a34a"/>
    <text x="660" y="58" font-weight="bold" fill="#14532d">Double satisfaction</text>
    <text x="660" y="84" font-size="13">ni siquiera existe en Ethereum</text>
    <text x="660" y="104" font-size="11">(nace de componer varios inputs)</text>
  </g>
</svg>

**Distinta arquitectura → distinto catálogo de bugs.**
*(Se profundiza en Clases 6–7 para Ethereum y 8–9 para Cardano.)*

---

<!-- _class: lead -->

<span class="seg">SEGMENTO 5 · ~20 min</span>

# ¿Dónde corre el código?

---

## Dos pipelines de compilación

<svg viewBox="0 0 880 200" width="820">
  <g font-family="sans-serif" font-size="13" text-anchor="middle">
    <rect x="30"  y="35" width="150" height="50" rx="8" fill="#dbeafe" stroke="#2563eb"/>
    <text x="105" y="65">Solidity</text>
    <line x1="180" y1="60" x2="240" y2="60" stroke="#334155" stroke-width="2" marker-end="url(#ic)"/>
    <rect x="245" y="35" width="150" height="50" rx="8" fill="#e0e7ff" stroke="#4338ca"/>
    <text x="320" y="65">bytecode</text>
    <line x1="395" y1="60" x2="455" y2="60" stroke="#334155" stroke-width="2" marker-end="url(#ic)"/>
    <rect x="460" y="35" width="150" height="50" rx="8" fill="#1e293b"/>
    <text x="535" y="65" fill="#fff">EVM</text>
    <rect x="30"  y="125" width="150" height="50" rx="8" fill="#dcfce7" stroke="#16a34a"/>
    <text x="105" y="155">Aiken / Plinth</text>
    <line x1="180" y1="150" x2="240" y2="150" stroke="#334155" stroke-width="2" marker-end="url(#ic)"/>
    <rect x="245" y="125" width="150" height="50" rx="8" fill="#bbf7d0" stroke="#15803d"/>
    <text x="320" y="155">UPLC</text>
    <line x1="395" y1="150" x2="455" y2="150" stroke="#334155" stroke-width="2" marker-end="url(#ic)"/>
    <rect x="460" y="125" width="150" height="50" rx="8" fill="#14532d"/>
    <text x="535" y="155" fill="#fff">nodo Cardano</text>
    <text x="730" y="56" font-size="12">cada llamada</text>
    <text x="730" y="74" font-size="12">muta estado</text>
    <text x="730" y="146" font-size="12">sólo dice</text>
    <text x="730" y="164" font-size="12">sí / no</text>
    <defs><marker id="ic" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto"><path d="M0,0 L9,3 L0,6" fill="#334155"/></marker></defs>
  </g>
</svg>

**UPLC** = Untyped Plutus Core, el "assembly" que ejecutan los nodos de Cardano.
Aiken y Plinth (ex-PlutusTx, Haskell) compilan **al mismo objetivo** — cambia la
ergonomía, no el destino *(Clase 4)*.

---

## Qué significa "deployar"

| | Ethereum | Cardano |
|---|---|---|
| El código... | Se sube a la blockchain y **vive** en una cuenta-contrato con su dirección | Se **referencia por hash**: la dirección del script se deriva del hash del validator |
| Las tx... | Le "hablan" a esa dirección | Mandan fondos a la dirección; el código se aporta **al gastar** (en la tx, o publicado antes como *reference script*) |

<div class="key">

Otra cara de la misma idea: **no hay objeto contrato — hay outputs protegidos.**

</div>

---

## Cómo se cobra el cómputo

Consecuencia directa del modelo (cierra el círculo del Segmento 2):

| | Ethereum (gas) | Cardano (ExUnits) |
|---|---|---|
| Unidad | Gas por opcode ejecutado | Memoria + pasos de CPU |
| ¿Cuándo se conoce el costo? | Recién al ejecutar (depende del estado global) | **Antes de enviar** (ejecución determinista) |
| ¿Puede fallar on-chain y cobrar igual? | **Sí**: una tx que revierte paga el gas consumido | El validator se corre localmente primero; una wallet honesta no envía tx que fallan |

---

## La asimetría on-chain / off-chain

<svg viewBox="0 0 880 150" width="800">
  <g font-family="sans-serif" font-size="13" text-anchor="middle">
    <text x="220" y="25" font-size="15" font-weight="bold" fill="#1e3a8a">Ethereum</text>
    <rect x="40" y="35" width="360" height="40" rx="6" fill="#dbeafe" stroke="#2563eb"/>
    <text x="220" y="60">on-chain: casi toda la lógica</text>
    <rect x="40" y="85" width="120" height="32" rx="6" fill="#eff6ff" stroke="#93c5fd"/>
    <text x="100" y="106" font-size="12">off-chain: poco</text>
    <text x="660" y="25" font-size="15" font-weight="bold" fill="#14532d">Cardano</text>
    <rect x="480" y="35" width="160" height="40" rx="6" fill="#dcfce7" stroke="#16a34a"/>
    <text x="560" y="60" font-size="12">on-chain: sí/no</text>
    <rect x="480" y="85" width="360" height="40" rx="6" fill="#dcfce7" stroke="#16a34a"/>
    <text x="660" y="110">off-chain: armar / balancear la tx</text>
  </g>
</svg>

En Cardano, decidir **qué inputs juntar**, **cómo balancear** y **armar datum/redeemer**
vive **fuera** de la blockchain. El validator on-chain sólo dice **sí o no**.

---

<!-- _class: lead -->

<span class="seg">SEGMENTO 6 · ~25 min</span>

# Actividad
# "Seguí la transacción"

---

## Actividad — en parejas

La **misma** operación, modelada en los dos mundos:
**Alice le transfiere 10 unidades de un token a Bob**
*(el token ya existe; no importa cómo se creó)*

<svg viewBox="0 0 880 130" width="760">
  <g font-family="sans-serif" font-size="14" text-anchor="middle">
    <rect x="40"  y="25" width="360" height="80" rx="10" fill="#dbeafe" stroke="#2563eb"/>
    <text x="220" y="55" font-weight="bold">Mitad: Ethereum</text>
    <text x="220" y="82" font-size="12">estado antes/después · quién valida</text>
    <rect x="480" y="25" width="360" height="80" rx="10" fill="#dcfce7" stroke="#16a34a"/>
    <text x="660" y="55" font-weight="bold">Mitad: Cardano</text>
    <text x="660" y="82" font-size="12">inputs/outputs · quién valida</text>
  </g>
</svg>

Cada pareja entrega, en papel o pizarra:

1. **El estado ANTES** — cuentas/storage (Ethereum) · UTXOs existentes (Cardano)
2. **La transacción** — ¿a quién llama? / ¿qué consume y qué crea? · quién firma
3. **El estado DESPUÉS**
4. **¿Quién valida y con qué información?** ← la pregunta central

Después se **cruzan y comparan**.

> Al terminar tendrían que poder explicar la diferencia **sin decir la palabra
> "blockchain"** — sólo hablando de estado, transacciones y validación.

---

## Lo que tiene que salir de la actividad

- En **Ethereum**: una llamada a una función muta un `mapping` de balances;
  valida **el código del contrato** contra el estado actual.
- En **Cardano**: la tx consume el UTXO con el token y crea uno nuevo para el destinatario;
  valida **el validator** con datum + redeemer + contexto.

<div class="key">

Misma intención, **dos máquinas distintas** — y por eso, dos formas de fallar.

</div>

---

## Errores esperables (dejarlos aparecer y usarlos)

**Lado Cardano — olvidar el cambio:**

Si Alice tiene un UTXO con **25** tokens y manda **10**, los otros **15** tienen que
salir en un output de vuelta a ella — los inputs se consumen **enteros**.

**Lado Ethereum — dibujar "monedas que viajan":**

En cuentas **no viaja nada**: se editan dos números de un `mapping`.

```text
balances[Alice]: 25 → 15
balances[Bob]:    0 → 10
```

---

## Lo que se ve más adelante

| Hoy apareció... | Vuelve en... |
|---|---|
| El **`mapping` de balances** como estado mutable | **Clase 2** — cómo se escribe en Solidity, dónde vive el dato y qué cuesta cada operación |
| El diagrama EUTXO y **datum / redeemer / contexto** | **Clase 4** — se retoman tal cual |
| La tabla de los **dos catálogos de bugs** | **Clases 6 y 8** — índice del bloque de análisis |
| Reentrancy ↔ double satisfaction | **Clases 7 y 9** — se demuestran con código |
| Front-running / MEV · oráculos | **Clase 6** — modelo de amenazas |

---

<!-- _class: lead -->

## Lecturas

- *Mastering Ethereum*, **2ª ed. (2025)** — **caps. 1–2** (cuentas) y **14** (EVM)
  *(actualizada post-Merge; gratis online y en `ethereumbook`)*
- *Mastering Cardano* — **cap. 4** (*How Cardano works*): EUTXO
- Cardano Developer Portal — página de EUTXO
- Opcional para curiosos: el paper *The Extended UTXO Model* (Chakravarty et al.)
  — formaliza la "E"; con la introducción alcanza

---

<!-- _class: lead -->
<!-- _paginate: false -->

# Próxima clase

## Clase 2 — Intro a Solidity

Leer y escribir un contrato; tipos y data location, visibilidad,
errores, eventos, y el ciclo deploy → call (en Remix).
