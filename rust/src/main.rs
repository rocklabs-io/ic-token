/**
* Module     : main.rs
* Copyright  : 2021 DFinance Team
* License    : Apache 2.0 with LLVM Exception
* Maintainer : DFinance Team <hello@dfinance.ai>
* Stability  : Experimental
*/
use candid::{candid_method, CandidType, Deserialize};
use ic_kit::{ic , Principal};
use ic_cdk_macros::*;
use std::collections::HashMap;
use std::iter::FromIterator;
use std::string::String;

#[derive(Deserialize, CandidType, Clone, Debug)]
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

#[derive(Deserialize, CandidType, Clone, Debug)]
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

#[derive(CandidType, Clone, Copy, Debug, PartialEq)]
enum Operation {
    Mint,
    Transfer,
    TransferFrom,
    Approve,
}

#[derive(CandidType, Clone, Debug)]
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

#[derive(CandidType, Debug, PartialEq)]
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
    let ops = ic::get_mut::<Ops>();
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
    let metadata = ic::get_mut::<Metadata>();
    metadata.logo = logo;
    metadata.name = name;
    metadata.symbol = symbol;
    metadata.decimals = decimals;
    metadata.total_supply = total_supply;
    metadata.owner = owner;
    metadata.fee = fee;
    let balances = ic::get_mut::<Balances>();
    balances.insert(owner, total_supply);
    let _ = add_record(
        Some(owner),
        Operation::Mint,
        Principal::from_text("aaaaa-aa").unwrap(),
        owner,
        total_supply,
        0,
        ic::time(),
    );
}

fn _transfer(from: Principal, to: Principal, value: u64) {
    let balances = ic::get_mut::<Balances>();
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
    let metadata = ic::get::<Metadata>();
    if metadata.fee > 0 {
        _transfer(user, fee_to, fee);
    }
}

#[update(name = "transfer")]
#[candid_method(update)]
fn transfer(to: Principal, value: u64) -> TxReceipt {
    let from = ic::caller();
    let metadata = ic::get::<Metadata>();
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
        ic::time(),
    );
    Ok(txid)
}

#[update(name = "transferFrom")]
#[candid_method(update, rename = "transferFrom")]
fn transfer_from(from: Principal, to: Principal, value: u64) -> TxReceipt {
    let owner = ic::caller();
    let from_allowance = allowance(from, owner);
    let metadata = ic::get::<Metadata>();
    if from_allowance < value + metadata.fee {
        return Err(TxError::InsufficientAllowance);
    } 
    let from_balance = balance_of(from);
    if from_balance < value + metadata.fee {
        return Err(TxError::InsufficientBalance);
    }
    _charge_fee(from, metadata.fee_to, metadata.fee);
    _transfer(from, to, value);
    let allowances = ic::get_mut::<Allowances>();
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
        ic::time(),
    );
    Ok(txid)
}

#[update(name = "approve")]
#[candid_method(update)]
fn approve(spender: Principal, value: u64) -> TxReceipt {
    let owner = ic::caller();
    let metadata = ic::get::<Metadata>();
    if balance_of(owner) < metadata.fee {
        return Err(TxError::InsufficientBalance);
    }
    _charge_fee(owner, metadata.fee_to, metadata.fee);
    let v = value + metadata.fee;
    let allowances = ic::get_mut::<Allowances>();
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
                let allowances = ic::get_mut::<Allowances>();
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
        ic::time(),
    );
    Ok(txid)
}

#[update(name = "setLogo")]
#[candid_method(update, rename = "setLogo")]
fn set_logo(logo: String) {
    let metadata = ic::get_mut::<Metadata>();
    assert_eq!(ic::caller(), metadata.owner);
    metadata.logo = logo;
}

#[update(name = "setFee")]
#[candid_method(update, rename = "setFee")]
fn set_fee(fee: u64) {
    let metadata = ic::get_mut::<Metadata>();
    assert_eq!(ic::caller(), metadata.owner);
    metadata.fee = fee;
}

