import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Storage "./storage";
import Types "./Types";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Error "mo:base/Error";
import Option "mo:base/Option";

shared(msg) actor class Token(_name: Text, _symbol: Text, _decimals: Nat64, _totalSupply: Nat64, _owner: Principal) {
    type Operation = Types.Operation;
    type OpRecord = Types.OpRecord;
    type StorageActor = actor {
        addRecord : (caller: Principal, op: Operation, from: ?Principal, to: ?Principal, amount: Nat64,
            fee: Nat64, timestamp: Time.Time) -> async Nat;
        getHistoryByIndex : (index : Nat) -> async ?OpRecord;
        getHistoryByAccount : (a : Principal) -> async ?[OpRecord];
        allHistory : () -> async [OpRecord];
    };
    type Metadata = {
        name : Text;
        symbol : Text;
        decimals : Nat64;
        totalSupply : Nat64;
        owner : Principal;
        storageCanister : ?StorageActor;
        deployTime: Time.Time;
        fee : Nat64;
        feeTo : Principal;
        userNumber : Nat;
    };

    private stable var owner_ : Principal = _owner;
    private stable var name_ : Text = _name;
    private stable var decimals_ : Nat64 = _decimals;
    private stable var symbol_ : Text = _symbol;
    private stable var totalSupply_ : Nat64 = _totalSupply;
    private stable var storageCanister : ?StorageActor = null;
    private stable var feeTo : Principal = owner_;
    private stable var fee : Nat64 = 0;
    private var balances =  HashMap.HashMap<Principal, Nat64>(1, Principal.equal, Principal.hash);
    private var allowances = HashMap.HashMap<Principal, HashMap.HashMap<Principal, Nat64>>(1, Principal.equal, Principal.hash);
    balances.put(owner_, totalSupply_);
    private stable let genesis : OpRecord = {
        caller = owner_;
        op = #init;
        index = 0;
        from = null;
        to = ?owner_;
        amount = totalSupply_;
        fee = 0;
        timestamp = Time.now();
    };

    private func addFee(_fee: Nat64) {
        switch (balances.get(feeTo)) {
            case (?balance) { balances.put(feeTo, balance + _fee); };
            case (_) { balances.put(feeTo, _fee); };
        }
    };

    public shared(msg) func setStorageCanisterId(storage: ?Principal) : async Bool {
        assert(msg.caller == owner_);
        if (storage == null) { storageCanister := null; }
        else { storageCanister := ?actor(Principal.toText(Option.unwrap(storage))); };
        return true;
    };

    public shared(msg) func setFeeTo(to: Principal) : async Bool {
        assert(msg.caller == owner_);
        feeTo := to;
        return true;
    };

    public shared(msg) func setFee(_fee: Nat64) : async Bool {
        assert(msg.caller == owner_);
        fee := _fee;
        return true;
    };

    /// owner should only call it ONCE
    public shared(msg) func storageGenesis() : async Nat {
        assert(msg.caller == owner_);
        if (storageCanister != null) {
            let res = await Option.unwrap(storageCanister).addRecord(genesis.caller, genesis.op, genesis.from, genesis.to, 
                genesis.amount, genesis.fee, genesis.timestamp);
            return res;
        } else { throw Error.reject("Storage Canister not set"); };
    };

    /// Transfers value amount of tokens to Principal to.
    public shared(msg) func transfer(to: Principal, value: Nat64) : async Bool {
        switch (balances.get(msg.caller)) {
            case (?caller_balance) {
                if (caller_balance >= value + fee) {
                    let from_balance_new : Nat64 = caller_balance - value - fee;
                    if (from_balance_new != 0) { balances.put(msg.caller, from_balance_new); } 
                    else { balances.delete(msg.caller); };                   
                    let to_balance_new = switch (balances.get(to)) {
                        case (?to_balance) { to_balance + value; };
                        case (_) { value; };
                    };
                    if (to_balance_new != 0) { balances.put(to, to_balance_new); };
                    addFee(fee);
                    if (storageCanister != null) {
                        ignore await Option.unwrap(storageCanister).addRecord(msg.caller, #transfer, ?msg.caller, ?to, value, fee, Time.now());
                    };
                    return true;
                } else { throw Error.reject("You have tried to spend more than the balance of your account"); };
            };
            case (_) {
                if (value == 0 and fee == 0) {
                    if (storageCanister != null) {
                        ignore await Option.unwrap(storageCanister).addRecord(msg.caller, #transfer, ?msg.caller, ?to, value, fee, Time.now());
                    };
                    return true;
                } else {
                    throw Error.reject("You tried to withdraw funds from empty account " # Principal.toText(msg.caller));
                }
            };
        }
    };

    /// Transfers value amount of tokens from Principal from to Principal to.
    public shared(msg) func transferFrom(from: Principal, to: Principal, value: Nat64) : async Bool {
        switch (balances.get(from), balances.get(msg.caller), allowances.get(from)) {
            case (?from_balance, ?caller_balance, ?allowance_from) {
                switch (allowance_from.get(msg.caller)) {
                    case (?allowance) {
                        if (from_balance >= value and allowance >= value and caller_balance >= fee) {
                            if (from_balance - value != 0) { balances.put(from, from_balance - value); } 
                            else { balances.delete(from); };
                            
                            if (caller_balance - fee != 0) { balances.put(msg.caller, caller_balance - fee); }
                            else { balances.delete(msg.caller); };
                            
                            var to_balance_new = switch (balances.get(to)) {
                                case (?to_balance) { to_balance + value; };
                                case (_) { value; };
                            };
                            if (to_balance_new != 0) { balances.put(to, to_balance_new);};

                            if (allowance - value != 0) { allowance_from.put(msg.caller, allowance - value); } 
                            else { allowance_from.delete(msg.caller); };
                            if (allowance_from.size() != 0) { allowances.put(from, allowance_from); } 
                            else { allowances.delete(from); };

                            addFee(fee);
                            if (storageCanister != null) {
                                ignore await Option.unwrap(storageCanister).addRecord(msg.caller, #transfer, ?from, ?to, value, fee, Time.now());
                            };
                            return true;                         
                        } else { 
                            throw Error.reject("You have tried to spend more than allowed or allower's balance or caller can't pay fee"); 
                        };
                    };
                    case (_) {
                        if (value == 0) {
                            if (caller_balance - fee != 0) { balances.put(msg.caller, caller_balance - fee); } 
                            else { balances.delete(msg.caller); };

                            addFee(fee);
                            if (storageCanister != null) {
                                ignore await Option.unwrap(storageCanister).addRecord(msg.caller, #transfer, ?from, ?to, value, fee, Time.now());
                            };
                            return true;                     
                        } else {
                            throw Error.reject("You tried to withdraw non-zero funds from empty allowance");
                        };
                    };
                }
            };
            case (_) {
                throw Error.reject("You tried to withdraw funds from empty allowance or empty account or caller can't pay fee");
            };
        }
    };

    /// Allows spender to withdraw from your account multiple times, up to the value amount. 
    /// If this function is called again it overwrites the current allowance with value.
    public shared(msg) func approve(spender: Principal, value: Nat64) : async Bool {
        switch(allowances.get(msg.caller)) {
            case (?allowances_caller) {
                allowances_caller.put(spender, value);
                allowances.put(msg.caller, allowances_caller);
                if (storageCanister != null) {
                    ignore await Option.unwrap(storageCanister).addRecord(msg.caller, #approve, ?msg.caller, ?spender, value, fee, Time.now());
                };
                return true;  
            };
            case (_) {
                var temp = HashMap.HashMap<Principal, Nat64>(1, Principal.equal, Principal.hash);
                temp.put(spender, value);
                allowances.put(msg.caller, temp);
                if (storageCanister != null) {
                    ignore await Option.unwrap(storageCanister).addRecord(msg.caller, #approve, ?msg.caller, ?spender, value, fee, Time.now());
                };
                return true; 
            };
        }
    };

    /// Creates value tokens and assigns them to Principal to, increasing the total supply.
    public shared(msg) func mint(to: Principal, value: Nat64): async Bool {
        assert(msg.caller == owner_);
        switch (balances.get(to)) {
            case (?to_balance) {
                balances.put(to, to_balance + value);
                totalSupply_ += value;
                if (storageCanister != null) {
                    ignore await Option.unwrap(storageCanister).addRecord(msg.caller, #mint, null, ?to, value, fee, Time.now());
                };
                return true;
            };
            case (_) {
                balances.put(to, value);
                totalSupply_ += value;
                if (storageCanister != null) {
                    ignore await Option.unwrap(storageCanister).addRecord(msg.caller, #mint, null, ?to, value, 0, Time.now());
                };
                return true;
            };
        }
    };

    public shared(msg) func burn(from: Principal, value: Nat64): async Bool {
        assert(msg.caller == owner_ or msg.caller == from);
        switch (balances.get(from)) {
            case (?from_balance) {
                if(from_balance >= value) {
                    balances.put(from, from_balance - value);
                    totalSupply_ -= value;
                    if (storageCanister != null) {
                        ignore await Option.unwrap(storageCanister).addRecord(msg.caller, #burn, ?from, null, value, 0, Time.now());
                    };
                    return true;
                } else {
                    throw Error.reject("You have tried to burn more than the balance of from account");
                }
            };
            case (_) {
                throw Error.reject("You tried to burn from empty account " # Principal.toText(from));
            };
        }
    };

    public query func balanceOf(who: Principal) : async Nat64 {
        switch (balances.get(who)) {
            case (?balance) { return balance; };
            case (_) { return 0; };
        }
    };

    public query func allowance(owner: Principal, spender: Principal) : async Nat64 {
        switch(allowances.get(owner)) {
            case (?allowance_owner) {
                switch(allowance_owner.get(spender)) {
                    case (?allowance) { return allowance; };
                    case (_) { return 0; };
                }
            };
            case (_) { return 0; };
        }
    };

    public query func totalSupply() : async Nat64 {
        return totalSupply_;
    };

    public query func name() : async Text {
        return name_;
    };

    public query func decimals() : async Nat64 {
        return decimals_;
    };

    public query func symbol() : async Text {
        return symbol_;
    };

    public query func owner() : async Principal {
        return owner_;
    };

    public query func getFeeTo() : async Principal {
        return feeTo;
    };

    public query func getFee() : async Nat64 {
        return fee;
    };

    public query func getUserNumber() : async Nat {
        return balances.size();
    };

    // no sure which is best, below vs Array.append();
    public query func getAllAccounts() : async [(Principal, Nat64)] {
        var res : [var (Principal, Nat64)] = Array.init<(Principal, Nat64)>(balances.size(),(owner_,0));
        var i : Nat = 0;
        for ((k, v) in balances.entries()) {
            res[i] := (k, v);
            i += 1;
        };
        return Array.freeze(res);
    };

    public query func getMetadata() : async Metadata {
        return {
            name = name_;
            symbol = symbol_;
            decimals = decimals_;
            totalSupply = totalSupply_;
            owner = owner_;
            storageCanister = storageCanister;
            deployTime = genesis.timestamp;
            fee = fee;
            feeTo = feeTo;
            userNumber = balances.size();
        };
    };
};