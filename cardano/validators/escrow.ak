// Escrow — validator del taller de la Clase 5.
// Se construye en esta clase y se audita en la Clase 9.
//
// Idea: un output bloqueado puede ser reclamado por el beneficiario antes de un
// deadline, o cancelado por el owner en cualquier momento.
//
// Clase 5: versión completa con deadline via validity_range.
// Clase 9 (auditoría): ¿este validator verifica que los fondos realmente lleguen
//   al beneficiario y por el monto correcto? (pista: double satisfaction).

use aiken/collection/list
use aiken/interval
use cardano/transaction.{OutputReference, Transaction, placeholder}

// ---------------------------------------------------------------------------
// Tipos
// ---------------------------------------------------------------------------

pub type Datum {
  // quién puede reclamar los fondos (hash de clave pública)
  beneficiary: ByteArray,
  // quién puede cancelar y recuperar (hash de clave pública)
  owner: ByteArray,
  // límite de tiempo para reclamar: POSIX time en milisegundos
  deadline: Int,
}

pub type Redeemer {
  Claim
  Cancel
}

// ---------------------------------------------------------------------------
// Lógica auxiliar (testeable de forma aislada)
// ---------------------------------------------------------------------------

fn can_claim(d: Datum, tx: Transaction) -> Bool {
  // El beneficiario firma Y la transacción ocurre antes del deadline.
  // interval.before(d.deadline) crea (-∞, deadline]; includes verifica que
  // la validity_range de la tx esté completamente contenida en ese intervalo.
  let signed_by_beneficiary = list.has(tx.extra_signatories, d.beneficiary)
  let before_deadline =
    interval.before(d.deadline) |> interval.includes(tx.validity_range)
  signed_by_beneficiary && before_deadline
}

fn can_cancel(d: Datum, tx: Transaction) -> Bool {
  // El owner puede cancelar en cualquier momento (recuperar fondos bloqueados).
  list.has(tx.extra_signatories, d.owner)
}

// ---------------------------------------------------------------------------
// Validator
// ---------------------------------------------------------------------------

validator escrow {
  spend(
    datum: Option<Datum>,
    redeemer: Redeemer,
    _utxo: OutputReference,
    self: Transaction,
  ) {
    expect Some(d) = datum
    when redeemer is {
      Claim -> can_claim(d, self)
      Cancel -> can_cancel(d, self)
    }
  }

  else(_) {
    fail
  }
}

// ---------------------------------------------------------------------------
// Tests unitarios
// ---------------------------------------------------------------------------

const beneficiary_hash: ByteArray = #"aabbccdd"

const owner_hash: ByteArray = #"11223344"

const deadline_ms: Int = 10_000

fn make_datum() -> Datum {
  Datum { beneficiary: beneficiary_hash, owner: owner_hash, deadline: deadline_ms }
}

// Claim válido: firma correcta + dentro del deadline
test claim_con_firma_y_antes_del_deadline() {
  let d = make_datum()
  let tx =
    Transaction {
      ..placeholder,
      extra_signatories: [beneficiary_hash],
      validity_range: interval.between(1_000, 5_000),
    }
  can_claim(d, tx)
}

// Claim rechazado: sin firma (aunque sea en tiempo)
test claim_sin_firma_falla() {
  let d = make_datum()
  let tx =
    Transaction {
      ..placeholder,
      extra_signatories: [],
      validity_range: interval.between(1_000, 5_000),
    }
  !can_claim(d, tx)
}

// Claim rechazado: firma correcta pero fuera del deadline
test claim_despues_del_deadline_falla() {
  let d = make_datum()
  let tx =
    Transaction {
      ..placeholder,
      extra_signatories: [beneficiary_hash],
      validity_range: interval.between(10_001, 15_000),
    }
  !can_claim(d, tx)
}

// Claim rechazado: firmó el owner en vez del beneficiario
test claim_con_firma_equivocada_falla() {
  let d = make_datum()
  let tx =
    Transaction {
      ..placeholder,
      extra_signatories: [owner_hash],
      validity_range: interval.between(1_000, 5_000),
    }
  !can_claim(d, tx)
}

// Cancel válido: el owner firma
test cancel_con_firma_del_owner() {
  let d = make_datum()
  let tx =
    Transaction { ..placeholder, extra_signatories: [owner_hash], validity_range: interval.everything }
  can_cancel(d, tx)
}

// Cancel rechazado: firmó el beneficiario en vez del owner
test cancel_con_firma_equivocada_falla() {
  let d = make_datum()
  let tx =
    Transaction {
      ..placeholder,
      extra_signatories: [beneficiary_hash],
      validity_range: interval.everything,
    }
  !can_cancel(d, tx)
}

// Cancel puede ocurrir después del deadline (el owner recupera fondos vencidos)
test cancel_despues_del_deadline_pasa() {
  let d = make_datum()
  let tx =
    Transaction {
      ..placeholder,
      extra_signatories: [owner_hash],
      validity_range: interval.after(50_000),
    }
  can_cancel(d, tx)
}

// ---------------------------------------------------------------------------
// Test property-based (requiere aiken-lang/fuzz como dependencia)
// ---------------------------------------------------------------------------
// Para agregar en la Clase 5 si se instala el paquete fuzz:
//
//   [[dependencies]]
//   name = "aiken-lang/fuzz"
//   version = "main"
//   source = "github"
//
// use aiken/fuzz
//
// test prop_claim_pasa_con_firma_y_tiempo_correctos(deadline via fuzz.int()) {
//   let d = Datum { beneficiary: beneficiary_hash, owner: owner_hash, deadline: deadline }
//   let tx = Transaction {
//     ..placeholder,
//     extra_signatories: [beneficiary_hash],
//     validity_range: interval.before(deadline),
//   }
//   can_claim(d, tx)
// }
