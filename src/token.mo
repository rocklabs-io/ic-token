/// Motoko ERC20 Token
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Utils "./Utils";
import Char "mo:base/Char";
import Text "mo:base/Text";
import OpRecord "./OpRecord";
import SHA256 "./SHA256";
import Array "mo:base/Array";
import Time "mo:base/Time";
import Option "mo:base/Option";

/// Init token with `_name`, `_symbol`, `_decimals`, `_totalSupply`. 
/// `_totalSupply` is the number of minimum units.
shared(msg) actor class Token(_name: Text, _symbol: Text, _decimals: Nat64, _totalSupply: Nat64) {
    type Account = Utils.AccountIdentifier;
    type OpRecord = OpRecord.OpRecord;
    type OpRecordIn = OpRecord.OpRecordIn;
    type Operation = OpRecord.Operation;
    type Status = OpRecord.Status;

    private stable var owner_ : Account = Utils.principalToAccount(msg.caller);
    private stable var name_ : Text = _name;
    private stable var decimals_ : Nat64 = _decimals;
    private stable var symbol_ : Text = _symbol;
    private stable var totalSupply_ : Nat64 = _totalSupply;
    private var balances =  HashMap.HashMap<Account, Nat64>(1, Utils.equal, Utils.hash);
    private var allowances = HashMap.HashMap<Account, HashMap.HashMap<Account, Nat64>>(1, Utils.equal, Utils.hash);
    
    private var ops : [var OpRecord] = [var];
    // tx hash to OpRecord
    private var ops_map = HashMap.HashMap<Text, OpRecord>(1, Text.equal, Text.hash);
    // account to it's OpRecord
    private var ops_acc = HashMap.HashMap<Text, [var OpRecord]>(1, Text.equal, Text.hash);

    private func putOpsAcc(who: Text, o: OpRecord) {
        switch (ops_acc.get(who)) {
            case (?op_acc) {
                var op_new : [var OpRecord] = Array.thaw(Array.append(Array.freeze(op_acc), Array.make(o)));
                ops_acc.put(who, op_new);
            };
            case (_) {
                ops_acc.put(who, Array.thaw(Array.make(o)));
            };            
        }
    };

    private func addRecord(
        caller: Text, op: Operation, status: Status, index: Nat, from: ?Text, to: ?Text, amount: Nat64,
        fee: ?Nat64, memo: ?Nat64, timestamp: Time.Time
    ) : Text {
        let (o, hash_o) = OpRecord.recordMake(caller, op, status, index, from,
                            to, amount, fee, memo, timestamp);
        ops := Array.thaw(Array.append(Array.freeze(ops), Array.make(o)));
        ops_map.put(hash_o, o);
        putOpsAcc(caller, o);
        if ((not Option.isNull(from)) and (from != ?caller)) { putOpsAcc(Option.unwrap(from), o); };
        if ((not Option.isNull(to)) and (to != ?caller) and (to != from) ) { putOpsAcc(Option.unwrap(to), o); };
        return hash_o;
    };

    /// init 
    balances.put(owner_, totalSupply_);
    ignore addRecord(Utils.accountToText(owner_), #init, #success, ops.size(), null, ?Utils.accountToText(owner_), 
        totalSupply_, null, null, Time.now());

    /// Transfers `value` amount of tokens to Account `to`. 
    /// `value` is the number of minimum units.
    public shared(msg) func transfer(to: Text, value: Nat64) : async (Bool, Text) {
        let caller = Utils.principalToAccount(msg.caller);
        let toer = Utils.textToAccount(to);
        switch (balances.get(caller)) {
            case (?from_balance) {
                if (from_balance >= value) {
                    var from_balance_new : Nat64 = from_balance - value;
                    assert(from_balance_new <= from_balance);
                    balances.put(caller, from_balance_new);

                    var to_balance_new = switch (balances.get(toer)) {
                        case (?to_balance) {
                            to_balance + value;
                        };
                        case (_) {
                            value;
                        };
                    };
                    assert(to_balance_new >= value);
                    balances.put(toer, to_balance_new);

                    let hash_o = addRecord(Utils.accountToText(caller), #transfer, #success, ops.size(), ?Utils.accountToText(caller),
                                    ?Utils.accountToText(toer), value, null, null, Time.now());
                    return (true, hash_o);
                };
            };
            case (_) {};
        };
        let hash_o = addRecord(Utils.accountToText(caller), #transfer, #failed, ops.size(), ?Utils.accountToText(caller),
                        ?Utils.accountToText(toer), value, null, null, Time.now());                    
        return (false, hash_o);
    };

    /// Transfers `value` amount of tokens from Account `from` to Account `to`.
    /// `value` is the number of minimum units.    
    public shared(msg) func transferFrom(from: Text, to: Text, value: Nat64) : async (Bool, Text) {
        let caller = Utils.principalToAccount(msg.caller);
        let toer = Utils.textToAccount(to);
        let fromer = Utils.textToAccount(from);
        switch (balances.get(fromer), allowances.get(fromer)) {
            case (?from_balance, ?allowance_from) {
                switch (allowance_from.get(caller)) {
                    case (?allowance) {
                        if (from_balance >= value and allowance >= value) {
                            var from_balance_new : Nat64 = from_balance - value;
                            assert(from_balance_new <= from_balance);
                            balances.put(fromer, from_balance_new);

                            var to_balance_new = switch (balances.get(toer)) {
                                case (?to_balance) {
                                   to_balance + value;
                                };
                                case (_) {
                                    value;
                                };
                            };
                            assert(to_balance_new >= value);
                            balances.put(toer, to_balance_new);

                            var allowance_new : Nat64 = allowance - value;
                            assert(allowance_new <= allowance);
                            allowance_from.put(caller, allowance_new);
                            allowances.put(fromer, allowance_from);

                            let hash_o = addRecord(Utils.accountToText(caller), #transfer, #success, ops.size(), ?Utils.accountToText(fromer),
                                            ?Utils.accountToText(toer), value, null, null, Time.now());                                                    
                            return (true, hash_o);
                        };
                    };
                    case (_) {};
                }
            };
            case (_) {};
        };
        let hash_o = addRecord(Utils.accountToText(caller), #transfer, #failed, ops.size(), ?Utils.accountToText(fromer),
                        ?Utils.accountToText(toer), value, null, null, Time.now());                 
        return (false, hash_o);
    };

    /// Allows `spender` to withdraw from your account multiple times, up to the `value` amount. 
    /// If this function is called again it overwrites the current allowance with value.
    /// `value` is the number of minimum units.    
    /// the `value` of `approve` is has **nothing** to do with your `balance`
    public shared(msg) func approve(spender: Text, value: Nat64) : async (Bool, Text) {
        let caller = Utils.principalToAccount(msg.caller);
        let spend = Utils.textToAccount(spender);
        switch(allowances.get(caller)) {
            case (?allowances_caller) {
                allowances_caller.put(spend, value);
                allowances.put(caller, allowances_caller);                
            };
            case (_) {
                var temp = HashMap.HashMap<Account, Nat64>(1, Utils.equal, Utils.hash);
                temp.put(spend, value);
                allowances.put(caller, temp);
            };
        };
        let hash_o = addRecord(Utils.accountToText(caller), #approve, #success, ops.size(), ?Utils.accountToText(caller),
                        ?Utils.accountToText(spend), value, null, null, Time.now());
        return (true, hash_o);
    };

    /// Creates `value` tokens and assigns them to Account `to`, increasing the total supply.
    public shared(msg) func mint(to: Text, value: Nat64): async (Bool, Text) {
        let caller = Utils.principalToAccount(msg.caller);
        let toer = Utils.textToAccount(to);
        assert(caller == owner_);
        switch (balances.get(toer)) {
            case (?to_balance) {
                balances.put(toer, to_balance + value);
                totalSupply_ += value;        
            };
            case (_) {
                balances.put(toer, value);
                totalSupply_ += value;
            };
        };
        let hash_o = addRecord(Utils.accountToText(caller), #mint, #success, ops.size(), null,
                        ?Utils.accountToText(toer), value, null, null, Time.now());
        return (true, hash_o);
    };

    /// Burn `value` tokens of Account `to`, decreasing the total supply.
    public shared(msg) func burn(from: Text, value: Nat64): async (Bool, Text) {
        let caller = Utils.principalToAccount(msg.caller);
        let fromer = Utils.textToAccount(from);
        assert(caller == owner_ or caller == fromer);
        switch (balances.get(fromer)) {
            case (?from_balance) {
                if(from_balance >= value) {
                    balances.put(fromer, from_balance - value);
                    totalSupply_ -= value;

                    let hash_o = addRecord(Utils.accountToText(caller), #burn, #success, ops.size(), ?Utils.accountToText(fromer),
                                    null, value, null, null, Time.now());
                    return (true, hash_o);
                };
            };
            case (_) {};
        };
        let hash_o = addRecord(Utils.accountToText(caller), #burn, #failed, ops.size(), ?Utils.accountToText(fromer),
                        null, value, null, null, Time.now());
        return (false, hash_o);        
    };

    /// Get the balance of Account `who`, in the number of minimum units. 
    public query func balanceOf(who: Text) : async Nat64 {
        let whoer = Utils.textToAccount(who);
        switch (balances.get(whoer)) {
            case (?balance) {
                return balance;
            };
            case (_) {
                return 0;
            };
        }
    };

    /// Get the amount which `spender` is still allowed to withdraw from `owner`, in the number of minimum units. 
    public query func allowance(owner: Text, spender: Text) : async Nat64 {
        let own = Utils.textToAccount(owner);
        let spend = Utils.textToAccount(spender);
        switch(allowances.get(own)) {
            case (?allowance_owner) {
                switch(allowance_owner.get(spend)) {
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

    /// Get the total token supply, in the number of minimum units.
    public query func totalSupply() : async Nat64 {
        return totalSupply_;
    };

    /// Get the name of the token.
    public query func name() : async Text {
        return name_;
    };

    /// Get the number of decimals the token uses.
    public query func decimals() : async Nat64 {
        return decimals_;
    };

    /// Get the symbol of the token.
    public query func symbol() : async Text {
        return symbol_;
    };

    /// Get the owner of the token.
    public query func owner() : async Text {
        return Utils.accountToText(owner_);
    };

    /// Get update call ops index by hash.
    public query func getHistoryByHash(hash: Text) : async ?OpRecord {
        return ops_map.get(hash);
    };

    /// Get update call ops by account.
    public query func getHistoryByAccount(a: Text) : async ?[OpRecord] {
        let account = Utils.textToAccount(a);
        switch (ops_acc.get(Utils.accountToText(account))) {
            case (?op_acc) {
                let res = Array.freeze(op_acc);
                return ?res;
            };
            case (_) {
                return null;
            };
        }
    };

    /// Get all update call ops.
    public query func allHistory() : async [OpRecord] {
        return Array.freeze(ops);
    };

    /// Get the caller's Account.
    public shared(msg) func whoami() : async Text {
        return Utils.accountToText(Utils.principalToAccount(msg.caller));
    };
};