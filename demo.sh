#!/bin/bash

# set -e

# clear
dfx stop
rm -rf .dfx

ALICE_HOME=$(mktemp -d -t alice-temp)
BOB_HOME=$(mktemp -d -t bob-temp)
DAN_HOME=$(mktemp -d -t dan-temp)
FEE_HOME=$(mktemp -d -t fee-temp)
HOME=$ALICE_HOME

ALICE_PUBLIC_KEY="principal \"$( \
    HOME=$ALICE_HOME dfx identity get-principal
)\""
BOB_PUBLIC_KEY="principal \"$( \
    HOME=$BOB_HOME dfx identity get-principal
)\""
DAN_PUBLIC_KEY="principal \"$( \
    HOME=$DAN_HOME dfx identity get-principal
)\""
FEE_PUBLIC_KEY="principal \"$( \
    HOME=$FEE_HOME dfx identity get-principal
)\""

echo Alice id = $ALICE_PUBLIC_KEY
echo Bob id = $BOB_PUBLIC_KEY
echo Dan id = $DAN_PUBLIC_KEY
echo Fee id = $FEE_PUBLIC_KEY

dfx start --clean --background
dfx canister --no-wallet create --all
dfx build

TOKENID=$(dfx canister --no-wallet id token)
STOREID=$(dfx canister --no-wallet id storage)
TOKENID="principal \"$TOKENID\""
STOREID="principal \"$STOREID\""

echo Token id: $TOKENID
echo Store id: $STOREID

HOME=$ALICE_HOME
eval dfx canister --no-wallet install token --argument="'(\"Test Token\", \"TT\", 3, 1000000, $ALICE_PUBLIC_KEY)'"
eval dfx canister --no-wallet install storage --argument="'($ALICE_PUBLIC_KEY)'"

eval dfx canister --no-wallet call token setStorageCanisterId "'(opt $STOREID)'"
eval dfx canister --no-wallet call storage setTokenCanisterId "'($TOKENID)'"
eval dfx canister --no-wallet call token setFeeTo "'($FEE_PUBLIC_KEY)'"
eval dfx canister --no-wallet call token setFee "'(100)'"
eval dfx canister --no-wallet call token storageGenesis

echo
echo == Initial token balances for Alice and Bob.
echo

echo Alice = $( \
    eval dfx canister --no-wallet call token balanceOf "'($ALICE_PUBLIC_KEY)'" \
)
echo Bob = $( \
    eval dfx canister --no-wallet call token balanceOf "'($BOB_PUBLIC_KEY)'" \
)

echo
echo == Transfer 42 tokens from Alice to Bob. 
echo

eval dfx canister --no-wallet call token transfer "'($BOB_PUBLIC_KEY, 42000)'"

echo
echo == Final token balances for Alice and Bob.
echo

echo Alice = $( \
    eval dfx canister --no-wallet call token balanceOf "'($ALICE_PUBLIC_KEY)'" \
)
echo Bob = $( \
    eval dfx canister --no-wallet call token balanceOf "'($BOB_PUBLIC_KEY)'" \
)

echo
echo == Alice grants Dan permission to spend 50 of her tokens
echo

eval dfx canister --no-wallet call token approve "'($DAN_PUBLIC_KEY, 50000)'"

echo
echo == Alices allowances 
echo

echo Alices allowance for Dan = $( \
    eval dfx canister --no-wallet call token allowance "'($ALICE_PUBLIC_KEY, $DAN_PUBLIC_KEY)'" \
)
echo Alices allowance for Bob = $( \
    eval dfx canister --no-wallet call token allowance "'($ALICE_PUBLIC_KEY, $BOB_PUBLIC_KEY)'" \
)

echo
echo == Dan transfers 40 tokens from Alice to Bob
echo

HOME=$DAN_HOME
eval dfx canister --no-wallet call token transferFrom "'($ALICE_PUBLIC_KEY, $BOB_PUBLIC_KEY, 40000)'"

echo
echo == Token balance for Bob and Alice
echo

echo Alice = $( \
    eval dfx canister --no-wallet call token balanceOf "'($ALICE_PUBLIC_KEY)'" \
)
echo Bob = $( \
    eval dfx canister --no-wallet call token balanceOf "'($BOB_PUBLIC_KEY)'" \
)

echo
echo == Alice allowances
echo

echo Alices allowance for Bob = $( \
    eval dfx canister --no-wallet call token allowance "'($ALICE_PUBLIC_KEY, $BOB_PUBLIC_KEY)'" \
)
echo Alices allowance for Dan = $( \
    eval dfx canister --no-wallet call token allowance "'($ALICE_PUBLIC_KEY, $DAN_PUBLIC_KEY)'" \
)

echo
echo == Dan tries to transfer 20 tokens more from Alice to Bob: Should fail, remaining allowance = 10
echo

eval dfx canister --no-wallet call token transferFrom "'($ALICE_PUBLIC_KEY, $BOB_PUBLIC_KEY, 20000)'"

