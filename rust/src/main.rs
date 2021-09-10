/**
* Module     : main.rs
* Copyright  : 2021 DFinance Team
* License    : Apache 2.0 with LLVM Exception
* Maintainer : DFinance Team <hello@dfinance.ai>
* Stability  : Experimental
*/

use ic_cdk::{export::Principal, storage, api};
use ic_cdk_macros::*;
use std::collections::HashMap;
use candid::{candid_method, CandidType};
use std::string::String;
use serde::Deserialize;

#[derive(Deserialize, CandidType, Clone)]
pub struct Metadata {
    logo: String,
    name: String,
    symbol: String,
    decimals: u8,
    total_supply: u64,
    mintable: bool,
    burnable: bool,
    owner: Principal,
    fee: u64,
    fee_to: Principal,
}

impl Default for Metadata {
    fn default() -> Self { 
        Metadata {
            logo: "".to_string(),
            name: "".to_string(),
            symbol: "".to_string(),
            decimals: 0u8,
            total_supply: 0u64,
            mintable: false,
            burnable: false,
            owner: Principal::anonymous(),
            fee: 0u64,
            fee_to: Principal::anonymous(),
        }
    }
}

type Balances = HashMap<Principal, u64>;
type Allowances = HashMap<Principal, HashMap<Principal, u64>>;
type Ops = Vec<OpRecord>;

#[derive(Deserialize, CandidType)]
struct UpgradePayload {
    metadata: Metadata,
    balance: Vec<(Principal, u64)>,
    allow: Vec<(Principal, Vec<(Principal, u64)>)>,
}

#[derive(CandidType, Clone, Copy)]
enum Operation {
    Mint, Burn, Transfer, Approve, Init
}

#[derive(CandidType, Clone, Copy)]
struct OpRecord {
    caller: Principal,
    op: Operation,
    index: u64,
    from: Principal,
    to: Principal,
    amount: u64,
    fee: u64,
    timestamp: u64,
}

#[derive(CandidType)]
enum TxError {
    InsufficientBalance,
    InsufficientAllowance,
    Overflow,
    Unauthorized,
}
type TxReceipt = Result<u64, TxError>;

#[derive(CandidType)]
pub struct MetaInfo {
    pub logo: String,
    pub name: String,
    pub symbol: String,
    pub decimals: u8,
    pub total_supply: u64,
    pub mintable: bool,
    pub burnable: bool,
    pub owner: Principal,
    pub history_size: usize,
    pub deploy_time: u64,
    pub fee: u64,
    pub fee_to: Principal,
    pub holder_number: usize,
    pub cycles: u64,
}

fn add_record(caller: Principal, op: Operation, from: Principal, to: Principal,
    amount: u64, fee: u64, timestamp: u64) -> u64
{
    let ops = storage::get_mut::<Ops>();
    let index: u64 = ops.len() as u64;
    ops.push(OpRecord{
        caller, op, index, from, to, amount, fee, timestamp,
    });
    index
}

#[init]
#[candid_method(init)]
fn init(
    logo: String,
    name: String, 
    symbol: String, 
    decimals: u8, 
    total_supply: u64, 
    owner: Principal,
    mintable: bool,
    burnable: bool
    ) {
        let metadata = storage::get_mut::<Metadata>();
        metadata.logo = logo;
        metadata.name = name;
        metadata.symbol = symbol;
        metadata.decimals = decimals;
        metadata.total_supply = total_supply;
        metadata.mintable = mintable;
        metadata.burnable = burnable;
        metadata.owner = owner;
        metadata.fee = 100000;
        metadata.fee_to = owner;
        let balances = storage::get_mut::<Balances>();
        balances.insert(owner, total_supply);
        let _ = add_record(owner, Operation::Init, Principal::from_text("aaaaa-aa").unwrap(), owner, total_supply, 0, api::time());
}

fn _transfer(from: Principal, to: Principal, value: u64) {
    let balances = storage::get_mut::<Balances>();
    let from_balance = balance_of(from);
    let from_balance_new: u64 = from_balance - value;
    if from_balance_new != 0 {
        balances.insert(from, from_balance_new);
    } else {
        balances.remove(&from);
    }
    let to_balance = balance_of(to);
    let to_balance_new: u64 = to_balance + value;
    if to_balance_new != 0 {
        balances.insert(to, to_balance_new);
    }
}

