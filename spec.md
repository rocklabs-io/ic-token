# Token Standard Spec



A fungible token standard for the DFINITY Internet Computer.

## Abstract

A standard token interface is a basic building block for many applications on the Internet Computer, such as wallets and decentralized exchanges, in this specification we propose a standard token interface for fungible tokens on the IC. This standard provides basic functionality to transfer tokens, allow tokens to be approved so they can be spent by a third-party, it also provides interfaces to query history transactions.

## Specification

### 1. Data Structures

1. Metadata: basic token information

   ```
   type Metadata = {
   	logo : Text; // base64 encoded logo or logo url
   	name : Text; // token name
   	symbol : Text; // token symbol
   	decimals : Nat8; // token decimal
   	totalSupply : Nat; // token total supply
   	owner : Principal; // token owner
   	fee : Nat; // fee for update calls
   	feeTo : Principal; // fee receiver
   }
   ```

2. Status: token status info

   ```
   type Status = {
   	historySize : Nat; // total number of history transactions
   	deployTime: Time.Time; // token canister deploy time in nanoseconds
   	holderNumber : Nat; // token holder number
   	cycles : Nat; // token canister cycles balance
   }
   ```

3. TxReceipt: receipt for update calls, contains the transaction index or an error message

   ```
   type TxReceipt = Result.Result<Nat, {
   	#InsufficientBalance;
   	#InsufficientAllowance;
   }>;
   ```

4. TxRecord: history transaction record

   ```
   public type Operation = {
   	#mint;
   	#burn;
   	#transfer;
   	#approve;
   	#init;
   };
   public type TxRecord = {
   	caller: Principal; // caller of the transaction
   	op: Operation; // operation type
   	index: Nat; // transaction index
   	from: Principal;
   	to: Principal;
   	amount: Nat;
   	fee: Nat;
   	timestamp: Time.Time;
   };
   ```

### 2. Basic Interfaces

#### Update calls

The update calls described in this section will be charged `fee` amount of tokens to prevent DDoS attack, this is necessary because of the reverse gas model of the IC.

##### transfer

Transfers `value` amount of tokens to user `to`, returns a `TxReceipt` which contains the transaction index or an error message.

```javascript
public shared(msg) func transfer(to: Principal, value: Nat) : async TxReceipt
```

##### transferFrom

Transfers `value` amount of tokens from user `from` to user `to`, this method allows canster smart contracts to transfer tokens on your behalf, it returns a `TxReceipt` which contains the transaction index or an error message.

```
public shared(msg) func transferFrom(from: Principal, to: Principal, value: Nat) : async TxReceipt
```

##### approve

Allows `spender` to withdraw tokens from your account, up to the `value` amount. If it is called again it overwrites the current allowance with `value`. There is no upper limit for `value`.

```
public shared(msg) func approve(spender: Principal, value: Nat) : async TxReceipt
```

#### Query calls

##### logo

Returns the logo of the token.

```
public query func logo() : async Text
```

##### name

Returns the name of the token.

```
public query func name() : async Text
```

##### symbol

Returns the symbol of the token.

```
public query func symbol() : async Text
```

##### decimals

Returns the decimals of the token.

```
public query func decimals() : async Nat8
```

##### totalSupply

Returns the total supply of the token.

```
public query func totalSupply() : async Nat
```

##### balanceOf

Returns the balance of user `who`.

```
public query func balanceOf(who: Principal) : async Nat
```

##### allowance

Returns the amount which `spender` is still allowed to withdraw from `owner`.

```
public query func allowance(owner: Principal, spender: Principal) : async Nat
```

##### getMetadata

Returns the metadata of the token.

```
public query func getMetadata() : async Metadata
```

##### getStatus

Returns the status of the token.

```
public query func getStatus() : async Status
```

The following functions are used for query of history transaction records.

##### getTransaction

Returns transaction detail of the transaction identified by `index`.

```
public query func getTransaction(index: Nat) : async TxRecord
```

##### getTransactions

Returns an array of transaction records in the range `[start, start + limit)`.

```
public query func getTransactions(start: Nat, limit: Nat) : async [TxRecord]
```

##### getUserTransactionAmount

Returns total number of transactions related to the user `who`.

```
public query func getUserTransactionAmount(who: Principal) : async Nat
```

##### getUserTransactions

Returns an array of transaction records in range `[start, start + limit)` related to user `who` . 

```
public query func getUserTransactions(who: Principal, start: Nat, limit: Nat) : async [TxRecord]
```



### 3. Optional interfaces

#### Update calls

The following update calls should be authorized, only the `owner` of the token canister can call these functions.

##### mint

Mint `value` number of new tokens to user `to`, this will increase the token total supply, only `owner` is allowed to mint new tokens.

```
public shared(msg) func mint(to: Principal, value: Nat): async TxReceipt
```

##### burn

Burn `value` number of new tokens from user `from`, this will decrease the token total supply, only `owner` or the user `from` him/herself can perform this operation.

```
public shared(msg) func burn(from: Principal, value: Nat): async TxReceipt
```

`aaaaa-aa` is the IC management canister id, it's not a real canister, just an abstraction of system level management functions, it can be used as blackhole address.

##### setLogo

Change the logo of the token, no return value needed. The `logo` can either be a base64 encoded text of the logo picture or an URL pointing to the logo picture.

```
public shared(msg) func setLogo(logo: Text)
```

##### setFee

Set fee to `newFee` for update calls(`approve`, `transfer`, `transferFrom`), no return value needed.

```
public shared(msg) func setFee(newFee: Nat)
```

##### setFeeTo

Set fee receiver to `newFeeTo` , no return value needed.

```
public shared(msg) func setFeeTo(newFeeTo: Principal)
```

##### setOwner

Set the owner of the token to `newOwner`, no return value needed.

```
public shared(msg) func setOwner(newOwner: Principal)
```



### 4. Change log



