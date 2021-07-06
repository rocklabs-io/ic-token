use ic_cdk::export::{
    candid::{CandidType, Deserialize},
    Principal,
};
use serde::Serialize;

pub mod receiver;
pub mod token;

#[derive(Clone, Debug, CandidType, Deserialize, Serialize)]
pub struct TransactionNotification {
    pub from: Principal,
    pub to: Principal,
    pub amount: u64,
}

const HASH_LEN_IN_BYTES: usize = 28;
const TYPE_SELF_AUTH: u8 = 0x02;
pub fn is_authenticating(id: &Principal) -> bool {
    let blob = id.as_slice();
    if blob.len() != HASH_LEN_IN_BYTES + 1 {
        return false;
    }
    if blob.last() != Some(&TYPE_SELF_AUTH) {
        return false;
    }
    true
}
