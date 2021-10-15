/**
* Module     : main.rs
* Copyright  : 2021 DFinance Team
* License    : Apache 2.0 with LLVM Exception
* Maintainer : DFinance Team <hello@dfinance.ai>
* Stability  : Experimental
*/
use candid::{candid_method, CandidType, Deserialize};
use ic_cdk::{api, export::Principal, storage};
use ic_cdk_macros::*;
use std::collections::HashMap;
use std::iter::FromIterator;
use std::string::String;

#[derive(Deserialize, CandidType, Clone)]
struct Metadata {
    logo: String,
    name: String,
    symbol: String,
    decimals: u8,
    total_supply: u64,
    owner: Principal,
    fee: u64,
    fee_to: Principal,
}

#[derive(Deserialize, CandidType, Clone)]
struct TokenInfo {
    metadata: Metadata,
    fee_to: Principal,
    // status info
    history_size: usize,
    deploy_time: u64,
    holder_number: usize,
    cycles: u64,
}

impl Default for Metadata {
    fn default() -> Self {
        Metadata {
            logo: "".to_string(),
            name: "".to_string(),
            symbol: "".to_string(),
            decimals: 0u8,
            total_supply: 0,
            owner: Principal::anonymous(),
            fee: 0,
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
    Mint,
    Transfer,
    TransferFrom,
    Approve,
}

#[derive(CandidType, Clone)]
struct OpRecord {
    caller: Option<Principal>,
    op: Operation,
    index: usize,
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
}
type TxReceipt = Result<usize, TxError>;

fn add_record(
    caller: Option<Principal>,
    op: Operation,
    from: Principal,
    to: Principal,
    amount: u64,
    fee: u64,
    timestamp: u64,
) -> usize {
    let ops = storage::get_mut::<Ops>();
    let index = ops.len();
    ops.push(OpRecord {
        caller,
        op,
        index,
        from,
        to,
        amount,
        fee,
        timestamp,
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
    fee: u64,
) {
    let metadata = storage::get_mut::<Metadata>();
    metadata.logo = logo;
    metadata.name = name;
    metadata.symbol = symbol;
    metadata.decimals = decimals;
    metadata.total_supply = total_supply;
    metadata.owner = owner;
    metadata.fee = fee;
    let balances = storage::get_mut::<Balances>();
    balances.insert(owner, total_supply);
    let _ = add_record(
        Some(owner),
        Operation::Mint,
        Principal::from_text("aaaaa-aa").unwrap(),
        owner,
        total_supply,
        0,
        api::time(),
    );
}

fn _transfer(from: Principal, to: Principal, value: u64) {
    let balances = storage::get_mut::<Balances>();
    let from_balance = balance_of(from);
    let from_balance_new = from_balance - value;
    if from_balance_new != 0 {
        balances.insert(from, from_balance_new);
    } else {
        balances.remove(&from);
    }
    let to_balance = balance_of(to);
    let to_balance_new = to_balance + value;
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
    let metadata = storage::get::<Metadata>();
    if balance_of(from) < value + metadata.fee {
        return Err(TxError::InsufficientBalance);
    }
    _charge_fee(from, metadata.fee_to, metadata.fee);
    _transfer(from, to, value);
    let txid = add_record(
        None,
        Operation::Transfer,
        from,
        to,
        value,
        metadata.fee,
        api::time(),
    );
    Ok(txid)
}

#[update(name = "transferFrom")]
#[candid_method(update, rename = "transferFrom")]
fn transfer_from(from: Principal, to: Principal, value: u64) -> TxReceipt {
    let owner = api::caller();
    let from_allowance = allowance(from, owner);
    let metadata = storage::get::<Metadata>();
    if from_allowance < value + metadata.fee {
        return Err(TxError::InsufficientAllowance);
    } 
    let from_balance = balance_of(from);
    if from_balance < value + metadata.fee {
        return Err(TxError::InsufficientBalance);
    }
    _charge_fee(from, metadata.fee_to, metadata.fee);
    _transfer(from, to, value);
    let allowances = storage::get_mut::<Allowances>();
    match allowances.get(&from) {
        Some(inner) => {
            let result = inner.get(&owner).unwrap().clone();
            let mut temp = inner.clone();
            if result - value - metadata.fee != 0 {
                temp.insert(owner, result - value - metadata.fee);
                allowances.insert(from, temp);
            } else {
                temp.remove(&owner);
                if temp.len() == 0 {
                    allowances.remove(&from);
                } else {
                    allowances.insert(from, temp);
                }
            }
        }
        None => {
            assert!(false);
        }
    }
    let txid = add_record(
        Some(owner),
        Operation::TransferFrom,
        from,
        to,
        value,
        metadata.fee,
        api::time(),
    );
    Ok(txid)
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
    let v = value + metadata.fee;
    let allowances = storage::get_mut::<Allowances>();
    match allowances.get(&owner) {
        Some(inner) => {
            let mut temp = inner.clone();
            if v != 0 {
                temp.insert(spender, v);
                allowances.insert(owner, temp);
            } else {
                temp.remove(&spender);
                if temp.len() == 0 {
                    allowances.remove(&owner);
                } else {
                    allowances.insert(owner, temp);
                }
            }
        }
        None => {
            if v != 0 {
                let mut inner = HashMap::new();
                inner.insert(spender, v);
                let allowances = storage::get_mut::<Allowances>();
                allowances.insert(owner, inner);
            }
        }
    }
    let txid = add_record(
        None,
        Operation::Approve,
        owner,
        spender,
        v,
        metadata.fee,
        api::time(),
    );
    Ok(txid)
}

#[update(name = "setLogo")]
#[candid_method(update, rename = "setLogo")]
fn set_logo(logo: String) {
    let metadata = storage::get_mut::<Metadata>();
    assert_eq!(api::caller(), metadata.owner);
    metadata.logo = logo;
}

#[update(name = "setFee")]
#[candid_method(update, rename = "setFee")]
fn set_fee(fee: u64) {
    let metadata = storage::get_mut::<Metadata>();
    assert_eq!(api::caller(), metadata.owner);
    metadata.fee = fee;
}

#[update(name = "setFeeTo")]
#[candid_method(update, rename = "setFeeTo")]
fn set_fee_to(fee_to: Principal) {
    let metadata = storage::get_mut::<Metadata>();
    assert_eq!(api::caller(), metadata.owner);
    metadata.fee_to = fee_to;
}

#[update(name = "setOwner")]
#[candid_method(update, rename = "setOwner")]
fn set_owner(owner: Principal) {
    let metadata = storage::get_mut::<Metadata>();
    assert_eq!(api::caller(), metadata.owner);
    metadata.owner = owner;
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

#[query(name = "getLogo")]
#[candid_method(query, rename = "getLogo")]
fn get_logo() -> String {
    let metadata = storage::get::<Metadata>();
    metadata.logo.clone()
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

#[query(name = "getMetadta")]
#[candid_method(query, rename = "getMetadta")]
fn get_metadata() -> Metadata {
    storage::get::<Metadata>().clone()
}

#[query(name = "historySize")]
#[candid_method(query, rename = "historySize")]
fn history_size() -> usize {
    let ops = storage::get::<Ops>();
    ops.len()
}

#[query(name = "getTransaction")]
#[candid_method(query, rename = "getTransaction")]
fn get_transaction(index: usize) -> OpRecord {
    let ops = storage::get::<Ops>();
    ops[index].clone()
}

#[query(name = "getTransactions")]
#[candid_method(query, rename = "getTransactions")]
fn get_transactions(start: usize, limit: usize) -> Vec<OpRecord> {
    let mut ret: Vec<OpRecord> = Vec::new();
    let ops = storage::get::<Ops>();
    let mut i = start;
    while i < start + limit && i < ops.len() {
        ret.push(ops[i].clone());
        i += 1;
    }
    ret
}

#[query(name = "getUserTransactionAmount")]
#[candid_method(query, rename = "getUserTransactionAmount")]
fn get_user_transaction_amount(a: Principal) -> usize {
    let mut res = 0;
    let ops = storage::get::<Ops>();
    for i in ops.clone() {
        if i.caller == Some(a) || i.from == a || i.to == a {
            res += 1;
        }
    }
    res
}

#[query(name = "getUserTransactions")]
#[candid_method(query, rename = "getUserTransactions")]
fn get_user_transactions(a: Principal, start: usize, limit: usize) -> Vec<OpRecord> {
    let ops = storage::get::<Ops>();
    let mut res: Vec<OpRecord> = Vec::new();
    let mut index: usize = 0;
    for i in ops.clone() {
        if i.caller == Some(a) || i.from == a || i.to == a {
            if index >= start && index < start + limit {
                res.push(i);
            }
            index += 1;
        }
    }
    res
}

#[query(name = "getTokenInfo")]
#[candid_method(query, rename = "getTokenInfo")]
fn get_token_info() -> TokenInfo {
    let metadata = storage::get::<Metadata>().clone();
    let ops = storage::get::<Ops>();
    let balance = storage::get::<Balances>();

    return TokenInfo {
        metadata: metadata.clone(),
        fee_to: metadata.fee_to,
        history_size: ops.len(),
        deploy_time: ops[0].timestamp,
        holder_number: balance.len(),
        cycles: api::canister_balance(),
    };
}

#[query(name = "getHolders")]
#[candid_method(query, rename = "getHolders")]
fn get_holders(start: usize, limit: usize) -> Vec<(Principal, u64)> {
    let mut balance = Vec::new();
    for (&k, &v) in storage::get::<Balances>().iter() {
        balance.push((k, v));
    }
    balance.sort_by(|a, b| b.1.cmp(&a.1));
    let limit: usize = if start + limit > balance.len() {
        balance.len() - start
    } else {
        limit
    };
    balance[start..start + limit].to_vec()
}

#[query(name = "getAllowanceSize")]
#[candid_method(query, rename = "getAllowanceSize")]
fn get_allowance_size() -> usize {
    let mut size = 0;
    let allowances = storage::get::<Allowances>();
    for (_, v) in allowances.iter() {
        size += v.len();
    }
    size
}

#[query(name = "getUserApprovals")]
#[candid_method(query, rename = "getUserApprovals")]
fn get_user_approvals(who: Principal) -> Vec<(Principal, u64)> {
    let allowances = storage::get::<Allowances>();
    match allowances.get(&who) {
        Some(allow) => return Vec::from_iter(allow.clone().into_iter()),
        None => return Vec::new(),
    }
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
    for (&k, &v) in storage::get::<Balances>().iter() {
        balance.push((k, v));
    }
    for (k, v) in storage::get::<Allowances>().iter() {
        let mut item = Vec::new();
        for (&a, &b) in v.iter() {
            item.push((a, b));
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
