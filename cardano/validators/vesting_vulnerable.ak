//// vesting_vulnerable.ak — el vesting de la Clase 5, versión 2, con bugs a propósito.
////
//// MATERIAL DE ENSEÑANZA. No usar en producción.
////
//// Lo que DICE que hace (la especificación):
////   - `Unlock`: el beneficiario retira `amount` recién DESPUÉS del deadline. La tx
////     tiene que pagarle `amount` y gastar un solo UTXO de este script.
////   - `Cancel`: el owner recupera los fondos en cualquier momento.
////
//// Qué cambió respecto del vesting de la Clase 5: se agregaron el owner y el `Cancel`,
//// la validación del output y la protección contra double satisfaction. En la
//// reescritura se rompieron dos cosas. Encontrarlas, demostrarlas con un test y
//// arreglarlas es el taller de la Clase 9 (ver cardano/Taller-Clase9.md).
////
//// Los tests `v2_*` vienen hechos y pasan. Los `poc_*` y los `prop_*` los escribís
//// vos: cada uno tiene la consigna en su comentario y arranca con `todo`, así que
//// `aiken check` los muestra en rojo hasta que estén.

use aiken/collection/list
use aiken/fuzz
use aiken/interval
use cardano/address.{Script, VerificationKey, from_script, from_verification_key}
use cardano/assets
use cardano/transaction.{
  Input, Output, OutputReference, Transaction, placeholder, resolve_input,
}

// ---------------------------------------------------------------------------
// Tipos
// ---------------------------------------------------------------------------

pub type Datum {
  /// quién puede retirar después del deadline (hash de clave pública)
  beneficiary: ByteArray,
  /// quién puede cancelar y recuperar los fondos (hash de clave pública)
  owner: ByteArray,
  /// POSIX time en milisegundos: recién a partir de acá se puede retirar
  deadline: Int,
  /// lo que tiene que cobrar el beneficiario (en lovelace)
  amount: Int,
}

pub type Redeemer {
  Unlock
  /// quien cancela declara quién es
  Cancel { quien: ByteArray }
}

// ---------------------------------------------------------------------------
// Lógica auxiliar
// ---------------------------------------------------------------------------

fn signed_by(tx: Transaction, who: ByteArray) -> Bool {
  list.has(tx.extra_signatories, who)
}

// Después del deadline: si la tx no es de antes, es de después.
fn after_deadline(d: Datum, tx: Transaction) -> Bool {
  !(interval.before(d.deadline) |> interval.includes(tx.validity_range))
}

// Exactamente un input de este script en la tx (cierra la double satisfaction).
fn single_script_input(own_ref: OutputReference, tx: Transaction) -> Bool {
  let own_input = resolve_input(tx.inputs, own_ref)
  let script_addr = own_input.address
  let script_inputs =
    list.filter(tx.inputs, fn(i: Input) { i.output.address == script_addr })
  list.length(script_inputs) == 1
}

// Existe un output que paga al beneficiario al menos `amount`.
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

fn can_unlock(d: Datum, own_ref: OutputReference, tx: Transaction) -> Bool {
  signed_by(tx, d.beneficiary) && after_deadline(d, tx) && single_script_input(
    own_ref,
    tx,
  ) && some_output_pays(tx.outputs, d.beneficiary, d.amount)
}

// Cancelar: el que cancela dice quién es, y tiene que haber firmado.
fn can_cancel(quien: ByteArray, tx: Transaction) -> Bool {
  signed_by(tx, quien)
}

// ---------------------------------------------------------------------------
// Validator
// ---------------------------------------------------------------------------

