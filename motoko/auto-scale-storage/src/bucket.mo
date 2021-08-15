/**
 * Module     : bucket.mo
 * Copyright  : 2021 DFinance Team
 * License    : Apache 2.0 with LLVM Exception
 * Maintainer : DFinance Team <hello@dfinance.ai>
 * Stability  : Experimental
 */

import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Time "mo:base/Time";
import Prim "mo:prim";
import Types "./types";
import ExperimentalCycles "mo:base/ExperimentalCycles";

shared(msg) actor class Bucket() {
    type Operation = Types.Operation;
    type OpRecord = Types.OpRecord;

    private stable var storage_canister_id_ : Principal = msg.caller;
    private stable var ops : [var OpRecord] = [var];

    public shared(msg) func addRecord(o: OpRecord): async () {
        assert(msg.caller == storage_canister_id_);
        ops := Array.thaw(Array.append(Array.freeze(ops), Array.make(o)));
    };

    /// Get History by index.
    public query func getRecordByIndex(index: Nat) : async OpRecord {
        return ops[index];
    };

    /// Get history
    public query func getRecords(start: Nat, num: Nat) : async [OpRecord] {
        var ret: [OpRecord] = [];
        var i = start;
        while(i < start + num and i < ops.size()) {
            ret := Array.append(ret, [ops[i]]);
            i += 1;
        };
        return ret;
    };
    
    /// Get all update call history.
    public query func getAllRecords() : async [OpRecord] {
        return Array.freeze(ops);
    };

    public query func txAmount() : async Nat {
        return ops.size();
    };

    public query func getSize(): async Nat {
        Prim.rts_memory_size()
    };

    public query func getCycles() : async Nat {
        return ExperimentalCycles.balance();
    };
};