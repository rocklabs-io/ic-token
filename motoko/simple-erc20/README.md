# ERC20 style token template for the IC
Simple ERC20 style token canister, only implemented the most basic token functions.

## content
- [ERC20 style token template for the IC](#erc20-style-token-template-for-the-ic)
  - [content](#content)
  - [Documents](#documents)
    - [Methods](#methods)
      - [ERC20 Interface](#erc20-interface)
      - [Other Interface](#other-interface)
  - [Reference](#reference)

## Documents
### Methods
#### ERC20 Interface
```mo
public query func name() : async Text
public query func symbol() : async Text
public query func decimals() : async Nat
public query func totalSupply() : async Nat
public query func balanceOf(who: Principal) : async Nat
public query func allowance(owner: Principal, spender: Principal) : async Nat
public shared(msg) func transfer(to: Principal, value: Nat) : async Bool
public shared(msg) func transferFrom(from: Principal, to: Principal, value: Nat) : async Bool
public shared(msg) func approve(spender: Principal, value: Nat) : async Bool
```

**name**
Returns the name of the token - e.g. "MyToken".

```mo
public query func name() : async Text
```

**symbol**
Returns the symbol of the token. E.g. “MT”.

```mo
public query func symbol() : async Text
```

**decimals**
Returns the number of decimals the token uses - e.g. 8, means to divide the token amount by 100000000 to get its user representation.

```mo
public query func decimals() : async Nat
```

**totalSupply**
Returns the total token supply.

```mo
public query func totalSupply() : async Nat
```

**balanceOf**
Returns the account balance of another account with Principal `who`.

```mo
public query func balanceOf(who: Principal) : async Nat
```

**allowance**
Returns the amount which `spender` is still allowed to withdraw from `owner`.

```mo
public query func allowance(owner: Principal, spender: Principal) : async Nat
```

**transfer**
Transfers `value` amount of tokens to Principal `to`. The function return `false` if the message caller’s Principal balance does not have enough tokens to spend. 

Transfers of 0 values will be treated as normal transfers

```mo
public shared(msg) func transfer(to: Principal, value: Nat) : async Bool
```

**transferFrom**
Transfers `value` amount of tokens from Principal `from` to address `to`.

The `transferFrom` method is used for a withdraw workflow, allowing canister to transfer tokens on your behalf. This can be used for example to allow a contract to transfer tokens on your behalf. The function will return `false` unless the `from` account has deliberately authorized the sender of the message via some mechanism.

Transfers of 0 values will be treated as normal transfers 

```mo
public shared(msg) func transferFrom(from: Principal, to: Principal, value: Nat) : async Bool
```

**approve**
Allows `spender` to withdraw from your account multiple times, up to the `value` amount. If this function is called again it overwrites the current allowance with `value`.

```mo
public shared(msg) func approve(spender: Principal, value: Nat) : async Bool
```

#### Other Interface
```mo
public query func owner() : async Principal
public shared(msg) func mint(to: Principal, value: Nat): async Bool
public shared(msg) func burn(from: Principal, value: Nat): async Bool
```

**owner**
Returns the admin account of the token.

```mo
public query func owner() : async Principal
```

**mint**
Creates `value` amount tokens and assigns them to Principal `to`, increasing the total supply.

Only the `admin` account can call this function successfully.

```mo
public shared(msg) func mint(to: Principal, value: Nat): async Bool
```

**burn**
Destories `value` amount tokens in `from`'s account, decreasing the total supply.

```mo
public shared(msg) func burn(from: Principal, value: Nat): async Bool
```


## Reference

* https://github.com/enzoh/motoko-token
* https://github.com/flyq/motoko_token
