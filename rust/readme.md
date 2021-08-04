## Rust Token Canister Templates


* erc20: simple ERC20 style token canister
* erc20-tx-storage: support history operations storage, token logic and storage in the same canister
* notify: use notify instead of approve

install erc20:
```
dfx canister install erc20 --argument "(\"test token\", \"TT\", 8:nat64, 100000000:nat64)"
```
