/**
 * Module     : token.rs
 * Copyright  : 2021 DFinance Team
 * License    : Apache 2.0 with LLVM Exception
 * Maintainer : DFinance Team <hello@dfinance.ai>
 * Stability  : Experimental
 */
use ic_cdk::api;
use ic_cdk::export::Principal;
use ic_cdk::storage;
use ic_cdk_macros::*;
use std::{collections::HashMap, convert::TryFrom};

use crate::is_authenticating;

use super::TransactionNotification;

static mut NAME: &str = "";
static mut SYMBOL: &str = "";
static mut DECIMALS: u64 = 8;
static mut OWNER: Principal = Principal::anonymous();
static mut TOTALSUPPLY: u64 = 0;

type Balances = HashMap<Principal, u64>;

#[init]
fn init(name: String, symbol: String, decimals: u64, total_supply: u64) {
    unsafe {
        NAME = Box::leak(name.into_boxed_str());
        SYMBOL = Box::leak(symbol.into_boxed_str());
        DECIMALS = decimals;
        TOTALSUPPLY = total_supply;
        OWNER = api::caller();
        let balances = storage::get_mut::<Balances>();
        balances.insert(OWNER, TOTALSUPPLY);
    }
}

#[update(name = "transfer")]
pub async fn transfer(to: Principal, value: u64) -> bool {
    let from = api::caller();
    if from == to {
        return false;
    }
    //TODO: determine whether "to" is a canister
    let from_balance = balance_of(from);
    api::print(from_balance.to_string());
    if from_balance < value {
        false
    } else {
        let to_balance = balance_of(to);
        let balances = storage::get_mut::<Balances>();
        balances.insert(from, from_balance - value);
        balances.insert(to, to_balance + value);

        if !is_authenticating(&to) {
            let res: Result<(bool,), _> = api::call::call(to, "wants_notify", ()).await;
            match res {
                Ok(ok) => {
                    if ok.0 {
                        let args = TransactionNotification {
                            from,
                            to,
                            amount: value,
                        };

                        let response: Result<(String,), _> =
                            api::call::call(to, "on_receive_transfer", (args,)).await;

                        match response {
                            Ok(bs) => {
                                api::print(String::from("response:") + &bs.0);
                                return true;
                            }
                            Err((_code, err)) => {
                                api::print(err);
                                return false;
                            }
                        }
                    }
                    return true;
                }
                //没有这个方法，或者不是Canister？
                Err((_code, err)) => {
                    api::print(err);
                    return true;
                }
            }
        }
        return true;
    }
}
#[update(name = "mint")]
fn mint(to: Principal, value: u64) -> bool {
    if api::caller() != to {
        false
    } else {
        let balance_before = balance_of(to);
        if balance_before + value >= u64::MAX {
            false
        } else {
            let balances = storage::get_mut::<Balances>();
            balances.insert(to, balance_before + value);
            unsafe {
                TOTALSUPPLY += value;
            }
            true
        }
    }
}

#[update(name = "burn")]
fn burn(from: Principal, value: u64) -> bool {
    if api::caller() != from || api::caller() != owner() {
        false
    } else {
        let balance = balance_of(from);
        if balance < value {
            false
        } else {
            let balances = storage::get_mut::<Balances>();
            balances.insert(from, balance - value);
            unsafe {
                TOTALSUPPLY -= value;
            }
            true
        }
    }
}

#[query(name = "balanceOf")]
fn balance_of(id: Principal) -> u64 {
    let balances = storage::get::<Balances>();
    match balances.get(&id) {
        Some(balance) => *balance,
        None => 0,
    }
}

#[query(name = "name")]
fn name() -> String {
    unsafe { NAME.to_string() }
}

#[query(name = "symbol")]
fn symbol() -> String {
    unsafe { SYMBOL.to_string() }
}

#[query(name = "decimals")]
fn decimals() -> u64 {
    unsafe { DECIMALS }
}

#[query(name = "totalSupply")]
fn total_supply() -> u64 {
    unsafe { TOTALSUPPLY }
}

#[query(name = "owner")]
fn owner() -> Principal {
    unsafe { OWNER }
}

#[query(name = "controller")]
fn controller() -> Principal {
    // TODO: get token canister controller
    Principal::anonymous()
}
