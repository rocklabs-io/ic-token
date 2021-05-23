import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Utils "./Utils";
import Char "mo:base/Char";

shared(msg) actor class Token(_name: Text, _symbol: Text, _decimals: Nat, _totalSupply: Nat) {
    type Account = Utils.AccountIdentifier;

    private stable var owner_ : Account = Utils.principalToAccount(msg.caller);
    private stable var name_ : Text = _name;
    private stable var decimals_ : Nat = _decimals;
    private stable var symbol_ : Text = _symbol;
    private stable var totalSupply_ : Nat = _totalSupply;
    private var balances =  HashMap.HashMap<Account, Nat>(1, Utils.equal, Utils.hash);
    private var allowances = HashMap.HashMap<Account, HashMap.HashMap<Account, Nat>>(1, Utils.equal, Utils.hash);
    balances.put(owner_, totalSupply_);

    /// Transfers value amount of tokens to Account to.
    public shared(msg) func transfer(to: Text, value: Nat) : async Bool {
        let caller = Utils.principalToAccount(msg.caller);
        let toer = Utils.textToAccount(to);
        switch (balances.get(caller)) {
            case (?from_balance) {
                if (from_balance >= value) {
                    var from_balance_new : Nat = from_balance - value;
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

    /// Transfers value amount of tokens from Account from to Account to.
    public shared(msg) func transferFrom(from: Text, to: Text, value: Nat) : async Bool {
        let caller = Utils.principalToAccount(msg.caller);
        let toer = Utils.textToAccount(to);
        let fromer = Utils.textToAccount(from);
        switch (balances.get(fromer), allowances.get(fromer)) {
            case (?from_balance, ?allowance_from) {
                switch (allowance_from.get(caller)) {
                    case (?allowance) {
                        if (from_balance >= value and allowance >= value) {
                            var from_balance_new : Nat = from_balance - value;
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

                            var allowance_new : Nat = allowance - value;
                            assert(allowance_new <= allowance);
                            allowance_from.put(caller, allowance_new);
                            allowances.put(fromer, allowance_from);
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
    public shared(msg) func approve(spender: Text, value: Nat) : async Bool {
        let caller = Utils.principalToAccount(msg.caller);
        let spend = Utils.textToAccount(spender);
        switch(allowances.get(caller)) {
            case (?allowances_caller) {
                allowances_caller.put(spend, value);
                allowances.put(caller, allowances_caller);
                return true;
            };
            case (_) {
                var temp = HashMap.HashMap<Account, Nat>(1, Utils.equal, Utils.hash);
                temp.put(spend, value);
                allowances.put(caller, temp);
                return true;
            };
        }
    };

    /// Creates value tokens and assigns them to Principal to, increasing the total supply.
    public shared(msg) func mint(to: Text, value: Nat): async Bool {
        let caller = Utils.principalToAccount(msg.caller);
        let toer = Utils.textToAccount(to);
        assert(caller == owner_);
        switch (balances.get(toer)) {
            case (?to_balance) {
                balances.put(toer, to_balance + value);
                totalSupply_ += value;
                return true;
            };
            case (_) {
                balances.put(toer, value);
                totalSupply_ += value;
                return true;
            };
        }
    };

    public shared(msg) func burn(from: Text, value: Nat): async Bool {
        let caller = Utils.principalToAccount(msg.caller);
        let fromer = Utils.textToAccount(from);
        assert(caller == owner_ or caller == fromer);
        switch (balances.get(fromer)) {
            case (?from_balance) {
                if(from_balance >= value) {
                    balances.put(fromer, from_balance - value);
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

    public query func balanceOf(who: Text) : async Nat {
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

    public query func allowance(owner: Text, spender: Text) : async Nat {
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

    public query func totalSupply() : async Nat {
        return totalSupply_;
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

    public query func owner() : async Text {
        return Utils.accountToText(owner_);
    };

    public shared(msg) func whoami() : async Text {
        return Utils.accountToText(Utils.principalToAccount(msg.caller));
    };
};