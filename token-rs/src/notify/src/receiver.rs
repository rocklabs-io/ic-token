use std::string;

use ic_cdk::export::{Principal};
use ic_cdk::storage;
use ic_cdk::api;
use ic_cdk_macros::*;

use super::TransactionNotification;

#[query(name = "wants_notify")]
fn wants_notify() -> bool {
    true
}

#[update(name = "on_receive_transfer")]
fn on_receive_transfer_() {
    dfn_core::over_async_may_reject(candid_one, transaction_notification)
}

async fn transaction_notification(tn: TransactionNotification) -> Result<string, String> {
    return Ok(tn.from.to_string())
}