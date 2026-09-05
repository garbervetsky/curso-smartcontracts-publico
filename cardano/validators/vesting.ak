//// Vesting: los fondos se liberan al beneficiario recién DESPUÉS de un deadline.
////
//// Es el espejo del escrow. Aquel exige que la transacción ocurra **antes** del
//// deadline (`interval.before`); éste, **después** (`interval.after`). Es el mismo
//// razonamiento sobre intervalos, dado vuelta — y ahí está el ejercicio.
////
//// Se construye en el taller de la Clase 5: `can_unlock` viene sin implementar y
//// los tests de abajo arrancan en rojo. Son la especificación.

use aiken/collection/list
use aiken/interval
use cardano/transaction.{OutputReference, Transaction, placeholder}

// ---------------------------------------------------------------------------
// Tipos
// ---------------------------------------------------------------------------

pub type Datum {
  /// hash de clave pública de quien puede retirar
  beneficiary: ByteArray,
  /// POSIX time en milisegundos: recién a partir de acá se puede retirar
  deadline: Int,
}

// El redeemer es `Void`: no hay dos caminos como en el escrow, así que quien
// gasta no tiene que elegir nada.

// ---------------------------------------------------------------------------
// Lógica auxiliar (testeable de forma aislada, igual que en el escrow)
// ---------------------------------------------------------------------------

fn can_unlock(_d: Datum, _tx: Transaction) -> Bool {
  // TODO — Clase 5, taller.
  //
  // Devolver True sólo si se cumplen las DOS condiciones:
  //
  //   1. El beneficiario del datum firmó la transacción.
  //      Pista: `list.has(tx.extra_signatories, ...)`, igual que el escrow.
  //
  //   2. La transacción ocurre DESPUÉS del deadline.
  //      Ojo: el escrow usa `interval.before`. Acá va el otro.
  //      Y como en el escrow, no alcanza con mirar un borde: se exige que
  //      TODO el validity_range esté del lado correcto (`interval.includes`).
  //
  // Cuando esté, cambiar `_d` y `_tx` por `d` y `tx`.
  todo @"implementar can_unlock"
}

// ---------------------------------------------------------------------------
// Validator
// ---------------------------------------------------------------------------

validator vesting {
  spend(
    datum: Option<Datum>,
    _redeemer: Void,
    _utxo: OutputReference,
    self: Transaction,
  ) {
    expect Some(d) = datum
    can_unlock(d, self)
  }

  else(_) {
    fail
  }
}

// ---------------------------------------------------------------------------
// Tests unitarios
// ---------------------------------------------------------------------------

const beneficiary_hash: ByteArray = #"aabbccdd"

const deadline_ms: Int = 10_000

fn make_datum() -> Datum {
  Datum { beneficiary: beneficiary_hash, deadline: deadline_ms }
}

fn tx_con(firmas: List<ByteArray>, rango: interval.Interval) -> Transaction {
  Transaction { ..placeholder, extra_signatories: firmas, validity_range: rango }
}

// Unlock válido: firma correcta y toda la tx ocurre después del deadline
test unlock_con_firma_y_despues_del_deadline() {
  can_unlock(make_datum(), tx_con([beneficiary_hash], interval.after(deadline_ms)))
}

// Rechazado: sin firma, aunque el tiempo esté bien
test unlock_sin_firma_falla() {
  !can_unlock(make_datum(), tx_con([], interval.after(deadline_ms)))
}

// Rechazado: la tx ocurre antes del deadline
test unlock_antes_del_deadline_falla() {
  !can_unlock(
    make_datum(),
    tx_con([beneficiary_hash], interval.between(1_000, 5_000)),
  )
}

// CONSIGNA 1 — escribir este test.
// Que falle cuando firma otro (definí un hash distinto de `beneficiary_hash`),
// aunque el tiempo esté bien.
test unlock_con_firma_equivocada_falla() {
  False
  // ↑ borrá este False y escribí el test
}

// CONSIGNA 2 — escribir este test, y es el que importa.
// Un validity_range que CRUZA el deadline: por ejemplo `interval.between(5_000,
// 15_000)` con el deadline en 10_000. ¿Debería pasar o fallar? Decidilo mirando
// qué garantiza `includes`, escribilo, y si tu implementación no lo cumple,
// arreglala.
test unlock_con_rango_que_cruza_el_deadline_falla() {
  False
  // ↑ borrá este False y escribí el test
}
