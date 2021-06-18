dfx canister --no-wallet create --all
dfx build erc20
dfx canister --no-wallet install erc20 --argument "(\"test token\", \"TT\", 8:nat64, 100000000:nat64)" -m=reinstall
