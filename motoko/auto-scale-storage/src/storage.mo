/**
 * Module     : storage.mo
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
import Types "./types";
import Bucket "./bucket";
import ExperimentalCycles "mo:base/ExperimentalCycles";

shared(msg) actor class Storage(_owner: Principal) = this {
    type Operation = Types.Operation;
    type OpRecord = Types.OpRecord;

    private stable var owner_ : Principal = _owner;
    private stable var token_canister_id_ : Principal = msg.caller;
    private stable var threshold: Nat = 2147483648;
    private stable var cyclesPerBucket: Nat = 1000000000000;

    public type BucketInfo = {
        bucket: Bucket.Bucket;
        var mem_size: Nat;
        var start: Nat;
        var length: Nat;
    };
    // current total number of tx history
    private stable var currentIndex : Nat = 0;
    private stable var bucketNum : Nat = 0;
    private stable var buckets : [var BucketInfo] = [var];

    public shared(msg) func setTokenCanisterId(token: Principal) : async Bool {
        assert(msg.caller == owner_);
        token_canister_id_ := token;
        return true;
    };

    // create a new empty bucket to store tx history, index starts at `start`
    public shared(msg) func newBucket(): async Bucket.Bucket {
        assert(msg.caller == Principal.fromActor(this));
        ExperimentalCycles.add(cyclesPerBucket);
        let b = await Bucket.Bucket();
        let s = await b.getSize();

        var v: BucketInfo = {
            bucket = b;
            var mem_size = s;
            var start = currentIndex;
            var length = 0;
        };
        bucketNum += 1;
        buckets := Array.thaw(Array.append(Array.freeze(buckets), [v]));
        return b;
    };

    // get a bucket to store new tx
    public shared(msg) func getBucket(): async Bucket.Bucket {
        if(bucketNum > 0) {
            // check if reached threshold
            var b: BucketInfo = buckets[bucketNum - 1];
            if(b.mem_size < threshold) {
                return b.bucket;
            };
        };
        // create a new bucket
        await newBucket()
    };

    // update the latest bucket size
    public shared(msg) func updateStatus(): async () {
        if(bucketNum == 0) { return; };
        var info: BucketInfo = buckets[bucketNum - 1];
        info.mem_size := await info.bucket.getSize();
        info.length := currentIndex - info.start;
        buckets[bucketNum - 1] := info;
    };

    public shared(msg) func addRecord(
        caller: Principal, op: Operation, from: ?Principal, to: ?Principal, amount: Nat,
        fee: Nat, timestamp: Time.Time
    ) : async Nat {
        assert(msg.caller == token_canister_id_);
        var b: Bucket.Bucket = await getBucket();
        let index = currentIndex;
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
        await b.addRecord(o);
        currentIndex += 1;
        await updateStatus();
        return index;
    };

    /// Get History by index.
    public func getHistoryByIndex(index: Nat) : async OpRecord {
        var idx : Nat = 0;
        var info : BucketInfo = buckets[idx];
        while(info.start + info.length < index) {
            idx += 1;
            info := buckets[idx];
        };
        await info.bucket.getRecordByIndex(index - info.start)
    };

    /// TODO: impl
    /// Get history in [start, start + num], for paging
    // public query func getHistory(start: Nat, num: Nat) : async [OpRecord] {
        
    // };

    /// TODO: impl
    /// Get history of related to a specific account
    // public query func getHistoryByAccount(a: Principal) : async ?[OpRecord] {
        
    // };
    
    /// Get all history
    public func allHistory() : async [OpRecord] {
        var ret: [OpRecord] = [];
        for(info in Iter.fromArrayMut(buckets)) {
            var ops = await info.bucket.getAllRecords();
            ret := Array.append(ret, ops);
        };
        return ret;
    };

    public query func tokenCanisterId() : async Principal {
        return token_canister_id_;
    };

    public query func owner() : async Principal {
        return owner_;
    };

    public query func txAmount() : async Nat {
        return currentIndex;
    };

    public query func getCycles() : async Nat {
        return ExperimentalCycles.balance();
    };
};