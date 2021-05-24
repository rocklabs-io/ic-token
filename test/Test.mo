import M "mo:matchers/Matchers";
import S "mo:matchers/Suite";
import T "mo:matchers/Testable";
import Debug "mo:base/Debug";
import Array "mo:base/Array";

import HashMap "mo:base/HashMap";
import Hash "mo:base/Hash";
import Utils "../src/Utils";

type Account = Utils.AccountIdentifier;

let ParamsInit = S.suite("ParamsInit", do {
    Debug.print("ParamsInit");
    var tests : [S.Suite] = [];

    // token attributes
    let name: Text = "ICP20 Token Canister";
    let decimals: Nat = 3;
    let symbol: Text = "ICP20";
    let totalSupply: Nat = 1_000_000;

    let alice: Account = Utils.textToAccount("53edce14bd498842a06b6178d9fc812bb5f7be45a519151d02a17a9b90044e85");
    let bob : Account = Utils.textToAccount("e28c9efe266e09ef0e2b7fa1e4f18b895ab0be0f1f875256749c3d37d08d799e");


    //let token = Token.Token(name, symbol, decimals, totalSupply);
    // vessel can only test module, not actor.
    tests := Array.append(tests, [S.test("ok", true, M.equals(T.bool(true)))]);
    tests;
});

let suite = S.suite("token", [
    ParamsInit
]);

S.run(suite);