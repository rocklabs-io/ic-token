sudo dfx canister --no-wallet create --all
cargo run erc20 > ./src/erc20/token.did
ic-cdk-optimizer target/wasm32-unknown-unknown/release/erc20.wasm -o target/wasm32-unknown-unknown/release/erc20_opt.wasm
sudo dfx build erc20
sudo dfx canister --no-wallet install erc20 --argument "(\"test token\", \"TT\", 8:nat64, 100000000:nat64)" -m=reinstall