#[update(name = "setFeeTo")]
#[candid_method(update, rename = "setFeeTo")]
fn set_fee_to(fee_to: Principal) {
    let metadata = ic::get_mut::<Metadata>();
    assert_eq!(ic::caller(), metadata.owner);
    metadata.fee_to = fee_to;
}

#[update(name = "setOwner")]
#[candid_method(update, rename = "setOwner")]
fn set_owner(owner: Principal) {
    let metadata = ic::get_mut::<Metadata>();
    assert_eq!(ic::caller(), metadata.owner);
    metadata.owner = owner;
}

#[query(name = "balanceOf")]
#[candid_method(query, rename = "balanceOf")]
fn balance_of(id: Principal) -> u64 {
    let balances = ic::get::<Balances>();
    match balances.get(&id) {
        Some(balance) => *balance,
        None => 0,
    }
}

#[query(name = "allowance")]
#[candid_method(query)]
fn allowance(owner: Principal, spender: Principal) -> u64 {
    let allowances = ic::get::<Allowances>();
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
    let metadata = ic::get::<Metadata>();
    metadata.logo.clone()
}

#[query(name = "name")]
#[candid_method(query)]
fn name() -> String {
    let metadata = ic::get::<Metadata>();
    metadata.name.clone()
}

#[query(name = "symbol")]
#[candid_method(query)]
fn symbol() -> String {
    let metadata = ic::get::<Metadata>();
    metadata.symbol.clone()
}

#[query(name = "decimals")]
#[candid_method(query)]
fn decimals() -> u8 {
    let metadata = ic::get::<Metadata>();
    metadata.decimals
}

#[query(name = "totalSupply")]
#[candid_method(query, rename = "totalSupply")]
fn total_supply() -> u64 {
    let metadata = ic::get::<Metadata>();
    metadata.total_supply
}

#[query(name = "owner")]
#[candid_method(query)]
fn owner() -> Principal {
    let metadata = ic::get::<Metadata>();
    metadata.owner
}

#[query(name = "getMetadta")]
#[candid_method(query, rename = "getMetadta")]
fn get_metadata() -> Metadata {
    ic::get::<Metadata>().clone()
}

#[query(name = "historySize")]
#[candid_method(query, rename = "historySize")]
fn history_size() -> usize {
    let ops = ic::get::<Ops>();
    ops.len()
}

#[query(name = "getTransaction")]
#[candid_method(query, rename = "getTransaction")]
fn get_transaction(index: usize) -> OpRecord {
    let ops = ic::get::<Ops>();
    ops[index].clone()
}

#[query(name = "getTransactions")]
#[candid_method(query, rename = "getTransactions")]
fn get_transactions(start: usize, limit: usize) -> Vec<OpRecord> {
    let mut ret: Vec<OpRecord> = Vec::new();
    let ops = ic::get::<Ops>();
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
    let ops = ic::get::<Ops>();
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
    let ops = ic::get::<Ops>();
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
    let metadata = ic::get::<Metadata>().clone();
    let ops = ic::get::<Ops>();
    let balance = ic::get::<Balances>();

    return TokenInfo {
        metadata: metadata.clone(),
        fee_to: metadata.fee_to,
        history_size: ops.len(),
        deploy_time: ops[0].timestamp,
        holder_number: balance.len(),
        cycles: ic::balance(),
    };
}