fn _charge_fee(user: Principal, fee_to: Principal, fee: u64) {
    let metadata = storage::get::<Metadata>();
    if metadata.fee > 0 {
        _transfer(user, fee_to, fee);
    }
}

#[update(name = "transfer")]
#[candid_method(update)]
fn transfer(to: Principal, value: u64) -> TxReceipt {
    let from = api::caller();
    let from_balance = balance_of(from);
    let metadata = storage::get::<Metadata>();
    if from_balance < value || from_balance < metadata.fee {
        return Err(TxError::InsufficientBalance);
    } 
    _charge_fee(from, metadata.fee_to, metadata.fee);
    _transfer(from, to, value);
    let txid = add_record(from, Operation::Transfer, from, to, value, metadata.fee, api::time());
    Ok(txid)
}

#[update(name = "transferFrom")]
#[candid_method(update, rename = "transferFrom")]
fn transfer_from(from: Principal, to: Principal, value: u64) -> TxReceipt {
    let owner = api::caller();
    let from_allowance = allowance(from, owner);
    let metadata = storage::get::<Metadata>();
    if from_allowance < value {
        Err(TxError::InsufficientAllowance)
    } else {
        let from_balance = balance_of(from);        
        if from_balance < value || from_balance < metadata.fee {
            return Err(TxError::InsufficientBalance);
        } 
        _charge_fee(from, metadata.fee_to, metadata.fee);
        _transfer(from, to, value);
        let allowances_read = storage::get::<Allowances>();
        match allowances_read.get(&from) {
            Some(inner) => {
                let result = inner.get(&owner).unwrap();
                let mut temp = inner.clone();
                temp.insert(owner, result - value);
                let allowances = storage::get_mut::<Allowances>();
                allowances.insert(from, temp);
            },
            None => {
                assert!(false);
            }
        }
        let txid = add_record(owner, Operation::Transfer, from, to, value, metadata.fee, api::time());
        Ok(txid)
    }
}

#[update(name = "approve")]
#[candid_method(update)]
fn approve(spender: Principal, value: u64) -> TxReceipt {
    let owner = api::caller();
    let metadata = storage::get::<Metadata>();
    if balance_of(owner) < metadata.fee {
        return Err(TxError::InsufficientBalance);
    }
    _charge_fee(owner, metadata.fee_to, metadata.fee);
    let allowances_read = storage::get::<Allowances>();
    match allowances_read.get(&owner) {
        Some(inner) => {
            let mut temp = inner.clone();
            temp.insert(spender, value);
            let allowances = storage::get_mut::<Allowances>();
            allowances.insert(owner, temp);
        },
        None => {
            let mut inner = HashMap::new();
            inner.insert(spender, value);
            let allowances = storage::get_mut::<Allowances>();
            allowances.insert(owner, inner);
        }
    }
    let txid = add_record(owner, Operation::Approve, owner, spender, value, metadata.fee, api::time());
    Ok(txid)
}

#[update(name = "mint")]
#[candid_method(update)]
fn mint(to: Principal, value: u64) -> TxReceipt {
    let metadata = storage::get_mut::<Metadata>();
    if !metadata.mintable || api::caller() != owner() {
        return Err(TxError::Unauthorized);
    }    
    let balance_before = balance_of(to);
    if balance_before + value >= u64::MAX {
        Err(TxError::Overflow)
    } else {
        let balances = storage::get_mut::<Balances>();
        balances.insert(to, balance_before + value);
        metadata.total_supply += value;
        let txid = add_record(api::caller(), Operation::Mint, Principal::from_text("aaaaa-aa").unwrap(), to, value, 0, api::time());    
        Ok(txid)
    }
}

