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
    public type Operation = {
        #mint;
        #burn;
        #transfer;
        #approve;
        #init;
    };
    public type Status = {
        #success;
        #failed;
    };
    public type OpRecord = {
        caller: Text;
        op: Operation;
        status: Status;
        index: Nat;
        hash: Text;
        from: ?Text;
        to: ?Text;
        amount: Nat64;
        fee: ?Nat64;
        memo: ?Nat64;
        timestamp: Time.Time;
    };
    // OpRecord without hash.
    public type OpRecordIn = {
        caller: Text;
        op: Operation;
        status: Status;
        index: Nat;
        from: ?Text;
        to: ?Text;
        amount: Nat64;
        fee: ?Nat64;
        memo: ?Nat64;
        timestamp: Time.Time;
    };

    public func bytes(o: OpRecordIn) : [Nat8] {
        var bytes : [var Nat8] = [var];
        bytes := Array.thaw(Array.append(Array.freeze(bytes), Utils.textToAccount(o.caller).hash));
        switch (o.op) {
            case (#mint) { bytes := Array.thaw(Array.append(Array.freeze(bytes), Array.make(0: Nat8))); };
            case (#burn) { bytes := Array.thaw(Array.append(Array.freeze(bytes), Array.make(1: Nat8))); };
            case (#transfer) { bytes := Array.thaw(Array.append(Array.freeze(bytes), Array.make(2: Nat8))); };
            case (#approve) { bytes := Array.thaw(Array.append(Array.freeze(bytes), Array.make(3: Nat8))); };
            case (#init) { bytes := Array.thaw(Array.append(Array.freeze(bytes), Array.make(4: Nat8))); }
        };
        switch (o.status) {
            case (#success) { bytes := Array.thaw(Array.append(Array.freeze(bytes), Array.make(0: Nat8))); };
            case (#failed) { bytes := Array.thaw(Array.append(Array.freeze(bytes), Array.make(1: Nat8))); };
        };
        bytes := Array.thaw(Array.append(Array.freeze(bytes), natTobytes(o.index)));
        if (not Option.isNull(o.from)) {
            bytes := Array.thaw(Array.append(Array.freeze(bytes), Utils.textToAccount(Option.unwrap(o.from)).hash));
        };
        if (not Option.isNull(o.to)) {
            bytes := Array.thaw(Array.append(Array.freeze(bytes), Utils.textToAccount(Option.unwrap(o.to)).hash));
        };
        bytes := Array.thaw(Array.append(Array.freeze(bytes), natTobytes(Nat64.toNat(o.amount))));
        if (not Option.isNull(o.fee)) {
            bytes := Array.thaw(Array.append(Array.freeze(bytes), natTobytes(Nat64.toNat(Option.unwrap(o.fee)))));
        };
        if (not Option.isNull(o.memo)) {
            bytes := Array.thaw(Array.append(Array.freeze(bytes), natTobytes(Nat64.toNat(Option.unwrap(o.memo)))));
        };
        bytes := Array.thaw(Array.append(Array.freeze(bytes), natTobytes(Int.abs(o.timestamp))));
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

    public func recordMake(
        caller: Text, op: Operation, status: Status, index: Nat, from: ?Text, to: ?Text, amount: Nat64,
        fee: ?Nat64, memo: ?Nat64, timestamp: Time.Time
    ) : (OpRecord, Text) {
        let ori : OpRecordIn = {
            caller = caller;
            op = op;
            status = status;
            index = index;
            from = from;
            to = to;
            amount = amount;
            fee = fee;
            memo = memo;
            timestamp = timestamp;
        };
        let hash_o = Utils.encode(SHA256.sha256(bytes(ori)));
        let o : OpRecord = {
            caller = ori.caller;
            op = ori.op;
            status = ori.status;
            index = ori.index;
            hash = hash_o;
            from = ori.from;
            to = ori.to;
            amount = ori.amount;
            fee = ori.fee;
            memo = ori.memo;
            timestamp = ori.timestamp;
        };          
        return (o, hash_o);
    };
};    