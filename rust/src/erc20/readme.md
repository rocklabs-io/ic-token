
# ERC20 style token canister template for the IC

Simple ERC20 style token canister in rust, only implemented the most basic token functions.

## content
- [ERC20 style token canister template for the IC](#erc20-style-token-canister-template-for-the-ic)
  - [content](#content)
  - [Documents](#documents)
    - [Methods](#methods)
      - [ERC20](#erc20)
      - [Other](#other)

## Documents
### Methods
#### ERC20
**Rust methods**
```rs
fn name() -> String 
fn symbol() -> String 
fn decimals() -> u64
fn total_supply() -> u64
fn balance_of(id: Principal) -> u64 
fn allowance(owner: Principal, spender: Principal) -> u64 
fn transfer(to: Principal, value: u64) -> bool 
fn transfer_from(from: Principal, to: Principal, value: u64) -> bool 
fn approve(spender: Principal, value: u64) -> bool
```

**Candid interface**
```did
name : () -> (text) query;
symbol : () -> (text) query;
decimals : () -> (nat64) query;
totalSupply : () -> (nat64) query;
balanceOf : (principal) -> (nat64) query;
allowance : (principal, principal) -> (nat64) query;
transfer : (principal, nat64) -> (bool);
transferFrom : (principal, principal, nat64) -> (bool);
approve : (principal, nat64) -> (bool);
```

**name**
Returns the name of the token - e.g. "MyToken".

```rs
fn name() -> String 
```

**symbol**
Returns the symbol of the token. E.g. “MT”.

```rs
fn symbol() -> String 
```

**decimals**
Returns the number of decimals the token uses - e.g. 8, means to divide the token amount by 100000000 to get its user representation.

```rs
fn decimals() -> u64
```

**totalSupply**
Returns the total token supply.

```rs
fn total_supply() -> u64
```

**balanceOf**
Returns the account balance of another account with Principal `id`.

```rs
fn balance_of(id: Principal) -> u64 
```

**allowance**
Returns the amount which `spender` is still allowed to withdraw from `owner`.

```rs
fn allowance(owner: Principal, spender: Principal) -> u64 
```

**transfer**
Transfers `value` amount of tokens to Principal `to`. The function return `false` if the message caller’s Principal balance does not have enough tokens to spend. 

Transfers of 0 values will be treated as normal transfers

```rs
fn transfer(to: Principal, value: u64) -> bool 
```

**transferFrom**
Transfers `value` amount of tokens from Principal `from` to address `to`.

The `transferFrom` method is used for a withdraw workflow, allowing canister to transfer tokens on your behalf. This can be used for example to allow a contract to transfer tokens on your behalf. The function will return `false` unless the `from` account has deliberately authorized the sender of the message via some mechanism.

Transfers of 0 values will be treated as normal transfers 

```rs
fn transfer_from(from: Principal, to: Principal, value: u64) -> bool 
```

**approve**
Allows `spender` to withdraw from your account multiple times, up to the `value` amount. If this function is called again it overwrites the current allowance with `value`.

```rs
fn approve(spender: Principal, value: u64) -> bool
```

#### Other
**Rust methods**
```rs
fn owner() -> Principal
fn controller() -> Principal
fn mint(to: Principal, value: u64) -> bool
fn burn(from: Principal, value: u64) -> bool
```

**Candid interface**
```did
owner : () -> (principal) query;
controller : () -> (principal) query;
mint : (principal, nat64) -> (bool);
burn : (principal, nat64) -> (bool);
```


**owner**
Returns the admin account of the token.

```rs
fn owner() -> Principal
```

**controller**
Return the controller of the canister, not implemented.

```rs
fn controller() -> Principal
```

**mint**
Creates `value` amount tokens and assigns them to Principal `to`, increasing the total supply.

Only the `admin` account can call this function successfully.

```rs
fn mint(to: Principal, value: u64) -> bool
```

**burn**
Destories `value` amount tokens in `from`'s account, decreasing the total supply.

```rs
fn burn(from: Principal, value: u64) -> bool
```