#[update(name = "burn")]
#[candid_method(update)]
fn burn(from: Principal, value: u64) -> TxReceipt {
    let metadata = storage::get_mut::<Metadata>();
    if !metadata.burnable || (api::caller() != from && api::caller() != owner()) {
        return Err(TxError::Unauthorized);
    }
    let balance = balance_of(from);
    if balance < value {
        Err(TxError::InsufficientBalance)
    } else {
        let balances = storage::get_mut::<Balances>();
        balances.insert(from, balance - value);
        metadata.total_supply -= value;
        let txid = add_record(api::caller(), Operation::Burn, from, Principal::from_text("aaaaa-aa").unwrap(), value, 0, api::time());
        Ok(txid)
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
        Some(inner) => {
            match inner.get(&spender) {
                Some(value) => *value,
                None => 0,
            }
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

#[query(name = "getTransaction")]
#[candid_method(query, rename = "getTransaction")]
fn get_transaction(index: usize) -> OpRecord {
    let ops = storage::get::<Ops>();
    ops[index]
}

#[query(name = "allTransactions")]
#[candid_method(query, rename = "allTransactions")]
fn all_transactions() -> Vec<OpRecord> {
    storage::get::<Ops>().to_vec()
}

#[query(name = "getTransactions")]
#[candid_method(query, rename = "getTransactions")]
fn get_transactions(start: usize, num: usize) -> Vec<OpRecord> {
    let mut res : Vec<OpRecord> = Vec::new();
    let ops = storage::get::<Ops>();
    let mut i = start;
    while i < start + num && i < ops.len() {
        res.push(ops[i]);
        i += 1;
    }
    res
}

#[query(name = "getTxsByAccount")]
#[candid_method(query, rename = "getTxsByAccount")]
fn get_txs_by_account(a: Principal) -> Vec<OpRecord> {
    let ops = storage::get::<Ops>();
    let mut res : Vec<OpRecord> = Vec::new();
    for i in ops {
        if i.caller == a || i.from == a || i.to == a {
            res.push(*i);
        }
    }
    res
}

#[query(name = "getMetaInfo")]
#[candid_method(query, rename = "getMetaInfo")]
fn get_meta_info() -> MetaInfo {
    let metadata = storage::get::<Metadata>();
    let ops = storage::get::<Ops>();
    let balance = storage::get::<Balances>();
    return MetaInfo {
        logo: metadata.logo.clone(),
        name: metadata.name.clone(),
        symbol: metadata.symbol.clone(),
        decimals: metadata.decimals,
        total_supply: metadata.total_supply,
        mintable: metadata.mintable,
        burnable: metadata.burnable,
        owner: metadata.owner,
        history_size: ops.len(),
        deploy_time: ops[0].timestamp,
        fee: metadata.fee,
        fee_to: metadata.fee_to,
        holder_number: balance.len(),
        cycles: api::canister_balance(),
    };
}

#[query(name = "getLogo")]
#[candid_method(query, rename = "getLogo")]
fn get_logo() -> String {
    let metadata = storage::get::<Metadata>();
    metadata.logo.clone()
}

#[query(name = "setLogo")]
#[candid_method(query, rename = "setLogo")]
fn set_logo(logo: String) -> bool {
    let metadata = storage::get_mut::<Metadata>();
    metadata.logo = logo;
    return true;
}

#[query(name = "setFee")]
#[candid_method(query, rename = "setFee")]
fn set_fee(fee: u64) -> bool {
    let metadata = storage::get_mut::<Metadata>();
    if api::caller() != metadata.owner {
        return false;
    }
    metadata.fee = fee;
    return true;
}

#[query(name = "setFeeTo")]
#[candid_method(query, rename = "setFeeTo")]
fn set_fee_to(fee_to: Principal) -> bool {
    let metadata = storage::get_mut::<Metadata>();
    if api::caller() != owner() {
        return false;
    }
    metadata.fee_to = fee_to;
    return true;
}

#[cfg(any(target_arch = "wasm32", test))]
fn main() {}

#[cfg(not(any(target_arch = "wasm32", test)))]
fn main() {
    candid::export_service!();
    std::print!("{}", __export_service());
}

// TODO: fix upgrade functions
#[pre_upgrade]
fn pre_upgrade() {
    let metadata = storage::get::<Metadata>().clone();
    let mut balance = Vec::new();
    // let mut allow: Vec<(Principal, Vec<(Principal, u64)>)> = Vec::new();
    let mut allow = Vec::new();
    for (k, v) in storage::get::<Balances>().iter() {
        balance.push((*k, *v));
    }
    for (k, v) in storage::get::<Allowances>().iter() {
        let mut item = Vec::new();
        for (a, b) in v.iter() {
            item.push((*a, *b));
        }
        allow.push((*k, item));
    }
    let up = UpgradePayload {
        metadata, balance, allow,
    };
    storage::stable_save((up, )).unwrap();
}

#[post_upgrade]
fn post_upgrade() {
    // There can only be one value in stable memory, currently. otherwise, lifetime error.
    // https://docs.rs/ic-cdk/0.3.0/ic_cdk/storage/fn.stable_restore.html
    let (down, ) : (UpgradePayload, ) = storage::stable_restore().unwrap();
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