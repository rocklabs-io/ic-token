/**
 * Module     : types.mo
 * Copyright  : 2021 DFinance Team
 * License    : Apache 2.0 with LLVM Exception
 * Maintainer : DFinance Team <hello@dfinance.ai>
 * Stability  : Experimental
 */

import Time "mo:base/Time";

module {
    /// Update call operations
    public type Operation = {
        #mint;
        #burn;
        #transfer;
        #approve;
        #init;
    };
    /// Update call operation record fields
    public type OpRecord = {
        caller: Principal;
        op: Operation;
        index: Nat;
        from: ?Principal;
        to: ?Principal;
        amount: Nat;
        fee: Nat;
        timestamp: Time.Time;
    };
};    