#[query(name = "getHolders")]
#[candid_method(query, rename = "getHolders")]
fn get_holders(start: usize, limit: usize) -> Vec<(Principal, u64)> {
    let mut balance = Vec::new();
    for (&k, &v) in ic::get::<Balances>().iter() {
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
    let allowances = ic::get::<Allowances>();
    for (_, v) in allowances.iter() {
        size += v.len();
    }
    size
}

#[query(name = "getUserApprovals")]
#[candid_method(query, rename = "getUserApprovals")]
fn get_user_approvals(who: Principal) -> Vec<(Principal, u64)> {
    let allowances = ic::get::<Allowances>();
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
    let metadata = ic::get::<Metadata>().clone();
    let mut balance = Vec::new();
    // let mut allow: Vec<(Principal, Vec<(Principal, u64)>)> = Vec::new();
    let mut allow = Vec::new();
    for (&k, &v) in ic::get::<Balances>().iter() {
        balance.push((k, v));
    }
    for (k, v) in ic::get::<Allowances>().iter() {
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
    ic::stable_store((up,)).unwrap();
}

#[post_upgrade]
fn post_upgrade() {
    // There can only be one value in stable memory, currently. otherwise, lifetime error.
    // https://docs.rs/ic-cdk/0.3.0/ic_cdk/storage/fn.stable_restore.html
    let (down,): (UpgradePayload,) = ic::stable_restore().unwrap();
    let metadata = ic::get_mut::<Metadata>();
    *metadata = down.metadata;
    for (k, v) in down.balance {
        ic::get_mut::<Balances>().insert(k, v);
    }
    for (k, v) in down.allow {
        let mut inner = HashMap::new();
        for (a, b) in v {
            inner.insert(a, b);
        }
        ic::get_mut::<Allowances>().insert(k, inner);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use ic_kit::{mock_principals::{alice, bob, john}, MockContext};
    use assert_panic::assert_panic;

    fn initialize_tests() {
      init(
        String::from("logo"),
        String::from("token"),
        String::from("TOKEN"),
        2,
        1_000,
        alice(),
        1,
      );
    }

    #[test]
    fn functionality_test() {
      MockContext::new()
      .with_balance(100_000)
      .with_caller(alice())
      .inject();

      initialize_tests();

      // initialization tests
      assert_eq!(balance_of(alice()), 1_000, "balanceOf did not return the correct value");
      assert_eq!(total_supply(), 1_000, "totalSupply did not return the correct value");
      assert_eq!(symbol(), String::from("TOKEN"), "symbol did not return the correct value");
      assert_eq!(owner(), alice(), "owner did not return the correct value");
      assert_eq!(name(), String::from("token"), "name did not return the correct value");
      assert_eq!(get_logo(), String::from("logo"), "getLogo did not return the correct value");
      assert_eq!(decimals(), 2, "decimals did not return the correct value");
      assert_eq!(get_holders(0, 10).len(), 1, "get_holders returned the correct amount of holders after initialization");
      assert_eq!(get_transaction(0).op, Operation::Mint, "get_transaction returnded a Mint operation");

      let token_info = get_token_info();
      assert_eq!(token_info.fee_to, Principal::anonymous(), "tokenInfo.fee_to did not return the correct value");
      assert_eq!(token_info.history_size, 1, "tokenInfo.history_size did not return the correct value");
      assert!(token_info.deploy_time > 0, "tokenInfo.deploy_time did not return the correct value");
      assert_eq!(token_info.holder_number, 1, "tokenInfo.holder_number did not return the correct value");
      assert_eq!(token_info.cycles, 100_000, "tokenInfo.cycles did not return the correct value");

      let metadata = get_metadata();
      assert_eq!(metadata.total_supply, 1_000, "metadata.total_supply did not return the correct value");
      assert_eq!(metadata.symbol, String::from("TOKEN"), "metadata.symbol did not return the correct value");
      // assert_eq!(metadata.owner, alice(), "metadata.owner did not return the correct value");
      assert_eq!(metadata.name, String::from("token"), "metadata.name did not return the correct value");
      assert_eq!(metadata.logo, String::from("logo"), "metadata.logo did not return the correct value");
      assert_eq!(metadata.decimals, 2, "metadata.decimals did not return the correct value");
      assert_eq!(metadata.fee, 1, "metadata.fee did not return the correct value");
      assert_eq!(metadata.fee_to, Principal::anonymous(), "metadata.fee_to did not return the correct value");

      // set fee test
      set_fee(2);
      assert_eq!(2, get_metadata().fee ,"Failed to update the fee_to");

      // set fee_to test
      set_fee_to(john());
      assert_eq!(john(), get_metadata().fee_to, "Failed to set fee");
      set_fee_to(Principal::anonymous());

      // set logo
      set_logo(String::from("new_logo"));
      assert_eq!("new_logo", get_logo());

      // test transfers
      let transfer_alice_balance_expected = balance_of(alice()) - 10 - get_metadata().fee;
      let transfer_bob_balance_expected = balance_of(bob()) + 10;
      let transfer_john_balance_expected = balance_of(john());
      let transfer_transaction_amount_expected = get_transactions(0, 10).len() + 1;
      let transfer_user_transaction_amount_expected = get_user_transaction_amount(alice()) + 1;
      transfer(bob(), 10).map_err(|err| println!("{:?}", err)).ok();

      assert_eq!(balance_of(alice()), transfer_alice_balance_expected, "Transfer did not transfer the expected amount to Alice");
      assert_eq!(balance_of(bob()), transfer_bob_balance_expected, "Transfer did not transfer the expected amount to Bob");
      assert_eq!(balance_of(john()), transfer_john_balance_expected, "Transfer did not transfer the expected amount to John");
      assert_eq!(get_transactions(0, 10).len(), transfer_transaction_amount_expected, "transfer operation did not produce a transaction");
      assert_eq!(get_user_transaction_amount(alice()), transfer_user_transaction_amount_expected, "get_user_transaction_amount returned the wrong value after a transfer");
      assert_eq!(get_user_transactions(alice(), 0, 10).len(), transfer_user_transaction_amount_expected, "get_user_transactions returned the wrong value after a transfer");
      assert_eq!(get_holders(0, 10).len(), 3, "get_holders returned the correct amount of holders after transfer");
      assert_eq!(get_transaction(1).op, Operation::Transfer, "get_transaction returnded a Transfer operation");

      // test allowances
      approve(bob(), 100).map_err(|err| println!("{:?}", err)).ok();
      assert_eq!(allowance(alice(), bob()), 100 + get_metadata().fee, "Approve did not give the correct allowance");
      assert_eq!(get_allowance_size(), 1, "getAllowanceSize returns the correct value");
      assert_eq!(get_user_approvals(alice()).len(), 1, "getUserApprovals not returning the correct value");

      // test transfer_from
      // inserting an allowance of Alice for Bob's balance to test transfer_from
      let allowances = ic::get_mut::<Allowances>();
      let mut inner = HashMap::new();
      inner.insert(alice(), 5 + get_metadata().fee);
      allowances.insert(bob(), inner);

      let transfer_from_alice_balance_expected = balance_of(alice());
      let transfer_from_bob_balance_expected = balance_of(bob()) - 5 - get_metadata().fee;
      let transfer_from_john_balance_expected = balance_of(john()) + 5;
      let transfer_from_transaction_amount_expected = get_transactions(0, 10).len() + 1;

      transfer_from(bob(), john(), 5).map_err(|err| println!("{:?}", err)).ok();

      assert_eq!(balance_of(alice()), transfer_from_alice_balance_expected, "transfer_from transferred the correct value for alice");
      assert_eq!(balance_of(bob()), transfer_from_bob_balance_expected, "transfer_from transferred the correct value for bob");
      assert_eq!(balance_of(john()), transfer_from_john_balance_expected, "transfer_from transferred the correct value for john");
      assert_eq!(allowance(bob(), alice()), 0, "allowance has not been spent");
      assert_eq!(get_transactions(0, 10).len(), transfer_from_transaction_amount_expected, "transfer_from operation did not produce a transaction");

      // Transferring more than the balance
      assert_eq!(transfer(alice(), 1_000_000), Err(TxError::InsufficientBalance) , "alice was able to transfer more than is allowed");
      // Transferring more than the balance
      assert_eq!(transfer_from(bob(), john(), 1_000_000), Err(TxError::InsufficientAllowance) , "alice was able to transfer more than is allowed");

      //set owner test
      set_owner(bob());
      assert_eq!(bob(), owner(), "Failed to set new owner");
    }

    #[test]
    fn permission_tests() {
      MockContext::new()
      .with_balance(100_000)
      .with_caller(bob())
      .inject();

      initialize_tests();

      assert_panic!(set_logo(String::from("forbidden")));
      assert_panic!(set_fee(123));
      assert_panic!(set_fee_to(john()));
      assert_panic!(set_owner(bob()));
    }
}
