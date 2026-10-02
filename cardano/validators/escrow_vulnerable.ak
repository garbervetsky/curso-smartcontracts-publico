// escrow_vulnerable.ak — versión DELIBERADAMENTE VULNERABLE del escrow.
//
// MATERIAL DE ENSEÑANZA. No usar en producción.
//
// Esta versión SÍ intenta validar el output (a diferencia del escrow base de la
// Clase 5, que solo miraba la firma). Pero la validación es ingenua: solo exige
// "existe UN output que paga al beneficiario el monto". Eso la deja expuesta a
// DOUBLE SATISFACTION: si la transacción gasta dos inputs de este mismo escrow,
// un único output puede satisfacer ambas validaciones a la vez.
//
// El fix, un único input de script, se vio en la Clase 8 y se repasa en la 9.

use aiken/collection/list
use aiken/interval
use cardano/address.{Script, VerificationKey, from_verification_key}
use cardano/assets
use cardano/transaction.{Output, OutputReference, Transaction, placeholder}

pub type Datum {
  beneficiary: ByteArray,
  owner: ByteArray,
  deadline: Int,
  // monto bloqueado que debe recibir el beneficiario (en lovelace)
  amount: Int,
}

pub type Redeemer {
  Claim
  Cancel
}

// Autorización: firma del beneficiario + antes del deadline. (Igual que Clase 5.)
fn authorized(d: Datum, tx: Transaction) -> Bool {
  let signed = list.has(tx.extra_signatories, d.beneficiary)
  let on_time = interval.before(d.deadline) |> interval.includes(tx.validity_range)
  signed && on_time
}

// ¿Existe AL MENOS UN output que pague al beneficiario al menos `amount`?
// Esta es la verificación ingenua: no suma, no descuenta, no ata el output a
// este input en particular. Cualquier output que alcance el monto "cuenta".
fn some_output_pays(
  outputs: List<Output>,
  beneficiary: ByteArray,
  amount: Int,
) -> Bool {
  list.any(
    outputs,
    fn(output: Output) {
      let to_beneficiary =
        when output.address.payment_credential is {
          VerificationKey(vk) -> vk == beneficiary
          Script(_) -> False
        }
      to_beneficiary && assets.lovelace_of(output.value) >= amount
    },
  )
}

// VULNERABLE: autorización + "existe un output que paga". Double-satisfiable.
fn can_claim_vulnerable(d: Datum, tx: Transaction) -> Bool {
  authorized(d, tx) && some_output_pays(tx.outputs, d.beneficiary, d.amount)
}

fn can_cancel(d: Datum, tx: Transaction) -> Bool {
  list.has(tx.extra_signatories, d.owner)
}

validator escrow_vulnerable {
  spend(
    datum: Option<Datum>,
    redeemer: Redeemer,
    _utxo: OutputReference,
    self: Transaction,
  ) {
    expect Some(d) = datum
    when redeemer is {
      Claim -> can_claim_vulnerable(d, self)
      Cancel -> can_cancel(d, self)
    }
  }

  else(_) {
    fail
  }
}

// ---------------------------------------------------------------------------
// Helpers de test
// ---------------------------------------------------------------------------

const beneficiary_hash: ByteArray = #"b0b0"

const owner_hash: ByteArray = #"0a0a"

const deadline_ms: Int = 10_000

const locked: Int = 100

fn make_datum() -> Datum {
  Datum {
    beneficiary: beneficiary_hash,
    owner: owner_hash,
    deadline: deadline_ms,
    amount: locked,
  }
}

// Un output que paga `amount` al beneficiario.
fn output_to_beneficiary(amount: Int) -> Output {
  Output {
    address: from_verification_key(beneficiary_hash),
    value: assets.from_lovelace(amount),
    datum: transaction.NoDatum,
    reference_script: None,
  }
}

// ---------------------------------------------------------------------------
// Tests — comportamiento "feliz" (parece correcto)
// ---------------------------------------------------------------------------

test vuln_claim_legitimo_un_input_un_output() {
  let d = make_datum()
  let tx =
    Transaction {
      ..placeholder,
      extra_signatories: [beneficiary_hash],
      validity_range: interval.before(deadline_ms),
      outputs: [output_to_beneficiary(locked)],
    }
  can_claim_vulnerable(d, tx)
}

test vuln_claim_sin_output_falla() {
  let d = make_datum()
  let tx =
    Transaction {
      ..placeholder,
      extra_signatories: [beneficiary_hash],
      validity_range: interval.before(deadline_ms),
      outputs: [],
    }
  !can_claim_vulnerable(d, tx)
}

// ---------------------------------------------------------------------------
// Test que DESTAPA la vulnerabilidad: DOUBLE SATISFACTION
// ---------------------------------------------------------------------------
// Escenario: la transacción gasta DOS inputs del escrow, cada uno con el mismo
// beneficiario y monto (100 c/u → deberían pagarse 200). Pero la tx crea UN solo
// output de 100 al beneficiario. El validator vulnerable, evaluado para CADA
// input, encuentra "su" output de 100 y aprueba. Resultado: se liberan 200 pero
// solo se pagan 100. El atacante (que arma la tx) se queda con 100.
//
// Este test PASA, y ese "pase" ES el bug: el validator aprueba un Claim que
// debería rechazar.
test vuln_double_satisfaction_se_aprueba_indebidamente() {
  let d = make_datum()
  // UN solo output de 100, aunque hay dos claims de 100 en juego.
  let tx =
    Transaction {
      ..placeholder,
      extra_signatories: [beneficiary_hash],
      validity_range: interval.before(deadline_ms),
      outputs: [output_to_beneficiary(locked)],
    }
  // El validator aprueba para el input A...
  let aprueba_input_a = can_claim_vulnerable(d, tx)
  // ...y también para el input B (mismo datum, mismo único output).
  let aprueba_input_b = can_claim_vulnerable(d, tx)
  // Ambos aprueban con un solo output → double satisfaction.
  aprueba_input_a && aprueba_input_b
}