echo
echo == Alice grants Bob permission to spend 100 of her tokens
echo

HOME=$ALICE_HOME
eval dfx canister --no-wallet call token approve "'($BOB_PUBLIC_KEY, 100000)'"

echo
echo == Alice allowances
echo

echo Alices allowance for Bob = $( \
    eval dfx canister --no-wallet call token allowance "'($ALICE_PUBLIC_KEY, $BOB_PUBLIC_KEY)'" \
)
echo Alices allowance for Dan = $( \
    eval dfx canister --no-wallet call token allowance "'($ALICE_PUBLIC_KEY, $DAN_PUBLIC_KEY)'" \
)

echo
echo == Bob transfers 99 tokens from Alice to Dan
echo

HOME=$BOB_HOME
eval dfx canister --no-wallet call token transferFrom "'($ALICE_PUBLIC_KEY, $DAN_PUBLIC_KEY, 99000)'"

echo
echo == Balances
echo

echo Alice = $( \
    eval dfx canister --no-wallet call token balanceOf "'($ALICE_PUBLIC_KEY)'" \
)
echo Bob = $( \
    eval dfx canister --no-wallet call token balanceOf "'($BOB_PUBLIC_KEY)'" \
)
echo Dan = $( \
    eval dfx canister --no-wallet call token balanceOf "'($DAN_PUBLIC_KEY)'" \
)

echo
echo == Alice allowances
echo

echo Alices allowance for Bob = $( \
    eval dfx canister --no-wallet call token allowance "'($ALICE_PUBLIC_KEY, $BOB_PUBLIC_KEY)'" \
)
echo Alices allowance for Dan = $( \
    eval dfx canister --no-wallet call token allowance "'($ALICE_PUBLIC_KEY, $DAN_PUBLIC_KEY)'" \
)

echo
echo == Dan grants Bob permission to spend 100 of this tokens: Should fail, dan only has 99 tokens
echo

HOME=$DAN_HOME
eval dfx canister --no-wallet call token approve "'($BOB_PUBLIC_KEY, 100000)'"

echo
echo == Dan grants Bob permission to spend 50 of this tokens
echo

eval dfx canister --no-wallet call token approve "'($BOB_PUBLIC_KEY, 50000)'"

echo
echo == Dan allowances
echo

echo Dan allowance for Bob = $( \
    eval dfx canister --no-wallet call token allowance "'($DAN_PUBLIC_KEY, $BOB_PUBLIC_KEY)'" \
)
echo Dan allowance for Alice = $( \
    eval dfx canister --no-wallet call token allowance "'($DAN_PUBLIC_KEY, $ALICE_PUBLIC_KEY)'" \
)

echo
echo == Dan change Bobs permission to spend 40 of this tokens instead of 50
echo

eval dfx canister --no-wallet call token approve "'($BOB_PUBLIC_KEY, 40000)'"

echo
echo == Dan allowances
echo

echo Dan allowance for Bob = $( \
    eval dfx canister --no-wallet call token allowance "'($DAN_PUBLIC_KEY, $BOB_PUBLIC_KEY)'" \
)
echo Dan allowance for Alice = $( \
    eval dfx canister --no-wallet call token allowance "'($DAN_PUBLIC_KEY, $ALICE_PUBLIC_KEY)'" \
)

echo
echo == Dan grants Alice permission to spend 60 of this tokens: Should fail, bob can already spend 40 so there is only 59 left
echo

eval dfx canister --no-wallet call token approve "'($ALICE_PUBLIC_KEY, 60000)'"

echo
echo == Dan allowances
echo

echo Dan allowance for Bob = $( \
    eval dfx canister --no-wallet call token allowance "'($DAN_PUBLIC_KEY, $BOB_PUBLIC_KEY)'" \
)
echo Dan allowance for Alice = $( \
    eval dfx canister --no-wallet call token allowance "'($DAN_PUBLIC_KEY, $ALICE_PUBLIC_KEY)'" \
)

echo
echo == Dan grants Alice permission to spend 59 of his tokens 
echo

eval dfx canister --no-wallet call token approve "'($ALICE_PUBLIC_KEY, 59000)'"

echo
echo == Dan allowances
echo

echo Dan allowance for Bob = $( \
    eval dfx canister --no-wallet call token allowance "'($DAN_PUBLIC_KEY, $BOB_PUBLIC_KEY)'" \
)
echo Dan allowance for Alice = $( \
    eval dfx canister --no-wallet call token allowance "'($DAN_PUBLIC_KEY, $ALICE_PUBLIC_KEY)'" \
)

echo
echo == all History
echo
eval dfx canister --no-wallet call storage allHistory

echo
echo == all holding account
echo
eval dfx canister --no-wallet  call token getAllAccounts

echo
echo == Metadata
echo
dfx canister --no-wallet call token getMetadata

echo
echo == userNumber
echo
dfx canister --no-wallet  call token getUserNumber

dfx stop
