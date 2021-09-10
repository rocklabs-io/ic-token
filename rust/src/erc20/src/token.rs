/**
 * Module     : token.rs
 * Copyright  : 2021 DFinance Team
 * License    : Apache 2.0 with LLVM Exception
 * Maintainer : DFinance Team <hello@dfinance.ai>
 * Stability  : Experimental
 */
use candid::{candid_method, CandidType, Deserialize};
use ic_cdk::{api, export::Principal, storage};
use ic_cdk_macros::*;
use std::collections::HashMap;
use std::string::String;

#[derive(Deserialize, CandidType, Clone)]
pub struct Metadata {
    name: String,
    symbol: String,
    decimals: u8,
    total_supply: u64,
    owner: Principal,
}

impl Default for Metadata {
    fn default() -> Self {
        Metadata {
            name: "".to_string(),
            symbol: "".to_string(),
            decimals: 0u8,
            total_supply: 0u64,
            owner: Principal::anonymous(),
        }
    }
}

type Balances = HashMap<Principal, u64>;
type Allowances = HashMap<Principal, HashMap<Principal, u64>>;

#[derive(Deserialize, CandidType)]
struct UpgradePayload {
    metadata: Metadata,
    balance: Vec<(Principal, u64)>,
    allow: Vec<(Principal, Vec<(Principal, u64)>)>,
}

#[init]
#[candid_method(init)]
fn init(name: String, symbol: String, decimals: u8, total_supply: u64) {
    let metadata = storage::get_mut::<Metadata>();
    metadata.name = name;
    metadata.symbol = symbol;
    metadata.decimals = decimals;
    metadata.total_supply = total_supply;
    metadata.owner = api::caller();
    let balances = storage::get_mut::<Balances>();
    balances.insert(metadata.owner, metadata.total_supply);
}

#[update(name = "transfer")]
#[candid_method(update)]
fn transfer(to: Principal, value: u64) -> bool {
    let from = api::caller();
    if from == to {
        return false;
    }
    let from_balance = balance_of(from);
    api::print(from_balance.to_string());
    if from_balance < value {
        false
    } else {
        let to_balance = balance_of(to);
        let balances = storage::get_mut::<Balances>();
        balances.insert(from, from_balance - value);
        balances.insert(to, to_balance + value);
        true
    }
}

#[update(name = "transferFrom")]
#[candid_method(update, rename = "transferFrom")]
fn transfer_from(from: Principal, to: Principal, value: u64) -> bool {
    let owner = api::caller();
    let from_allowance = allowance(from, owner);
    if from_allowance < value {
        false
    } else {
        let from_balance = balance_of(from);
        let to_balance = balance_of(to);
        if from_balance < value {
            false
        } else {
            let balances = storage::get_mut::<Balances>();
            balances.insert(from, from_balance - value);
            balances.insert(to, to_balance + value);
            let allowances_read = storage::get::<Allowances>();
            match allowances_read.get(&from) {
                Some(inner) => {
                    let result = inner.get(&owner).unwrap();
                    let mut temp = inner.clone();
                    temp.insert(owner, result - value);
                    let allowances = storage::get_mut::<Allowances>();
                    allowances.insert(from, temp);
                }
                None => {
                    assert!(false);
                }
            }
            true
        }
    }
}

#[update(name = "approve")]
#[candid_method(update)]
fn approve(spender: Principal, value: u64) -> bool {
    let owner = api::caller();
    let allowances_read = storage::get::<Allowances>();
    match allowances_read.get(&owner) {
        Some(inner) => {
            let mut temp = inner.clone();
            temp.insert(spender, value);
            let allowances = storage::get_mut::<Allowances>();
            allowances.insert(owner, temp);
        }
        None => {
            let mut inner = HashMap::new();
            inner.insert(spender, value);
            let allowances = storage::get_mut::<Allowances>();
            allowances.insert(owner, inner);
        }
    }
    true
}

