use ic_cdk_macros::*;

use crate::TransactionNotification;

#[query(name = "wants_notify")]
fn wants_notify() -> bool {
    true
}

#[update(name = "on_receive_transfer")]
fn on_receive_transfer(tx: TransactionNotification) -> String {
    return tx.from.to_string();
}
