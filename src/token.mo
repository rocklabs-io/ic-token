import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Storage "./storage";
import Types "./Types";
import Time "mo:base/Time";


shared(msg) actor class Token(_name: Text, _symbol: Text, _decimals: Nat64, _totalSupply: Nat64, _owner: Principal, _storageCanisterId: Principal) {
    type Operation = Types.Operation;
    type OpRecord = Types.OpRecord;
    type StorageActor = actor {
        addRecord : (caller: Principal, op: Operation, from: ?Principal, to: ?Principal, amount: Nat64,
            fee: Nat64, timestamp: Time.Time) -> async Bool;
        getHistoryByIndex : (index : Nat) -> async ?OpRecord;
        getHistoryByAccount : (a : Principal) -> async ?[OpRecord];
        allHistory : () -> async [OpRecord];
    };

    private stable var owner_ : Principal = _owner;
    private stable var name_ : Text = _name;
    private stable var decimals_ : Nat64 = _decimals;
    private stable var symbol_ : Text = _symbol;
    private stable var totalSupply_ : Nat64 = _totalSupply;
    private stable var storageCanister : StorageActor = actor(Principal.toText(_storageCanisterId));
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
    private stable var feeTo = owner_;

    private var balances =  HashMap.HashMap<Principal, Nat64>(1, Principal.equal, Principal.hash);
    private var allowances = HashMap.HashMap<Principal, HashMap.HashMap<Principal, Nat64>>(1, Principal.equal, Principal.hash);

    balances.put(owner_, totalSupply_);

    public shared(msg) func setStorageCanisterId(storage: Principal) : async Bool {
        assert(msg.caller == owner_);
        storageCanister := actor(Principal.toText(storage));
        return true;
    };

    public shared(msg) func setFeeTo(to: Principal) : async Bool {
        assert(msg.caller == owner_);
        feeTo := to;
        return true;
    };

    /// Transfers value amount of tokens to Principal to.
    public shared(msg) func transfer(to: Principal, value: Nat64) : async Bool {
        switch (balances.get(msg.caller)) {
            case (?from_balance) {
                if (from_balance >= value) {
                    var from_balance_new : Nat64 = from_balance - value;
                    assert(from_balance_new <= from_balance);
                    balances.put(msg.caller, from_balance_new);

                    var to_balance_new = switch (balances.get(to)) {
                        case (?to_balance) {
                            to_balance + value;
                        };
                        case (_) {
                            value;
                        };
                    };
                    assert(to_balance_new >= value);
                    balances.put(to, to_balance_new);
                    ignore await storageCanister.addRecord(msg.caller, #transfer, ?msg.caller, ?to, value, 0, Time.now());
                    return true;
                } else {
                    return false;
                };
            };
            case (_) {
                return false;
            };
        }
    };

    /// Transfers value amount of tokens from Principal from to Principal to.
    public shared(msg) func transferFrom(from: Principal, to: Principal, value: Nat64) : async Bool {
        switch (balances.get(from), allowances.get(from)) {
            case (?from_balance, ?allowance_from) {
                switch (allowance_from.get(msg.caller)) {
                    case (?allowance) {
                        if (from_balance >= value and allowance >= value) {
                            var from_balance_new : Nat64 = from_balance - value;
                            assert(from_balance_new <= from_balance);
                            balances.put(from, from_balance_new);

                            var to_balance_new = switch (balances.get(to)) {
                                case (?to_balance) {
                                   to_balance + value;
                                };
                                case (_) {
                                    value;
                                };
                            };
                            assert(to_balance_new >= value);
                            balances.put(to, to_balance_new);

                            var allowance_new : Nat64 = allowance - value;
                            assert(allowance_new <= allowance);
                            allowance_from.put(msg.caller, allowance_new);
                            allowances.put(from, allowance_from);
                            return true;                            
                        } else {
                            return false;
                        };
                    };
                    case (_) {
                        return false;
                    };
                }
            };
            case (_) {
                return false;
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
                return true;
            };
            case (_) {
                var temp = HashMap.HashMap<Principal, Nat64>(1, Principal.equal, Principal.hash);
                temp.put(spender, value);
                allowances.put(msg.caller, temp);
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
                return true;
            };
            case (_) {
                balances.put(to, value);
                totalSupply_ += value;
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
                    return true;
                } else {
                    return false;
                }
            };
            case (_) {
                return false;
            };
        }
    };

    public query func balanceOf(who: Principal) : async Nat64 {
        switch (balances.get(who)) {
            case (?balance) {
                return balance;
            };
            case (_) {
                return 0;
            };
        }
    };

    public query func allowance(owner: Principal, spender: Principal) : async Nat64 {
        switch(allowances.get(owner)) {
            case (?allowance_owner) {
                switch(allowance_owner.get(spender)) {
                    case (?allowance) {
                        return allowance;
                    };
                    case (_) {
                        return 0;
                    };
                }
            };
            case (_) {
                return 0;
            };
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
};