#[update(name = "mint")]
#[candid_method(update)]
fn mint(to: Principal, value: u64) -> bool {
    let metadata = storage::get_mut::<Metadata>();
    if api::caller() != metadata.owner {
        false
    } else {
        let balance_before = balance_of(to);
        if balance_before + value >= u64::MAX {
            false
        } else {
            let balances = storage::get_mut::<Balances>();
            balances.insert(to, balance_before + value);
            metadata.total_supply += value;
            true
        }
    }
}

#[update(name = "burn")]
#[candid_method(update)]
fn burn(from: Principal, value: u64) -> bool {
    let metadata = storage::get_mut::<Metadata>();

    if api::caller() != from || api::caller() != metadata.owner {
        false
    } else {
        let balance = balance_of(from);
        if balance < value {
            false
        } else {
            let balances = storage::get_mut::<Balances>();
            balances.insert(from, balance - value);
            metadata.total_supply -= value;
            true
        }
    }
}

#[query(name = "balanceOf")]
#[candid_method(query, rename = "balanceOf")]
fn balance_of(id: Principal) -> u64 {
    let balances = storage::get::<Balances>();
    match balances.get(&id) {
        Some(balance) => *balance,
        None => 0,
    }
}

#[query(name = "allowance")]
#[candid_method(query)]
fn allowance(owner: Principal, spender: Principal) -> u64 {
    let allowances = storage::get::<Allowances>();
    match allowances.get(&owner) {
        Some(inner) => match inner.get(&spender) {
            Some(value) => *value,
            None => 0,
        },
        None => 0,
    }
}

#[query(name = "name")]
#[candid_method(query)]
fn name() -> String {
    let metadata = storage::get::<Metadata>();
    metadata.name.clone()
}

#[query(name = "symbol")]
#[candid_method(query)]
fn symbol() -> String {
    let metadata = storage::get::<Metadata>();
    metadata.symbol.clone()
}

#[query(name = "decimals")]
#[candid_method(query)]
fn decimals() -> u8 {
    let metadata = storage::get::<Metadata>();
    metadata.decimals
}

#[query(name = "totalSupply")]
#[candid_method(query, rename = "totalSupply")]
fn total_supply() -> u64 {
    let metadata = storage::get::<Metadata>();
    metadata.total_supply
}

#[query(name = "owner")]
#[candid_method(query)]
fn owner() -> Principal {
    let metadata = storage::get::<Metadata>();
    metadata.owner
}

// #[query(name = "controller")]
// #[candid_method(query)]
// fn controller() -> Principal {
//     // TODO: get token canister controller
//     Principal::anonymous()
// }

#[cfg(any(target_arch = "wasm32", test))]
fn main() {}

#[cfg(not(any(target_arch = "wasm32", test)))]
fn main() {
    candid::export_service!();
    std::print!("{}", __export_service());
}

#[pre_upgrade]
fn pre_upgrade() {
    let metadata = storage::get::<Metadata>().clone();
    let mut balance = Vec::new();
    let mut allow = Vec::new();
    for (k, v) in storage::get_mut::<Balances>().iter() {
        balance.push((*k, *v));
    }
    for (k, v) in storage::get_mut::<Allowances>().iter() {
        let mut item = Vec::new();
        for (a, b) in v.iter() {
            item.push((*a, *b));
        }
        allow.push((*k, item));
    }

    let up = UpgradePayload {
        metadata,
        balance,
        allow,
    };
    storage::stable_save((up,)).unwrap();
}

#[post_upgrade]
fn post_upgrade() {
    // There can only be one value in stable memory, currently. otherwise, lifetime error.
    // https://docs.rs/ic-cdk/0.3.0/ic_cdk/storage/fn.stable_restore.html
    let (down,): (UpgradePayload,) = storage::stable_restore().unwrap();
    let metadata = storage::get_mut::<Metadata>();
    *metadata = down.metadata;
    for (k, v) in down.balance {
        storage::get_mut::<Balances>().insert(k, v);
    }
    for (k, v) in down.allow {
        let mut inner = HashMap::new();
        for (a, b) in v {
            inner.insert(a, b);
        }
        storage::get_mut::<Allowances>().insert(k, inner);
    }
}
