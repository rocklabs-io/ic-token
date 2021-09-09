sudo dfx canister --no-wallet create --all
cargo run token > ./token.did
ic-cdk-optimizer target/wasm32-unknown-unknown/release/token.wasm -o target/wasm32-unknown-unknown/release/opt.wasm
sudo dfx build token
sudo dfx canister --no-wallet install erc20 --argument "(\"test token\", \"TT\", 8:nat64, 100000000:nat64)" -m=reinstall
