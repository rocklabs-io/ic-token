import Time "mo:base/Time";
import Array "mo:base/Array";
import Operation "mo:base/Option";
import Int "mo:base/Int";
import Utils "./Utils";
import SHA256 "./SHA256";
import Option "mo:base/Option";
import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";

module {
    type Account = Utils.AccountIdentifier;
    type Operation = {
        #mint;
        #burn;
        #transfer;
        #approve;
    };
    type Status = {
        #success;
        #failed;
    };
    public type Mint = {
        caller: Account;
        to: Account;
        amount: Nat;
        fee: ?Nat;
        memo: ?Nat64;
        timestamp: Time.Time;
    };
  
    public type Burn = {
        caller: Account;
        from: Account;
        amount: Nat;
        fee: ?Nat;
        memo: ?Nat64;
        timestamp: Time.Time;
    };
    public type Transfer = {
        caller: Account;
        from: Account;
        to: Account;
        amount: Nat;
        fee: ?Nat;
        memo: ?Nat64;
        timestamp: Time.Time;
    };
    public type Approve = {
        caller: Account;
        allowed: Account;
        amount: Nat;
        fee: ?Nat;
        memo: ?Nat64;
        timestamp: Time.Time;
    }; 
    public type History = {
        hash: Text;
        operation: Operation;
        mint: ?Mint;
        burn: ?Burn;
        transfer: ?Transfer;
        approve: ?Approve;
        index: Nat;
        status: Status;
    };
    public type HistoryInter = {
        operation: Operation;
        mint: ?Mint;
        burn: ?Burn;
        transfer: ?Transfer;
        approve: ?Approve;
        index: Nat;
        status: Status;
    };

    public func bytes(h: HistoryInter) : [Nat8] {
        var bytes : [var Nat8] = [var];
        switch (h.operation) {
            case (#mint) { bytes := Array.thaw<Nat8>(Array.append<Nat8>(Array.freeze<Nat8>(bytes), Array.make<Nat8>(0))); };
            case (#burn) { bytes := Array.thaw<Nat8>(Array.append<Nat8>(Array.freeze<Nat8>(bytes), Array.make<Nat8>(1))); };
            case (#transfer) { bytes := Array.thaw<Nat8>(Array.append<Nat8>(Array.freeze<Nat8>(bytes), Array.make<Nat8>(2))); };
            case (#approve) { bytes := Array.thaw<Nat8>(Array.append<Nat8>(Array.freeze<Nat8>(bytes), Array.make<Nat8>(3))); };
        };
        if (not Option.isNull(h.mint)) {
            let m = Option.unwrap(h.mint);
            bytes := Array.thaw(Array.append(Array.freeze(bytes), m.caller.hash));
            bytes := Array.thaw(Array.append(Array.freeze(bytes), m.to.hash));
            bytes := Array.thaw(Array.append(Array.freeze(bytes), natTobytes(m.amount)));
            if (not Option.isNull(m.fee)) {
                let f = Option.unwrap(m.fee);
                bytes := Array.thaw(Array.append(Array.freeze(bytes), natTobytes(f)));
            };
            if (not Option.isNull(m.memo)) {
                let me = Option.unwrap(m.memo);
                bytes := Array.thaw(Array.append(Array.freeze(bytes), natTobytes(Nat64.toNat(me))));
            };
            bytes := Array.thaw(Array.append(Array.freeze(bytes), natTobytes(Int.abs(m.timestamp))));
        };
        if (not Option.isNull(h.burn)) {
            let b = Option.unwrap(h.burn);
            bytes := Array.thaw(Array.append(Array.freeze(bytes), b.caller.hash));
            bytes := Array.thaw(Array.append(Array.freeze(bytes), b.from.hash));
            bytes := Array.thaw(Array.append(Array.freeze(bytes), natTobytes(b.amount)));
            if (not Option.isNull(b.fee)) {
                let f = Option.unwrap(b.fee);
                bytes := Array.thaw(Array.append(Array.freeze(bytes), natTobytes(f)));
            };
            if (not Option.isNull(b.memo)) {
                let me = Option.unwrap(b.memo);
                bytes := Array.thaw(Array.append(Array.freeze(bytes), natTobytes(Nat64.toNat(me))));
            };
            bytes := Array.thaw(Array.append(Array.freeze(bytes), natTobytes(Int.abs(b.timestamp))));
        };
        if (not Option.isNull(h.transfer)) {
            let t = Option.unwrap(h.transfer);
            bytes := Array.thaw(Array.append(Array.freeze(bytes), t.caller.hash));
            bytes := Array.thaw(Array.append(Array.freeze(bytes), t.from.hash));
            bytes := Array.thaw(Array.append(Array.freeze(bytes), t.to.hash));
            bytes := Array.thaw(Array.append(Array.freeze(bytes), natTobytes(t.amount)));
            if (not Option.isNull(t.fee)) {
                let f = Option.unwrap(t.fee);
                bytes := Array.thaw(Array.append(Array.freeze(bytes), natTobytes(f)));
            };
            if (not Option.isNull(t.memo)) {
                let me = Option.unwrap(t.memo);
                bytes := Array.thaw(Array.append(Array.freeze(bytes), natTobytes(Nat64.toNat(me))));
            };
            bytes := Array.thaw(Array.append(Array.freeze(bytes), natTobytes(Int.abs(t.timestamp))));
        };
        if (not Option.isNull(h.approve)) {
            let a = Option.unwrap(h.approve);
            bytes := Array.thaw(Array.append(Array.freeze(bytes), a.caller.hash));
            bytes := Array.thaw(Array.append(Array.freeze(bytes), a.allowed.hash));
            bytes := Array.thaw(Array.append(Array.freeze(bytes), natTobytes(a.amount)));
            if (not Option.isNull(a.fee)) {
                let f = Option.unwrap(a.fee);
                bytes := Array.thaw(Array.append(Array.freeze(bytes), natTobytes(f)));
            };
            if (not Option.isNull(a.memo)) {
                let me = Option.unwrap(a.memo);
                bytes := Array.thaw(Array.append(Array.freeze(bytes), natTobytes(Nat64.toNat(me))));
            };
            bytes := Array.thaw(Array.append(Array.freeze(bytes), natTobytes(Int.abs(a.timestamp))));
        };
        bytes := Array.thaw(Array.append(Array.freeze(bytes), natTobytes(h.index)));
        switch (h.status) {
            case (#success) { bytes := Array.thaw(Array.append(Array.freeze(bytes), Array.make(0 : Nat8))); };
            case (#failed) { bytes := Array.thaw(Array.append(Array.freeze(bytes), Array.make(1 : Nat8))); };
        };
        return Array.freeze(bytes);
    };

    private func natTobytes(n: Nat) : [Nat8] {
        var a : Nat = n;
        var bytes : [var Nat8] = [var];
        while (a != 0) {
            let min = a % 256;
            bytes := Array.thaw(Array.append(Array.make(Nat8.fromNat(min)), Array.freeze(bytes)));
            a := a / 256;
        };
        return Array.freeze(bytes);
    };

    public func transferMake(
        caller: Account, from: Account, to: Account, amount: Nat,
        fee: ?Nat, memo: ?Nat64, index: Nat, status: Status
    ) : (History, Text) {
        let t : Transfer = {
            caller = caller;
            from = from;
            to = to;
            amount = amount;
            fee = fee;
            memo = memo;
            timestamp = Time.now();
        };
        let hi : HistoryInter = {
            operation = #transfer;
            mint = null;
            burn = null;
            transfer = ?t;
            approve = null;
            index = index;
            status = status;
        };
        let hash_h = Utils.encode(SHA256.sha256(bytes(hi)));
        let h : History = {
            hash = hash_h;
            operation = hi.operation;
            mint = hi.mint;
            burn = hi.burn;
            transfer = hi.transfer;
            approve = hi.approve;
            index = hi.index;
            status = hi.status;
        };          
        return (h, hash_h);
    };

    public func approveMake(
        caller: Account, allowed: Account, amount: Nat, 
        fee: ?Nat, memo: ?Nat64, index: Nat, status: Status
    ) : (History, Text) {
        let a : Approve = {
            caller = caller;
            allowed = allowed;
            amount = amount;
            fee = fee;
            memo = memo;
            timestamp = Time.now();
        };
        let hi : HistoryInter = {
            operation = #approve;
            mint = null;
            burn = null;
            transfer = null;
            approve = ?a;
            index = index;
            status = status;
        };
        let hash_h = Utils.encode(SHA256.sha256(bytes(hi)));
        let h : History = {
            hash = hash_h;
            operation = hi.operation;
            mint = hi.mint;
            burn = hi.burn;
            transfer = hi.transfer;
            approve = hi.approve;
            index = hi.index;
            status = hi.status;
        };          
        return (h, hash_h);        
    };

    public func mintMake(
        caller: Account, to: Account, amount: Nat,
        fee: ?Nat, memo: ?Nat64, index: Nat, status: Status
    ) : (History, Text) {
        let m : Mint = {
            caller = caller;
            to = to;
            amount = amount;
            fee = fee;
            memo = memo;
            timestamp = Time.now();
        };
        let hi : HistoryInter = {
            operation = #mint;
            mint = ?m;
            burn = null;
            transfer = null;
            approve = null;
            index = index;
            status = status;
        };
        let hash_h = Utils.encode(SHA256.sha256(bytes(hi)));
        let h : History = {
            hash = hash_h;
            operation = hi.operation;
            mint = hi.mint;
            burn = hi.burn;
            transfer = hi.transfer;
            approve = hi.approve;
            index = hi.index;
            status = hi.status;
        };          
        return (h, hash_h);        
    };        

    public func burnMake(
       caller: Account, from: Account, amount: Nat,
       fee: ?Nat, memo: ?Nat64, index: Nat, status: Status 
    ) : (History, Text) {
        let b : Burn = {
            caller = caller;
            from = from;
            amount = amount;
            fee = fee;
            memo = memo;
            timestamp = Time.now();
        };
        let hi : HistoryInter = {
            operation = #burn;
            mint = null;
            burn = ?b;
            transfer = null;
            approve = null;
            index = index;
            status = status;
        };
        let hash_h = Utils.encode(SHA256.sha256(bytes(hi)));
        let h : History = {
            hash = hash_h;
            operation = hi.operation;
            mint = hi.mint;
            burn = hi.burn;
            transfer = hi.transfer;
            approve = hi.approve;
            index = hi.index;
            status = hi.status;
        };          
        return (h, hash_h);         
    };
};    