validator vesting_vulnerable {
  spend(
    datum: Option<Datum>,
    redeemer: Redeemer,
    utxo: OutputReference,
    self: Transaction,
  ) {
    expect Some(d) = datum
    when redeemer is {
      Unlock -> can_unlock(d, utxo, self)
      Cancel { quien } -> can_cancel(quien, self)
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

const atacante_hash: ByteArray = #"bad0"

const deadline_ms: Int = 10_000

const locked: Int = 100

const script_hash: ByteArray = #"5c0107"

const tx_id: ByteArray =
  #"0000000000000000000000000000000000000000000000000000000000000000"

fn make_datum() -> Datum {
  Datum {
    beneficiary: beneficiary_hash,
    owner: owner_hash,
    deadline: deadline_ms,
    amount: locked,
  }
}

// Un input que vive en la dirección del script, en el índice `idx`.
fn make_script_input(idx: Int) -> Input {
  Input {
    output_reference: OutputReference {
      transaction_id: tx_id,
      output_index: idx,
    },
    output: Output {
      address: from_script(script_hash),
      value: assets.from_lovelace(locked),
      datum: transaction.NoDatum,
      reference_script: None,
    },
  }
}

fn ref(idx: Int) -> OutputReference {
  OutputReference { transaction_id: tx_id, output_index: idx }
}

fn output_to_beneficiary(amount: Int) -> Output {
  Output {
    address: from_verification_key(beneficiary_hash),
    value: assets.from_lovelace(amount),
    datum: transaction.NoDatum,
    reference_script: None,
  }
}

// Una tx de Unlock bien formada (un input de script, el pago al beneficiario),
// con las firmas y el rango que se le pasen.
fn tx_unlock(firmas: List<ByteArray>, rango: interval.Interval) -> Transaction {
  Transaction {
    ..placeholder,
    inputs: [make_script_input(0)],
    outputs: [output_to_beneficiary(locked)],
    extra_signatories: firmas,
    validity_range: rango,
  }
}

// Una tx de Cancel: sólo importan las firmas.
fn tx_cancel(firmas: List<ByteArray>) -> Transaction {
  Transaction {
    ..placeholder,
    inputs: [make_script_input(0)],
    extra_signatories: firmas,
    validity_range: interval.everything,
  }
}

// ---------------------------------------------------------------------------
// Tests — lo que anda (parece correcto)
// ---------------------------------------------------------------------------

test v2_unlock_legitimo_pasa() {
  can_unlock(
    make_datum(),
    ref(0),
    tx_unlock([beneficiary_hash], interval.after(deadline_ms)),
  )
}

test v2_unlock_sin_firma_falla() {
  !can_unlock(make_datum(), ref(0), tx_unlock([], interval.after(deadline_ms)))
}

test v2_unlock_sin_pago_al_beneficiario_falla() {
  let tx =
    Transaction {
      ..tx_unlock([beneficiary_hash], interval.after(deadline_ms)),
      outputs: [],
    }
  !can_unlock(make_datum(), ref(0), tx)
}

// La double satisfaction está cerrada: dos inputs del script, rechazado.
test v2_unlock_con_dos_inputs_de_script_falla() {
  let tx =
    Transaction {
      ..tx_unlock([beneficiary_hash], interval.after(deadline_ms)),
      inputs: [make_script_input(0), make_script_input(1)],
    }
  !can_unlock(make_datum(), ref(0), tx)
}

test v2_owner_recupera_los_fondos_pasa() {
  can_cancel(owner_hash, tx_cancel([owner_hash]))
}

// ---------------------------------------------------------------------------
// CONSIGNA 2 — los PoCs: la tx-dato que el validator aprueba y no debería
// ---------------------------------------------------------------------------
// En EUTXO el exploit no es un contrato: es una transacción. Cada test arma una
// tx que el validator DEBERÍA rechazar y afirma que la aprueba. Cuando lo
// escribas bien, el test PASA, y ese pase es el bug.

// TODO: una tx de Unlock con la firma del beneficiario y un validity_range que
// empieza ANTES del deadline (10_000). Pista: `tx_unlock` arma todo lo demás;
// elegí el rango con `interval.between`. ¿Y con `interval.everything`?
test poc_unlock_antes_del_deadline_se_aprueba() {
  let pendiente: Bool = todo @"consigna 2: la tx que retira antes de tiempo"
  pendiente
}

// TODO: una tx de Cancel firmada por `atacante_hash`, que no es el owner, y que
// el validator aprueba igual. Mirá qué compara `can_cancel` y contra qué.
test poc_cualquiera_se_lleva_los_fondos() {
  let pendiente: Bool =
    todo @"consigna 2: la tx con la que un extranio se lleva los fondos"
  pendiente
}

// ---------------------------------------------------------------------------
// CONSIGNA 3 — las propiedades de seguridad, para todos los casos
// ---------------------------------------------------------------------------
// Un PoC es UNA tx. Una propiedad dice qué debe pasar con TODAS. Contra este
// validator, las dos tienen que FALLAR: `aiken check` te muestra el
// contraejemplo que encontró y achicó. Cuando tengas tu versión arreglada,
// copialas ahí: tienen que pasar `[after 100 tests]`.

// Generador: un rango [lo, hi] que empieza antes del deadline. Viene hecho.
fn rango_que_empieza_antes() -> Fuzzer<interval.Interval> {
  fuzz.int_between(0, deadline_ms - 1)
    |> fuzz.and_then(
        fn(lo) {
          fuzz.int_at_least(lo)
            |> fuzz.map(fn(hi) { interval.between(lo, hi) })
        },
      )
}

// TODO: para todo rango que empieza antes del deadline, Unlock rechaza.
test prop_unlock_rechaza_todo_rango_que_empieza_antes(
  rango via rango_que_empieza_antes(),
) {
  let pendiente: Bool = todo @"consigna 3: la propiedad del tiempo"
  pendiente
}

// TODO: para toda firma que no es la del owner, Cancel rechaza.
// Ojo: el generador puede producir justo `owner_hash`; ese caso no cuenta.
test prop_solo_el_owner_recupera(quien via fuzz.bytearray()) {
  let pendiente: Bool = todo @"consigna 3: la propiedad del owner"
  pendiente
}
