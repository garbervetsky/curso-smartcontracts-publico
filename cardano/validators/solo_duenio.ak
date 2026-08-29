//// Validator mínimo: "solo el dueño gasta".
////
//// Es el ejemplo de la Clase 4 — el validator más chico que sigue siendo útil.
//// Cualquier UTXO bloqueado en esta dirección solo puede gastarlo quien tenga la
//// clave privada correspondiente al hash guardado en el datum.
////
//// Comparado con `escrow.ak`, que es el que se construye en el taller, acá no hay
//// redeemer, ni deadline, ni dos caminos de salida: una sola condición, una línea.
//// Sirve para ver la forma de un validator sin la lógica del escrow encima.

use aiken/collection/list
use cardano/transaction.{OutputReference, Transaction}

/// El dato que se pega al UTXO al depositar. Lo elige **quien deposita**: el
/// validator no interviene en el LOCK, solo en el UNLOCK.
pub type Datum {
  /// Hash de la clave pública del dueño (el mismo formato que
  /// `extra_signatories` de la transacción).
  owner: ByteArray,
}

validator solo_duenio {
  spend(
    datum: Option<Datum>,
    _redeemer: Void,
    // no hace falta que el gastador aporte nada
    _utxo: OutputReference,
    tx: Transaction,
  ) {
    expect Some(d) = datum
    list.has(tx.extra_signatories, d.owner)
  }

  // los otros tres propósitos (mint, withdraw, publish) se rechazan
  else(_) {
    fail
  }
}
