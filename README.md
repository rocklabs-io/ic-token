## Introduction

Token standard is essential for the Internet Computer ecosystem, especially for the decentralized finance(DeFi) system, this repository contains code of several token canister templates, developers can choose whichever implementation to issue their own tokens.

Token templates:

[motoko](./motoko): token canister templates implemented in motoko:

* [simple-erc20](./motoko/simple-erc20): Simple ERC20 style token canister implemented in motoko
* [erc20-simple-storage](./motoko/erc20-simple-storage): ERC20 style token canister implemented in motoko, support history transaction storage
* [erc20](./motoko/erc20): Improved ERC20 style token canister template implemented in motoko, support history transaction storage in a seperate storage canister

[rust](./rust): token canister templates implemented in Rust:

* [erc20](./rust/src/erc20): Rust implementation of ERC20 style token canister template
* [notify](./rust/src/notify): Rust implementation of notify scheme token canister template



## Development

You need the latest DFINITY Canister SDK to be able to build and deploy a token canister:

```shell
sh -ci "$(curl -fsSL https://sdk.dfinity.org/install.sh)"
```

Navigate to a token sub directory and start a local development network:

```shell
cd erc20
dfx start --background
```

Create canisters:

```shell
dfx canister create --all
```

Install code for token canister:

```
dfx build

dfx canister install token --argument="(\"<NAME>\", \"<SYMBOL>\", <DECIMALS>, <TOTAL_SUPPLY>, <YOUR_PRINCIPAL_ID>)"
e.g.:
dfx canister install token --argument="(\"DFinance Coin\", \"DFC\", 8, 10000000000000000, principal \"4qehi-lqyo6-afz4c-hwqwo-lubfi-4evgk-5vrn5-rldx2-lheha-xs7a4-gae\")"
```

Refer to `demo.sh` in the corresponding sub directory for more details.



## Contributing

We'd like to collaborate with the community to provide more and better token template options for the developers on the IC, if you have some ideas you'd like to discuss, submit an issue, if you want to improve the code or you made a different implementation, make a pull request!

