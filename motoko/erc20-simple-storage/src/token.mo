/**
 * Module     : token.mo
 * Copyright  : 2021 DFinance Team
 * License    : Apache 2.0 with LLVM Exception
 * Maintainer : DFinance Team <hello@dfinance.ai>
 * Stability  : Experimental
 */

import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Types "./types";
import Time "mo:base/Time";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Option "mo:base/Option";
import ExperimentalCycles "mo:base/ExperimentalCycles";

shared(msg) actor class Token(
    _logo: Text,
    _name: Text, 
    _symbol: Text,
    _decimals: Nat, 
    _totalSupply: Nat, 
    _owner: Principal, 
    _mintable: Bool, 
    _burnable: Bool
    ) {
    type Operation = Types.Operation;
    type OpRecord = Types.OpRecord;
    type Metadata = {
        logo : Text;
        name : Text;
        symbol : Text;
        decimals : Nat;
        totalSupply : Nat;
        mintable: Bool;
        burnable: Bool;
        owner : Principal;
        historySize : Nat;
        deployTime: Time.Time;
        fee : Nat;
        feeTo : Principal;
        holderNumber : Nat;
        cycles : Nat;
    };

    private stable var owner_ : Principal = _owner;
    private stable var logo_ : Text = _logo;
    private stable var name_ : Text = _name;
    private stable var decimals_ : Nat = _decimals;
    private stable var symbol_ : Text = _symbol;
    private stable var totalSupply_ : Nat = _totalSupply;
    private stable var mintable_ : Bool = _mintable;
    private stable var burnable_ : Bool = _burnable;
    private stable var feeTo : Principal = owner_;
    private stable var fee : Nat = 0;
    private stable var balanceEntries : [(Principal, Nat)] = [];
    private stable var allowanceEntries : [(Principal, [(Principal, Nat)])] = [];
    private var balances = HashMap.HashMap<Principal, Nat>(1, Principal.equal, Principal.hash);
    private var allowances = HashMap.HashMap<Principal, HashMap.HashMap<Principal, Nat>>(1, Principal.equal, Principal.hash);
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
    private stable var ops : [OpRecord] = [genesis];

    private func addRecord(
        caller: Principal, op: Operation, from: ?Principal, to: ?Principal, amount: Nat,
        fee: Nat, timestamp: Time.Time
    ) {
        let index = ops.size();
        let o : OpRecord = {
            caller = caller;
            op = op;
            index = index;
            from = from;
            to = to;
            amount = amount;
            fee = fee;
            timestamp = timestamp;
        };
        ops := Array.append(ops, [o]);
    };

    private func _addFee(from: Principal, fee: Nat) {
        if(fee > 0) {
            _transfer(from, feeTo, fee);
        };
    };

    private func _transfer(from: Principal, to: Principal, value: Nat) {
        let from_balance = _balanceOf(from);
        let from_balance_new : Nat = from_balance - value;
        if (from_balance_new != 0) { balances.put(from, from_balance_new); }
        else { balances.delete(from); };

        let to_balance = _balanceOf(to);
        let to_balance_new : Nat = to_balance + value;
        if (to_balance_new != 0) { balances.put(to, to_balance_new); };
    };

    private func _balanceOf(who: Principal) : Nat {
        switch (balances.get(who)) {
            case (?balance) { return balance; };
            case (_) { return 0; };
        }
    };

    private func _allowance(owner: Principal, spender: Principal) : Nat {
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

    public shared(msg) func setFeeTo(to: Principal) : async Bool {
        assert(msg.caller == owner_);
        feeTo := to;
        return true;
    };

    public shared(msg) func setFee(_fee: Nat) : async Bool {
        assert(msg.caller == owner_);
        fee := _fee;
        return true;
    };

    public shared(msg) func setLogo(logo: Text) : async Bool {
        assert(msg.caller == owner_);
        logo_ := logo;
        return true;
    };

    /// Transfers value amount of tokens to Principal to.
    public shared(msg) func transfer(to: Principal, value: Nat) : async Bool {
        if (value < fee) { return false; };
        if (_balanceOf(msg.caller) < value) { return false; };
        _addFee(msg.caller, fee);
        _transfer(msg.caller, to, value - fee);
        addRecord(msg.caller, #transfer, ?msg.caller, ?to, value, fee, Time.now());
        return true;
    };

    /// Transfers value amount of tokens from Principal from to Principal to.
    public shared(msg) func transferFrom(from: Principal, to: Principal, value: Nat) : async Bool {
        if (value < fee) { return false; };
        if (_balanceOf(from) < value) { return false; };
        let allowed : Nat = _allowance(from, msg.caller);
        if (allowed < value) { return false; };
        _addFee(from, fee);
        _transfer(from, to, value - fee);
        let allowed_new : Nat = allowed - value;
        if (allowed_new != 0) {
            let allowance_from = Option.unwrap(allowances.get(from));
            allowance_from.put(msg.caller, allowed_new);
            allowances.put(from, allowance_from);
        } else {
            if (allowed != 0) {
                let allowance_from = Option.unwrap(allowances.get(from));
                allowance_from.delete(msg.caller);
                if (allowance_from.size() == 0) { allowances.delete(from); }
                else { allowances.put(from, allowance_from); };
            };
        };
        addRecord(from, #transfer, ?from, ?to, value, fee, Time.now());
        return true;
    };

    /// Allows spender to withdraw from your account multiple times, up to the value amount. 
    /// If this function is called again it overwrites the current allowance with value.
    public shared(msg) func approve(spender: Principal, value: Nat) : async Bool {
        if (value == 0 and Option.isSome(allowances.get(msg.caller))) {
            let allowance_caller = Option.unwrap(allowances.get(msg.caller));
            allowance_caller.delete(spender);
            if (allowance_caller.size() == 0) { allowances.delete(msg.caller); }
            else { allowances.put(msg.caller, allowance_caller); };
        } else if (value != 0 and Option.isNull(allowances.get(msg.caller))) {
            var temp = HashMap.HashMap<Principal, Nat>(1, Principal.equal, Principal.hash);
            temp.put(spender, value);
            allowances.put(msg.caller, temp);
        } else if (value != 0 and Option.isSome(allowances.get(msg.caller))) {
            let allowance_caller = Option.unwrap(allowances.get(msg.caller));
            allowance_caller.put(spender, value);
            allowances.put(msg.caller, allowance_caller);
        };
        addRecord(msg.caller, #approve, ?msg.caller, ?spender, value, 0, Time.now());
        return true;
    };

    public shared(msg) func setMintable(v: Bool): async Bool {
        assert(msg.caller == owner_);
        mintable_ := v;
        return true;
    };

    public shared(msg) func setBurnable(v: Bool): async Bool {
        assert(msg.caller == owner_);
        burnable_ := v;
        return true;
    };

    /// Creates value tokens and assigns them to Principal to, increasing the total supply.
    public shared(msg) func mint(to: Principal, value: Nat): async Bool {
        assert(mintable_);
        assert(msg.caller == owner_);
        if (Option.isSome(balances.get(to))) {
            balances.put(to, Option.unwrap(balances.get(to)) + value);
            totalSupply_ += value;
        } else {
            if (value != 0) {
                balances.put(to, value);
                totalSupply_ += value;
            };
        };
        addRecord(msg.caller, #mint, null, ?to, value, 0, Time.now());
        return true;
    };

    public shared(msg) func burn(from: Principal, value: Nat): async Bool {
        assert(burnable_);
        assert(msg.caller == owner_ or msg.caller == from);
        if (Option.isSome(balances.get(from))) {
            let balance_from = _balanceOf(from);
            if (balance_from < value) { return false; }
            else if (balance_from == value) { balances.delete(from); }
            else { balances.put(from, balance_from - value); };
            totalSupply_ -= value;
        } else { return false; };
        addRecord(msg.caller, #burn, ?from, null, value, 0, Time.now());
        return true;
    };

    public query func balanceOf(who: Principal) : async Nat {
        return _balanceOf(who);
    };

    public query func allowance(owner: Principal, spender: Principal) : async Nat {
        return _allowance(owner, spender);
    };

    public query func totalSupply() : async Nat {
        return totalSupply_;
    };

    public query func logo() : async Text {
        return logo_;
    };

    public query func name() : async Text {
        return name_;
    };

    public query func decimals() : async Nat {
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

    public query func getFee() : async Nat {
        return fee;
    };

    public query func getHolderNumber() : async Nat {
        return balances.size();
    };

    /// Get History by index.
    public query func getHistoryByIndex(index: Nat) : async OpRecord {
        return ops[index];
    };

    /// Get history
    public query func getHistory(start: Nat, num: Nat) : async [OpRecord] {
        var ret: [OpRecord] = [];
        var i = start;
        while(i < start + num and i < ops.size()) {
            ret := Array.append(ret, [ops[i]]);
            i += 1;
        };
        return ret;
    };

    public query func getUserOpAmount(a: Principal) : async Nat {
        var res: Nat = 0;
        for (i in ops.vals()) {
            if (i.caller == a or (Option.isSome(i.from) and Option.unwrap(i.from) == a) or (Option.isSome(i.to) and Option.unwrap(i.to) == a)) {
                res += 1;
            };
        };
        return res;
    };

    public query func getUserHistory(a: Principal, start: Nat, num: Nat) : async [OpRecord] {
        var res: [OpRecord] = [];
        var index: Nat = 0;
        for (i in ops.vals()) {
            if (i.caller == a or (Option.isSome(i.from) and Option.unwrap(i.from) == a) or (Option.isSome(i.to) and Option.unwrap(i.to) == a)) {
                if(index >= start and index < start + num) {
                    res := Array.append<OpRecord>(res, [i]);
                };
                index += 1;
            };
        };
        return res;
    };

    /// Get history by account.
    public query func getHistoryByAccount(a: Principal) : async [OpRecord] {
        var res: [OpRecord] = [];
        for (i in ops.vals()) {
            if (i.caller == a or (Option.isSome(i.from) and Option.unwrap(i.from) == a) or (Option.isSome(i.to) and Option.unwrap(i.to) == a)) {
                res := Array.append<OpRecord>(res, [i]);
            };
        };
        return res;
    };
    
    /// Get all update call history.
    public query func allHistory() : async [OpRecord] {
        return ops;
    };

    public query func getAllAllowed() : async [(Principal, [(Principal, Nat)])] {
        var size : Nat = allowances.size();
        var res : [var (Principal, [(Principal, Nat)])] = Array.init<(Principal, [(Principal, Nat)])>(size, (owner_, []));
        size := 0;
        for ((k, v) in allowances.entries()) {
            res[size] := (k, Iter.toArray(v.entries()));
            size += 1;
        };
        return Array.freeze(res);
    };

    public query func getAllAllowedNumber() : async Nat {
        var size : Nat = 0;
        for ((k, v) in allowances.entries()) {
            size += v.size();
        };
        return size;   
    };

    public query func getSomeAllowed(who : Principal) : async [(Principal, Nat)] {
        var size : Nat = 0;
        if (Option.isSome(allowances.get(who))) {
            let allowance_who = Option.unwrap(allowances.get(who));
            return Iter.toArray(allowance_who.entries());
        } else {
            return [];
        };
    };

    public query func getSomeAllowedNumber(who : Principal) : async Nat {
        if (Option.isSome(allowances.get(who))) { return Option.unwrap(allowances.get(who)).size(); } 
        else { return 0; };
    };

    // no sure which is best, below vs Array.append();
    public query func getAllAccounts() : async [(Principal, Nat)] {
        return Iter.toArray(balances.entries());
    };

    public query func getCycles() : async Nat {
        return ExperimentalCycles.balance();
    };

    public query func getMetadata() : async Metadata {
        return {
            logo = logo_;
            name = name_;
            symbol = symbol_;
            decimals = decimals_;
            totalSupply = totalSupply_;
            mintable = mintable_;
            burnable = burnable_;
            owner = owner_;
            historySize = ops.size();
            deployTime = genesis.timestamp;
            fee = fee;
            feeTo = feeTo;
            holderNumber = balances.size();
            cycles = ExperimentalCycles.balance();
        };
    };

    system func preupgrade() {
        balanceEntries := Iter.toArray(balances.entries());
        var size : Nat = allowances.size();
        var temp : [var (Principal, [(Principal, Nat)])] = Array.init<(Principal, [(Principal, Nat)])>(size, (owner_, []));
        size := 0;
        for ((k, v) in allowances.entries()) {
            temp[size] := (k, Iter.toArray(v.entries()));
            size += 1;
        };
        allowanceEntries := Array.freeze(temp);
    };

    system func postupgrade() {
        balances := HashMap.fromIter<Principal, Nat>(balanceEntries.vals(), 1, Principal.equal, Principal.hash);
        balanceEntries := [];
        for ((k, v) in allowanceEntries.vals()) {
            let allowed_temp = HashMap.fromIter<Principal, Nat>(v.vals(), 1, Principal.equal, Principal.hash);
            allowances.put(k, allowed_temp);
        };
        allowanceEntries := [];
    };
};