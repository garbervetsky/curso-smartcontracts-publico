---
marp: true
theme: default
paginate: true
header: 'Smart Contracts — Clase 2'
footer: 'Intro a Solidity'
style: |
  section { font-size: 24px; }
  section.lead { justify-content: center; text-align: center; }
  section.lead h1 { font-size: 52px; }
  section.lead h2 { font-size: 34px; color: #475569; }
  table { font-size: 20px; }
  th { background: #f1f5f9; }
  svg { display: block; margin: 0.3em auto; }
  pre { font-size: 17px; }
  .key { background: #fef9c3; border-left: 6px solid #ca8a04; padding: 0.3em 0.7em; }
  .seg { color: #64748b; font-size: 20px; letter-spacing: 2px; }
  .nota { color: #b45309; font-weight: 700; }
  section.small { font-size: 19px; }
  section.small table { font-size: 16px; }
  section.small pre { font-size: 14px; }
---

<!-- _class: lead -->
<!-- _paginate: false -->

# Clase 2
## Intro a Solidity
### Leer y escribir un contrato

---

## Leer y escribir un contrato Solidity simple

Leer y escribir un contrato Solidity simple:

- tipos y **data location**
- **visibilidad** y **mutabilidad** de funciones
- manejo de **errores** y **eventos**
- el ciclo **deploy → call**

---

## Objetivos de aprendizaje

Al terminar, vas a poder:

- Leer un contrato y decir **qué hace cada parte**
- Distinguir `storage` / `memory` / `calldata` y **por qué importa** (estado y gas)
- Elegir la **visibilidad** correcta de una función
- Usar `require` / `revert` / **custom errors**
- Emitir y entender **eventos**
- **Desplegar y llamar** un contrato en Remix

---

<!-- _class: lead -->

<span class="seg">SEGMENTO 1</span>

# Contexto EVM

---

## Un contrato es una cuenta con código


<svg viewBox="0 0 880 175" width="760">
  <g font-family="sans-serif" font-size="14" text-anchor="middle">
    <rect x="280" y="20" width="320" height="140" rx="12" fill="#dbeafe" stroke="#2563eb" stroke-width="2"/>
    <text x="440" y="48" font-weight="bold">Contrato = cuenta</text>
    <rect x="305" y="62" width="270" height="40" rx="6" fill="#fff" stroke="#2563eb"/>
    <text x="440" y="87">storage (estado persistente)</text>
    <rect x="305" y="110" width="270" height="40" rx="6" fill="#fff" stroke="#2563eb"/>
    <text x="440" y="135">código (funciones)</text>
    <text x="120" y="85" font-size="12" fill="#dc2626">cada llamada</text>
    <text x="120" y="103" font-size="12" fill="#dc2626">que escribe = tx</text>
    <line x1="200" y1="95" x2="278" y2="95" stroke="#dc2626" stroke-width="2" marker-end="url(#a)"/>
    <text x="760" y="95" font-size="12">y cuesta gas</text>
    <defs><marker id="a" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto"><path d="M0,0 L9,3 L0,6" fill="#dc2626"/></marker></defs>
  </g>
</svg>

Solidity → **bytecode** → lo ejecuta la **EVM**.

---

## ¿De dónde sale una dirección?

<svg viewBox="0 0 880 250" width="840">
  <g font-family="sans-serif" font-size="12.5" text-anchor="middle">
    <text x="60" y="26" font-size="13" font-weight="bold" fill="#166534">EOA (persona)</text>
    <rect x="14" y="40" width="150" height="52" rx="8" fill="#fee2e2" stroke="#dc2626" stroke-width="2"/>
    <text x="89" y="61" font-weight="bold">clave privada</text>
    <text x="89" y="79" font-size="10.5">32 bytes al azar</text>
    <line x1="164" y1="66" x2="204" y2="66" stroke="#334155" stroke-width="2" marker-end="url(#dr)"/>
    <text x="184" y="57" font-size="9.5" fill="#64748b">curva</text>
    <rect x="208" y="40" width="150" height="52" rx="8" fill="#dcfce7" stroke="#16a34a" stroke-width="2"/>
    <text x="283" y="61" font-weight="bold">clave pública</text>
    <text x="283" y="79" font-size="10.5">64 bytes</text>
    <line x1="358" y1="66" x2="398" y2="66" stroke="#334155" stroke-width="2" marker-end="url(#dr)"/>
    <rect x="402" y="40" width="150" height="52" rx="8" fill="#f1f5f9" stroke="#475569" stroke-width="2"/>
    <text x="477" y="61" font-weight="bold">keccak256</text>
    <text x="477" y="79" font-size="10.5">32 bytes</text>
    <line x1="552" y1="66" x2="592" y2="66" stroke="#334155" stroke-width="2" marker-end="url(#dr)"/>
    <text x="572" y="57" font-size="9.5" fill="#64748b">últimos 20</text>
    <rect x="596" y="40" width="248" height="52" rx="8" fill="#dbeafe" stroke="#2563eb" stroke-width="2.5"/>
    <text x="720" y="61" font-weight="bold">la dirección</text>
    <text x="720" y="79" font-size="11" font-family="monospace">0x5B38…eddC4</text>
    <text x="440" y="118" font-size="11.5" fill="#dc2626">sólo va para un lado: de la dirección NO se vuelve a la clave</text>
    <line x1="14" y1="140" x2="844" y2="140" stroke="#cbd5e1" stroke-width="1.5"/>
    <text x="70" y="170" font-size="13" font-weight="bold" fill="#1e40af">Contrato</text>
    <rect x="14" y="184" width="344" height="52" rx="8" fill="#e0e7ff" stroke="#4338ca" stroke-width="2"/>
    <text x="186" y="205" font-weight="bold">keccak256( quién despliega + nonce )</text>
    <text x="186" y="223" font-size="10.5">no hay ninguna clave de por medio</text>
    <line x1="358" y1="210" x2="398" y2="210" stroke="#334155" stroke-width="2" marker-end="url(#dr)"/>
    <text x="378" y="201" font-size="9.5" fill="#64748b">últimos 20</text>
    <rect x="402" y="184" width="200" height="52" rx="8" fill="#dbeafe" stroke="#2563eb" stroke-width="2.5"/>
    <text x="502" y="205" font-weight="bold">la dirección</text>
    <text x="502" y="223" font-size="10.5">predecible antes de desplegar</text>
    <text x="726" y="200" font-size="11.5" font-weight="bold" fill="#dc2626">sin clave privada</text>
    <text x="726" y="220" font-size="11.5" fill="#dc2626">→ no puede firmar</text>
    <defs><marker id="dr" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto"><path d="M0,0 L9,3 L0,6" fill="#334155"/></marker></defs>
  </g>
</svg>

<div class="key">

Un contrato **no puede iniciar una transacción**: no tiene con qué firmarla.
En el origen de toda cadena de llamadas hay **siempre una persona**. <span class="nota">*</span>

</div>

---

## Como un objeto — pero que cuesta dinero y persiste

> Un contrato es como un **objeto** con campos persistentes (storage) y métodos
> (funciones)...
>
> ...pero cada método que **escribe** estado **cuesta dinero** y **queda registrado**
> en la blockchain.

Esa diferencia con un objeto común —el costo y la permanencia— condiciona **cómo** se
escribe el código.

---

## La EVM: máquina de pila de 256 bits

La palabra nativa de la EVM es de **256 bits** → por eso `uint256` es el tipo
"por defecto" de todo el ecosistema.

<div class="key">

Usar `uint8` **no ahorra gas** por sí solo — la EVM opera palabras completas.
Ahorra sólo cuando el compilador puede **empaquetar** varios campos chicos
en un mismo slot de storage.

</div>

Y no hay punto flotante: **todos los montos son enteros** (en wei). Es deliberado —
determinismo primero.

---

## Las piezas de la EVM

<svg viewBox="0 0 880 375" width="820">
  <g font-family="sans-serif" font-size="12.5" text-anchor="middle">
    <rect x="6" y="78" width="66" height="50" rx="8" fill="#f1f5f9" stroke="#334155" stroke-width="2"/>
    <text x="39" y="100" font-weight="bold">la tx</text>
    <text x="39" y="118" font-size="10.5" fill="#64748b">de Alice</text>
    <line x1="72" y1="103" x2="100" y2="103" stroke="#334155" stroke-width="2" marker-end="url(#ev)"/>
    <rect x="104" y="14" width="712" height="178" rx="12" fill="none" stroke="#94a3b8" stroke-width="2" stroke-dasharray="7 5"/>
    <rect x="124" y="78" width="196" height="50" rx="8" fill="#dcfce7" stroke="#16a34a" stroke-width="2"/>
    <text x="222" y="99" font-weight="bold">calldata</text>
    <text x="222" y="117" font-size="10.5">los argumentos · sólo lectura</text>
    <line x1="320" y1="103" x2="356" y2="103" stroke="#334155" stroke-width="2" marker-end="url(#ev)"/>
    <rect x="360" y="46" width="152" height="132" rx="8" fill="#1e293b"/>
    <text x="436" y="72" fill="#fff" font-weight="bold" font-size="14">STACK</text>
    <text x="436" y="91" fill="#cbd5e1" font-size="10.5">acá se computa TODO</text>
    <rect x="378" y="102" width="116" height="17" rx="3" fill="#475569"/>
    <rect x="378" y="123" width="116" height="17" rx="3" fill="#475569"/>
    <rect x="378" y="144" width="116" height="17" rx="3" fill="#475569"/>
    <text x="436" y="172" fill="#94a3b8" font-size="10">1024 × 256 bits</text>
    <line x1="512" y1="88" x2="552" y2="88" stroke="#334155" stroke-width="2" marker-end="url(#ev)"/>
    <line x1="552" y1="110" x2="512" y2="110" stroke="#334155" stroke-width="2" marker-end="url(#ev)"/>
    <rect x="556" y="46" width="244" height="62" rx="8" fill="#fef9c3" stroke="#ca8a04" stroke-width="2"/>
    <text x="678" y="68" font-weight="bold">memory</text>
    <text x="678" y="88" font-size="10.5">borrador de trabajo · se borra al terminar</text>
    <rect x="556" y="122" width="244" height="56" rx="8" fill="#fff" stroke="#94a3b8" stroke-width="2"/>
    <text x="678" y="143" font-weight="bold" font-size="12">gas</text>
    <text x="678" y="163" font-size="10.5">baja con cada opcode</text>
    <line x1="300" y1="288" x2="300" y2="194" stroke="#475569" stroke-width="2.5" marker-end="url(#ev)"/>
    <text x="212" y="228" font-size="10.5" fill="#475569">se carga</text>
    <text x="212" y="244" font-size="10.5" fill="#475569">y se ejecuta</text>
    <line x1="600" y1="288" x2="600" y2="194" stroke="#dc2626" stroke-width="2.5" marker-end="url(#evr)"/>
    <line x1="628" y1="194" x2="628" y2="288" stroke="#dc2626" stroke-width="2.5" marker-end="url(#evr)"/>
    <text x="700" y="228" font-size="10.5" fill="#dc2626">SLOAD / SSTORE</text>
    <text x="700" y="244" font-size="10.5" fill="#dc2626">lo más caro que hay</text>
    <rect x="150" y="290" width="620" height="78" rx="12" fill="#f8fafc" stroke="#0f172a" stroke-width="2.5"/>
    <text x="460" y="311" font-size="12.5" font-weight="bold" fill="#0f172a">La cuenta del contrato · vive on-chain, persiste</text>
    <rect x="172" y="320" width="270" height="38" rx="6" fill="#e2e8f0" stroke="#475569" stroke-width="2"/>
    <text x="307" y="336" font-weight="bold" font-size="12">código (bytecode)</text>
    <text x="307" y="351" font-size="10.5">se escribe UNA vez, al deployar</text>
    <rect x="478" y="320" width="270" height="38" rx="6" fill="#fee2e2" stroke="#dc2626" stroke-width="2"/>
    <text x="613" y="336" font-weight="bold" font-size="12">storage (el estado)</text>
    <text x="613" y="351" font-size="10.5">se reescribe en CADA transacción</text>
    <defs>
      <marker id="ev" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto"><path d="M0,0 L9,3 L0,6" fill="#475569"/></marker>
      <marker id="evr" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto"><path d="M0,0 L9,3 L0,6" fill="#dc2626"/></marker>
    </defs>
  </g>
</svg>

Lo de arriba **existe sólo durante la llamada**. Lo de abajo **persiste**: el código (inmutable) y el storage de la cuenta (mutable). <span class="nota">*</span>

---

## El gas cuenta una historia

Números orientativos — lo que importa es la **proporción**:

| Operación | Gas (aprox.) |
|---|---|
| Suma en la pila (`ADD`) | 3 |
| Leer un slot de storage (`SLOAD`, primera vez) | ~2.100 |
| **Escribir un slot NUEVO de storage (`SSTORE`)** | **~20.000** |
| Sobrescribir un slot existente | ~5.000 |
| Costo base de cualquier tx | 21.000 |

<div class="key">

Escribir estado es **~4 órdenes de magnitud** más caro que computar.
**Diseñar las estructuras de datos = diseñar los costos.**

</div>

---

## Unidades de ETH

Las tres que vas a ver todo el tiempo:

```text
1 ether = 1.000.000.000 gwei = 10^18 wei

msg.value  → siempre en wei
precio del gas → se suele expresar en gwei
```

Todos los montos on-chain son **enteros en wei** — nunca "0.5 ETH" dentro del contrato,
sino `500000000000000000`.

---

<!-- _class: lead -->

<span class="seg">SEGMENTO 2</span>

# Anatomía de un contrato

---

## Las partes mínimas

```solidity
// SPDX-License-Identifier: MIT       ← identificador de licencia
pragma solidity ^0.8.26;              ← versión del compilador

contract Contador {
    uint256 public total;             // variable de estado (storage)
    address public owner;             // quién desplegó

    constructor() {
        owner = msg.sender;           // corre UNA vez, en el deploy
    }

    function incrementar() external {
        total += 1;                   // muta estado → es una tx, cuesta gas
    }
}
```

---

## Qué aporta cada pieza

<svg viewBox="0 0 880 200" width="800">
  <g font-family="sans-serif" font-size="12.5" text-anchor="middle">
    <rect x="20"  y="30" width="195" height="55" rx="8" fill="#f1f5f9" stroke="#334155"/>
    <text x="117" y="53" font-weight="bold">SPDX + pragma</text>
    <text x="117" y="73" font-size="11">licencia y versión</text>
    <rect x="240" y="30" width="195" height="55" rx="8" fill="#dbeafe" stroke="#2563eb"/>
    <text x="337" y="53" font-weight="bold">contract</text>
    <text x="337" y="73" font-size="11">unidad de despliegue</text>
    <rect x="460" y="30" width="195" height="55" rx="8" fill="#dcfce7" stroke="#16a34a"/>
    <text x="557" y="53" font-weight="bold">variables de estado</text>
    <text x="557" y="73" font-size="11">viven en storage</text>
    <rect x="680" y="30" width="180" height="55" rx="8" fill="#fef9c3" stroke="#ca8a04"/>
    <text x="770" y="53" font-weight="bold">constructor</text>
    <text x="770" y="73" font-size="11">corre 1 vez al deploy</text>
    <rect x="240" y="115" width="415" height="55" rx="8" fill="#e0e7ff" stroke="#4338ca"/>
    <text x="447" y="138" font-weight="bold">funciones</text>
    <text x="447" y="158" font-size="11">leen o mutan el estado</text>
  </g>
</svg>

---

## Qué es "deployar"

<svg viewBox="0 0 880 150" width="800">
  <g font-family="sans-serif" font-size="13" text-anchor="middle">
    <rect x="20" y="40" width="220" height="70" rx="8" fill="#f1f5f9" stroke="#334155"/>
    <text x="130" y="68">tx de creación</text>
    <text x="130" y="90" font-size="11" font-family="monospace">to: (vacío) · data: bytecode</text>
    <line x1="240" y1="75" x2="330" y2="75" stroke="#334155" stroke-width="2" marker-end="url(#dp)"/>
    <rect x="335" y="40" width="220" height="70" rx="8" fill="#fef9c3" stroke="#ca8a04"/>
    <text x="445" y="68">constructor corre</text>
    <text x="445" y="90" font-size="11">UNA sola vez</text>
    <line x1="555" y1="75" x2="645" y2="75" stroke="#334155" stroke-width="2" marker-end="url(#dp)"/>
    <rect x="650" y="40" width="210" height="70" rx="8" fill="#dbeafe" stroke="#2563eb"/>
    <text x="755" y="68">cuenta-contrato</text>
    <text x="755" y="90" font-size="11">con dirección propia</text>
    <defs><marker id="dp" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto"><path d="M0,0 L9,3 L0,6" fill="#334155"/></marker></defs>
  </g>
</svg>

<div class="key">

Desde entonces **el código es inmutable** — no hay "subir un fix".
Esta es la razón de ser de todo el bloque de análisis del curso
*(y del ecosistema de proxies — Clase 6)*.

</div>

---

## El getter automático

```solidity
uint256 public total;   // ← `public` genera un getter automático
```

Es equivalente a escribir a mano:

```solidity
uint256 private total;

function total() external view returns (uint256) {
    return total;
}
```

<div class="key">

`public` en una **variable de estado** crea una función de lectura con el mismo nombre.

</div>

---

## `constant` e `immutable`

Dos calificadores que **evitan storage** (y por lo tanto, gas):

```solidity
uint256 public constant MAX = 1000;   // fijado al COMPILAR; vive en el bytecode
address public immutable owner;       // fijado UNA vez, en el constructor
```

| | Se fija... | Vive en... |
|---|---|---|
| `constant` | al compilar | el bytecode |
| `immutable` | una vez, en el constructor | el código desplegado |

<div class="key">

Idioma muy común: `owner` como `immutable`. Leerlas **no toca storage** →
mucho más barato que una variable de estado normal.

</div>

---

## Comentarios NatSpec

La convención de documentación del ecosistema — la van a ver en cualquier contrato real:

```solidity
/// @title  Contador — lleva una cuenta pública
/// @notice Suma `cuantos` al total de una vez.  ← para el usuario
/// @dev    Sin control de acceso: cualquiera    ← para el desarrollador
///         puede llamarla.
/// @param  cuantos  cuánto sumar al total
function incrementarEn(uint256 cuantos) external { ... }
```

Las herramientas (exploradores, wallets, generadores de docs) los leen y los muestran.

---

## `import` y herencia (`is`)

Cierran la anatomía del archivo: arriba del `contract` van los **imports**; al lado del nombre,
**de quién hereda**.

```solidity
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MiToken is Ownable {      // `is` = herencia (el `extends` de Solidity)
    // hereda owner, onlyOwner, transferOwnership…
}
```

`Ownable` (OpenZeppelin) resuelve *"sólo el dueño puede llamar a esto"*. Heredarlo evita
reescribir el control de acceso a mano — **error muy común**.

Una **`interface`** es otra cosa: sólo las firmas, sin cuerpo, para hablarle a un contrato ajeno.

<div class="key">

En la Clase 3 vamos a ver los tests que empiezan con `contract MiTest is Test`: el contrato de test **hereda** del framework de Foundry.

</div>

---

<!-- _class: lead -->

<span class="seg">SEGMENTO 3</span>

# Tipos y data location

---

## Los tipos

**De valor** (se copian):

```solidity
uint256 n;      int256 i;      bool flag;
address cuenta; bytes32 hash;
```

**De referencia** (apuntan a una ubicación):

```solidity
string  texto;
bytes   datos;
uint256[] lista;        // array (dinámico: push/pop)
struct Persona { ... }  // struct
mapping(address => uint256) balances;  // mapping
```

---

## Detalles de tipos que importan

**`address` vs `address payable`:**

```solidity
address cuenta;                       // NO se le puede enviar ETH
address payable cobrador;             // sí se puede
cobrador = payable(cuenta);           // el cast es EXPLÍCITO
```

**`bytes32`:** el tipo de los hashes e identificadores —

```solidity
bytes32 huella = keccak256(abi.encodePacked(dato));
```

---

## No hay `null`

Toda variable nace **zero-inicializada**: `0`, `false`, `address(0)`, `""`.

Consecuencias directas:

- "No inicializado" y "vale cero" son **indistinguibles** — si cero es un valor
  válido del dominio, hace falta un flag aparte
- `address(0)` como valor especial: mandar fondos u ownership a `address(0)`
  es un bug clásico — muchos contratos lo chequean explícitamente

---

## El mapping no es un diccionario común

```solidity
mapping(address => uint256) private balances;
```

- **Todas las claves "existen" siempre**, con valor cero:
  `balances[cualquiera]` nunca falla — devuelve `0`
  *(es la zero-inicialización otra vez)*
- **No es iterable**: no hay `keys()` ni `length`.
  ¿"Cómo listo todos los balances"? 
  → **off-chain**, con eventos o un indexer 
  → **on-chain**, con un array (no recomendable)
- `delete balances[x]` sólo resetea esa clave a cero

Es *la* estructura de estado: casi todo contrato que lleva **saldos por usuario** es, en el
fondo, un mapping.

---

## `private` no es privacidad

`private` controla el acceso **desde otros contratos** —
el contenido del storage es **legible por cualquiera** desde afuera de la blockchain.

<div class="key">

El estado es público por diseño (Clase 1). **Nunca guardar secretos en storage**,
ni "escondidos" en variables `private`.

</div>

---

## Data location: ¿dónde vive el dato?

Fuente clásica de **bugs** y de **costos de gas**:

<svg viewBox="0 0 880 170" width="800">
  <g font-family="sans-serif" font-size="13" text-anchor="middle">
    <rect x="30"  y="30" width="260" height="120" rx="10" fill="#fee2e2" stroke="#dc2626"/>
    <text x="160" y="58" font-weight="bold">storage</text>
    <text x="160" y="84" font-size="12">persistente on-chain</text>
    <text x="160" y="108" font-size="12">💰 caro de escribir</text>
    <text x="160" y="132" font-size="11" fill="#64748b">el estado del contrato</text>
    <rect x="310" y="30" width="260" height="120" rx="10" fill="#fef9c3" stroke="#ca8a04"/>
    <text x="440" y="58" font-weight="bold">memory</text>
    <text x="440" y="84" font-size="12">temporal, mutable</text>
    <text x="440" y="108" font-size="12">dura sólo la llamada</text>
    <text x="440" y="132" font-size="11" fill="#64748b">variables de trabajo</text>
    <rect x="590" y="30" width="260" height="120" rx="10" fill="#dcfce7" stroke="#16a34a"/>
    <text x="720" y="58" font-weight="bold">calldata</text>
    <text x="720" y="84" font-size="12">sólo lectura</text>
    <text x="720" y="108" font-size="12">✅ la más barata</text>
    <text x="720" y="132" font-size="11" fill="#64748b">parámetros de entrada</text>
  </g>
</svg>

---

## Data location en código

```solidity
mapping(address => uint256) private balances;  // sólo existe en storage

function nombres(string calldata n)
    external pure
    returns (string memory)
{
    return n;   // calldata entra (lectura barata), memory sale
}
```

<div class="key">

Equivocarse de location —p. ej. copiar a `memory` creyendo que se modifica el estado—
es un error **muy común** al empezar.

</div>

---

## Ejemplo del error clásico de location

```solidity
struct Usuario { uint256 saldo; }
mapping(address => Usuario) usuarios;

function malRomper() external {
    Usuario memory u = usuarios[msg.sender];  // ← COPIA a memory
    u.saldo += 10;                            // modifica la copia...
}                                             // ...el storage NO cambia ✗

function bienHacer() external {
    Usuario storage u = usuarios[msg.sender]; // ← REFERENCIA a storage
    u.saldo += 10;                            // modifica el estado real ✓
}
```

`memory` vs `storage` en una variable local **cambia por completo** el comportamiento.

---

<!-- _class: lead -->

<span class="seg">SEGMENTO 4 · ~30 min</span>

# Funciones
# visibilidad · mutabilidad · errores

---

## Visibilidad

<svg viewBox="0 0 880 200" width="740">
  <g font-family="sans-serif" font-size="13" text-anchor="middle">
    <rect x="240" y="20" width="400" height="170" rx="12" fill="#f8fafc" stroke="#334155" stroke-dasharray="5 4"/>
    <text x="440" y="40" font-size="12" fill="#64748b">el contrato</text>
    <rect x="30" y="80" width="150" height="45" rx="8" fill="#fee2e2" stroke="#dc2626"/>
    <text x="105" y="107">afuera</text>
    <rect x="270" y="55" width="150" height="36" rx="6" fill="#dbeafe" stroke="#2563eb"/>
    <text x="345" y="78" font-size="12">public</text>
    <rect x="270" y="100" width="150" height="36" rx="6" fill="#dbeafe" stroke="#2563eb"/>
    <text x="345" y="123" font-size="12">external</text>
    <rect x="460" y="55" width="150" height="36" rx="6" fill="#dcfce7" stroke="#16a34a"/>
    <text x="535" y="78" font-size="12">internal</text>
    <rect x="460" y="100" width="150" height="36" rx="6" fill="#dcfce7" stroke="#16a34a"/>
    <text x="535" y="123" font-size="12">private</text>
    <line x1="180" y1="95"  x2="268" y2="75"  stroke="#dc2626" stroke-width="2" marker-end="url(#af)"/>
    <line x1="180" y1="110" x2="268" y2="118" stroke="#dc2626" stroke-width="2" marker-end="url(#af)"/>
    <text x="440" y="165" font-size="11" fill="#16a34a">internal/private: NO desde afuera</text>
    <defs><marker id="af" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto"><path d="M0,0 L9,3 L0,6" fill="#dc2626"/></marker></defs>
  </g>
</svg>

| | Quién puede llamar |
|---|---|
| `public` | interna **y** externa |
| `external` | sólo desde afuera (más barata para args grandes) |
| `internal` | este contrato y herederos |
| `private` | sólo este contrato |

> Regla práctica para empezar: `external` para la API, `internal` para helpers;
> `public` sólo cuando de verdad hace falta llamar desde adentro **y** desde afuera.

---

## Mutabilidad

| Modificador | Qué puede hacer |
|---|---|
| `view` | **lee** estado, no escribe |
| `pure` | **ni** lee **ni** escribe |
| `payable` | puede **recibir ETH** |

```solidity
function leer() external view returns (uint256) { return total; }
function sumar(uint256 a, uint256 b) external pure returns (uint256) { return a + b; }
function depositar() external payable { /* msg.value trae ETH */ }
```

El compilador **verifica** estas promesas: si una `view` intenta escribir, no compila.

<div class="key">

Y una función **sin** `payable` **rechaza** cualquier ETH que le manden (la tx revierte).
Por eso `depositar()` de arriba lleva `payable` — y `leer()` no.

</div>

---

## Funciones especiales

| Función | Cuándo corre |
|---|---|
| `constructor()` | una vez, al deploy |
| `receive() external payable` | llega **ETH sin datos** (transferencia "pelada") |
| `fallback() external [payable]` | la llamada **no matchea ninguna función** |

`receive` **tiene que ser** `payable`. `fallback` puede serlo **o no**:

| El contrato tiene… | Transferencia "pelada" (sin datos) |
|---|---|
| `receive` | la atiende `receive` |
| sólo `fallback` **payable** | la atiende `fallback` — **no revierte** |
| sólo `fallback` **sin** `payable` | **revierte** |
| ninguno de los dos | **revierte** |

Con datos que no matchean ninguna función, siempre va a `fallback`. <span class="nota">*</span>

---

## Errores: require, revert, custom errors

```solidity
error NoAutorizado();              // custom error (desde 0.8.4)

modifier soloOwner() {
    if (msg.sender != owner) revert NoAutorizado();
    _;   // ← acá se inserta el cuerpo de la función
}

function reset() external soloOwner {
    total = 0;
}
```

- `require` / `revert` **revierten** todo el cambio si la condición falla
- **Custom errors**: más **baratos** en gas que strings de `require(...)`
- **Modifiers**: pre-condición **reutilizable**

---

## require vs custom error

```solidity
// Estilo viejo: string (cuesta más gas, el string vive en el bytecode)
require(msg.sender == owner, "No autorizado");

// Estilo moderno: custom error (más barato)
if (msg.sender != owner) revert NoAutorizado();
```

<div class="key">

Convención: nombrar los errores como **sustantivos** descriptivos
(`NoAutorizado`, `SaldoInsuficiente`), no como frases.

</div>

`assert(...)`, en una línea: es para **invariantes internas** ("esto no puede pasar jamás") —
si falla, es un bug del contrato, no un input inválido. Los analizadores de la Clase 6
lo tratan distinto de `require` por esa semántica.

---

## Los custom errors pueden llevar datos

Y ahí está buena parte de su valor:

```solidity
error SaldoInsuficiente(uint256 pedido, uint256 disponible);

if (monto > saldo) revert SaldoInsuficiente(monto, saldo);
```

<div class="key">

Quien recibe el revert puede **decodificar esos valores** —el test, el frontend, el explorador—:
mucho más útil para diagnosticar que un string, y aún así **más barato**.

</div>

> Cada error tiene un **selector** que lo identifica. En la Clase 3 los tests van a
> esperar errores por nombre usándolo: `vm.expectRevert(MiContrato.MiError.selector)`.

---

## Qué significa "revertir", exactamente

La tx se deshace **entera y atómicamente**:

- todos los cambios de estado
- todas las transferencias de ETH
- todos los eventos emitidos

No hay "quedó por la mitad". Y vale **a través de toda la cadena de llamadas**:
si A llamó a B y B revierte, lo de A también se deshace
*(salvo manejo explícito con `try/catch` — mención, no lo desarrollamos)*.

<div class="key">

**Pero el gas consumido hasta ahí se paga igual.** Revertir no es gratis —
la diferencia con Cardano que quedó planteada en la Clase 1.

</div>

---

<!-- _class: lead -->

## — intervalo —

---

<!-- _class: lead -->

<span class="seg">SEGMENTO 5 · ~20 min</span>

# Eventos y contexto
# de la transacción

---

## Eventos: el puente al off-chain

```solidity
event Incrementado(address indexed quien, uint256 nuevoTotal);

function incrementar() external {
    total += 1;
    emit Incrementado(msg.sender, total);
}
```

<svg viewBox="0 0 880 120" width="800">
  <g font-family="sans-serif" font-size="13" text-anchor="middle">
    <rect x="30"  y="30" width="180" height="55" rx="8" fill="#dbeafe" stroke="#2563eb"/>
    <text x="120" y="55">contrato</text>
    <text x="120" y="75" font-size="11">emit Evento(...)</text>
    <line x1="210" y1="57" x2="300" y2="57" stroke="#334155" stroke-width="2" marker-end="url(#ae)"/>
    <rect x="305" y="30" width="180" height="55" rx="8" fill="#fef9c3" stroke="#ca8a04"/>
    <text x="395" y="55">logs</text>
    <text x="395" y="75" font-size="11">en la blockchain</text>
    <line x1="485" y1="57" x2="575" y2="57" stroke="#334155" stroke-width="2" marker-end="url(#ae)"/>
    <rect x="580" y="30" width="270" height="55" rx="8" fill="#dcfce7" stroke="#16a34a"/>
    <text x="715" y="55">frontends / indexers</text>
    <text x="715" y="75" font-size="11">los leen off-chain</text>
    <defs><marker id="ae" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto"><path d="M0,0 L9,3 L0,6" fill="#334155"/></marker></defs>
  </g>
</svg>

Los contratos **no** pueden leer logs. `indexed` (hasta 3 por evento) manda ese campo a los
*topics* del log, que es lo que se puede **filtrar**: acá `quien` es `indexed`, así que un
frontend puede pedir *"todos los `Incrementado` de esta cuenta"*. `nuevoTotal` **no** es
`indexed` — viaja en el log, pero no se puede buscar por él.

---

## ¿Por qué eventos y no storage para el historial?

| | Costo aprox. |
|---|---|
| Emitir un evento | **cientos** de gas |
| Guardar una entrada de historial en storage | **~20.000** de gas |

...para datos que el contrato **nunca necesita releer**.

<div class="key">

**Storage para lo que el contrato necesita decidir;
eventos para lo que los humanos y las UIs necesitan saber.**

</div>

---

## El contexto de la transacción

Variables globales disponibles en cualquier función:

| Global | Qué es |
|---|---|
| `msg.sender` | quién llama (dirección **directa**: EOA o contrato) |
| `msg.value` | ETH enviado con la llamada (en wei) |
| `msg.data` | el calldata crudo de la llamada (*) |
| `block.timestamp` | tiempo del bloque (lo pone el **productor** del bloque) |
| `block.number` | número de bloque actual |
| `tx.origin` | la **EOA** que originó toda la cadena de llamadas |

Ownership básico: guardar `owner` en el constructor (idealmente `immutable`)
y chequearlo con un modifier.

---

## ⚠️ Aviso temprano: `tx.origin`

<svg viewBox="0 0 880 165" width="820">
  <g font-family="sans-serif" font-size="12.5" text-anchor="middle">
    <rect x="20"  y="60" width="130" height="50" rx="8" fill="#dcfce7" stroke="#16a34a"/>
    <text x="85" y="82">víctima</text>
    <text x="85" y="100" font-size="10">(dueña)</text>
    <line x1="150" y1="85" x2="235" y2="85" stroke="#334155" stroke-width="2" marker-end="url(#at)"/>
    <text x="192" y="76" font-size="10">llama</text>
    <rect x="240" y="60" width="160" height="50" rx="8" fill="#fee2e2" stroke="#dc2626"/>
    <text x="320" y="82">contrato malicioso</text>
    <line x1="400" y1="85" x2="485" y2="85" stroke="#dc2626" stroke-width="2" marker-end="url(#at)"/>
    <text x="442" y="76" font-size="10">reenvía</text>
    <rect x="490" y="60" width="160" height="50" rx="8" fill="#dbeafe" stroke="#2563eb"/>
    <text x="570" y="82">tu contrato</text>
    <text x="745" y="70" font-size="12" fill="#dc2626">tx.origin = víctima ✗</text>
    <text x="745" y="100" font-size="12" fill="#16a34a">msg.sender = malicioso ✓</text>
    <defs><marker id="at" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto"><path d="M0,0 L9,3 L0,6" fill="#334155"/></marker></defs>
  </g>
</svg>

### No usar `tx.origin` para autorización — usar `msg.sender`

*(Se profundiza en la Clase 6.)*

---

## Enviar ETH *desde* un contrato

La forma actual — `call` con valor, chequeando el resultado:

```solidity
error TransferFailed();          // un custom error, como los de recién

(bool ok, ) = destinatario.call{value: monto}("");
if (!ok) revert TransferFailed();
```

Ese `("")` es el **calldata vacío**: sólo plata. Si además querés **llamar a una función**,
ahí va la llamada — o, si conocés el contrato, `Otro(dir).f{value: monto}(arg)`.

Existen `transfer` y `send` (heredadas, con límite fijo de gas que las volvió frágiles);
hoy la recomendación es **`call` + chequear `ok`**.

<div class="key">

Si el destinatario es un **contrato**, esa línea **ejecuta código ajeno en el medio de
tu función**.

</div>

De ahí salen **checks-effects-interactions** (Clase 3) y **reentrancy** (Clases 6–7).

---

<!-- _class: lead -->

<span class="seg">SEGMENTO 6 · ~35 min</span>

# Tooling + mini-demo

---

## Empezamos con Remix

`https://remix.ethereum.org` — editor en el navegador, **sin instalar nada**.
Ideal para el primer contacto.

<svg viewBox="0 0 880 110" width="820">
  <g font-family="sans-serif" font-size="12.5" text-anchor="middle">
    <rect x="20"  y="35" width="150" height="45" rx="8" fill="#dbeafe" stroke="#2563eb"/>
    <text x="95" y="62">escribir</text>
    <line x1="170" y1="57" x2="200" y2="57" stroke="#334155" stroke-width="2" marker-end="url(#ad)"/>
    <rect x="205" y="35" width="150" height="45" rx="8" fill="#dbeafe" stroke="#2563eb"/>
    <text x="280" y="62">compilar</text>
    <line x1="355" y1="57" x2="385" y2="57" stroke="#334155" stroke-width="2" marker-end="url(#ad)"/>
    <rect x="390" y="35" width="150" height="45" rx="8" fill="#dcfce7" stroke="#16a34a"/>
    <text x="465" y="62" font-size="12">desplegar (VM)</text>
    <line x1="540" y1="57" x2="570" y2="57" stroke="#334155" stroke-width="2" marker-end="url(#ad)"/>
    <rect x="575" y="35" width="150" height="45" rx="8" fill="#fef9c3" stroke="#ca8a04"/>
    <text x="650" y="62">llamar</text>
    <line x1="725" y1="57" x2="755" y2="57" stroke="#334155" stroke-width="2" marker-end="url(#ad)"/>
    <rect x="760" y="35" width="100" height="45" rx="8" fill="#f1f5f9" stroke="#334155"/>
    <text x="810" y="62" font-size="11">ver estado</text>
    <defs><marker id="ad" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto"><path d="M0,0 L9,3 L0,6" fill="#334155"/></marker></defs>
  </g>
</svg>

---

## La demo en vivo (1/2) — deploy y primera tx

Contrato listo para pegar: **`ethereum/src/Contador.sol`** — junta las piezas que
fueron apareciendo sueltas (estado, evento, custom error + modifier, `incrementar()`, `reset()`).

1. Crear `Contador.sol`, **compilar** (Ctrl+S compila solo; la versión debe matchear el `pragma`)
2. **Desplegar en la "Remix VM"**: blockchain simulada en el navegador —
   cuentas de juguete con 100 ETH falsos. Señalar el **dropdown de cuentas**: cada una es una EOA
3. Leer el contrato desplegado:
   - botones **azules** = `view` / getters → **gratis**, no crean tx
   - botones **naranjas** = escriben → **cada click es una transacción**
4. Llamar `incrementar()` y abrir la tx en la consola: ver el **gas usado** y,
   en *logs*, el evento `Incrementado` decodificado

---

## La demo en vivo (2/2) — el contexto en acción

5. En la consola, la tx trae **`data: 0x…`** — ése es el **`msg.data`**. Los primeros
   **4 bytes** son el **selector** de la función; **el resto, los parámetros**. Acá no hay
   resto: `incrementar()` no toma nada, y por eso **`decoded input`** dice `{}`
6. Llamar `reset()` y **comparar los dos `data`**: distinto **selector** → es lo que dice
   **qué función** se llamó
7. **Cambiar de cuenta** y llamar `reset()` → **revierte** con `NoAutorizado()` y `total`
   **no cambió**. Volver a la cuenta original → funciona
8. Mandar ETH "pelado" desde el campo **Value** → **revierte**: no hay `receive()`

<div class="key">

**Llamar a una función no es "llamar"**: es mandarle **bytes** a una dirección, y el contrato
decide qué hacer con ellos. Y con el paso 7: los **mismos** bytes, **distinto `msg.sender`
→ distinto resultado**.

</div>

---

## Actividad — leer un contrato que no vieron

<!-- _class: small -->

En parejas, "leerlo completo" (si no llega el tiempo, queda de tarea):

<div style="display:flex; gap:1.2em">
<div style="flex:1">

```solidity
contract Alcancia {
    address public immutable owner;
    mapping(address => uint256) private ahorros;
    bool public cerrada;

    event Ahorro(address indexed quien,
                 uint256 monto);
    event Cierre(uint256 totalFinal);

    error EstaCerrada();
    error NoEsOwner();

    constructor() { owner = msg.sender; }

    modifier soloOwner() {
        if (msg.sender != owner)
            revert NoEsOwner();
        _;
    }
```

</div>
<div style="flex:1">

```solidity
    function ahorrar() external payable {
        if (cerrada) revert EstaCerrada();
        ahorros[msg.sender] += msg.value;
        emit Ahorro(msg.sender, msg.value);
    }

    function miAhorro() external view
            returns (uint256) {
        return ahorros[msg.sender];
    }

    function cerrar() external soloOwner {
        cerrada = true;
        emit Cierre(address(this).balance);
    }
}
```

</div>
</div>

Son **tres** funciones. Contalas — hace falta para la consigna 2, y para la pregunta que cierra la clase.

---

## Actividad — las consignas

1. Variables de estado y **dónde vive** cada una
2. **Visibilidad y mutabilidad** de cada función
3. ¿**Quién** puede llamar qué? (¿y quién es `owner`?)
4. ¿Qué **eventos** se emiten y cuándo?
5. Si alguien llama `ahorrar()` con 1 ETH **después del cierre**, ¿qué pasa con su ETH?
6. ¿`ahorros` es **secreto**, dado que es `private`?

*(Las respuestas las vemos juntos al cierre.)* <span class="nota">*</span>

---

## ¿Cómo saco la plata de la `Alcancia`?

<div class="key">

**No se puede: falta una función de retiro.** El contrato acepta ETH pero no tiene
ninguna función que lo envíe — quedó **atrapado para siempre**
(el código es inmutable; no hay a quién pedirle un fix).

</div>

Escribir esa función de retiro es **exactamente** el trabajo de la **Clase 3** —
y por qué escribirla **bien** es mucho más delicado de lo que parece.

---

## Un dato que se ve en la Clase 6

Desde **Solidity 0.8** el overflow/underflow **se chequea por defecto** (revierte).

<div class="key">

La vulnerabilidad clásica **no desapareció**: ahora vive en bloques `unchecked` y en *casts*.

</div>

```solidity
unchecked {
    balances[msg.sender] += amount;   // puede dar wraparound (sin chequeo)
}

uint8 chico = uint8(valorGrande);     // trunca en silencio si no entra
```

Lo retomamos al ver el **modelo de amenazas**.

---

## Lo que se ve más adelante

| Hoy apareció... | Vuelve en... |
|---|---|
| `(bool ok, ) = dest.call{value: monto}("")` | **Clase 3** — la función de retiro y el orden estado/interacción (CEI) |
| "esa línea ejecuta código ajeno en el medio de tu función" | **Clases 6–7** — reentrancy |
| Overflow en `unchecked` y casts | **Clase 6** — modelo de amenazas |
| `tx.origin` · código inmutable (proxies) · `block.timestamp` lo pone el productor | **Clase 6** |
| Remix | → **Foundry** desde la Clase 3 |

---

<!-- _class: lead -->

## Lecturas

- *Mastering Ethereum*, **2ª ed. (2025)** — **cap. 7**, *Smart Contracts and Solidity*
  *(actualizada post-Merge; gratis online y en `ethereumbook`)*
- Documentación oficial: `docs.soliditylang.org` (versión actual)
- Para practicar con ejemplos cortos: `solidity-by-example.org`
  *(ejemplos por tema, misma filosofía que esta clase)*

---

<!-- _class: lead -->
<!-- _paginate: false -->

# Próxima clase

## Clase 3 — Taller Solidity con Foundry

Construir una bóveda (`Vault.sol`) paso a paso, tests con `forge test`,
y el patrón **checks-effects-interactions**.
