use candid::CandidType;
use ic_types::{CanisterId, PrincipalId};
use serde::{
    Deserialize, Serialize
};

use std::hash::Hash;

pub mod token;
pub mod receiver;

/// Struct sent by the ledger canister when it notifies a recipient of a payment
#[derive(Serialize, Deserialize, CandidType, Clone, Hash, Debug, PartialEq, Eq)]
pub struct TransactionNotification {
    pub from: PrincipalId,
    pub to: CanisterId,
    pub amount: u64,
}