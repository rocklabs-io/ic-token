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
        amount: Nat64;
        fee: Nat64;
        timestamp: Time.Time;
    };
};    
