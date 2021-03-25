#!/bin/bash

set -e

echo PATH = $PATH

# clear
dfx stop
rm -rf .dfx

ALICE_HOME=$(mktemp -d -t alice-temp)
BOB_HOME=$(mktemp -d -t bob-temp)
DAN_HOME=$(mktemp -d -t dan-temp)
HOME=$ALICE_HOME

dfx start --background
dfx canister create --all
dfx build
dfx canister install --all

ALICE_PUBLIC_KEY="principal \"$( \
    HOME=$ALICE_HOME dfx canister call token callerPrincipal \
        | awk -F '"' '{printf $2}' \
)\""
BOB_PUBLIC_KEY="principal \"$( \
    HOME=$BOB_HOME dfx canister call token callerPrincipal \
        | awk -F '"' '{printf $2}' \
)\""
DAN_PUBLIC_KEY="principal \"$( \
    HOME=$DAN_HOME dfx canister call token callerPrincipal \
        | awk -F '"' '{printf $2}' \
)\""

echo Alice id = $ALICE_PUBLIC_KEY
echo Bob id = $BOB_PUBLIC_KEY
echo Dan id = $DAN_PUBLIC_KEY

echo 
echo == Initialize token template.
echo 
eval dfx canister call token initialize "'(\"test token\", \"TT\", 0, 1000)'"

echo
echo == Initial token balances for Alice and Bob.
echo

echo Alice = $( \
    eval dfx canister call token balanceOf "'($ALICE_PUBLIC_KEY)'" \
)
echo Bob = $( \
    eval dfx canister call token balanceOf "'($BOB_PUBLIC_KEY)'" \
)

echo
echo == Transfer 42 tokens from Alice to Bob.
echo

eval dfx canister call token transfer "'($BOB_PUBLIC_KEY, 42)'"

echo
echo == Final token balances for Alice and Bob.
echo

echo Alice = $( \
    eval dfx canister call token balanceOf "'($ALICE_PUBLIC_KEY)'" \
)
echo Bob = $( \
    eval dfx canister call token balanceOf "'($BOB_PUBLIC_KEY)'" \
)

echo
echo == Alice grants Dan permission to spend 50 of her tokens
echo

eval dfx canister call token approve "'($DAN_PUBLIC_KEY, 50)'"

echo
echo == Alices allowances 
echo

echo Alices allowance for Dan = $( \
    eval dfx canister call token allowance "'($ALICE_PUBLIC_KEY, $DAN_PUBLIC_KEY)'" \
)
echo Alices allowance for Bob = $( \
    eval dfx canister call token allowance "'($ALICE_PUBLIC_KEY, $BOB_PUBLIC_KEY)'" \
)

echo
echo == Dan transfers 40 tokens from Alice to Bob
echo

HOME=$DAN_HOME
eval dfx canister call token transferFrom "'($ALICE_PUBLIC_KEY, $BOB_PUBLIC_KEY, 40)'"

echo
echo == Token balance for Bob and Alice
echo

echo Alice = $( \
    eval dfx canister call token balanceOf "'($ALICE_PUBLIC_KEY)'" \
)
echo Bob = $( \
    eval dfx canister call token balanceOf "'($BOB_PUBLIC_KEY)'" \
)

echo
echo == Alice allowances
echo

echo Alices allowance for Bob = $( \
    eval dfx canister call token allowance "'($ALICE_PUBLIC_KEY, $BOB_PUBLIC_KEY)'" \
)
echo Alices allowance for Dan = $( \
    eval dfx canister call token allowance "'($ALICE_PUBLIC_KEY, $DAN_PUBLIC_KEY)'" \
)

echo
echo == Dan tries to transfer 20 tokens more from Alice to Bob: Should fail, remaining allowance = 10
echo

eval dfx canister call token transferFrom "'($ALICE_PUBLIC_KEY, $BOB_PUBLIC_KEY, 20)'"

echo
echo == Alice grants Bob permission to spend 100 of her tokens
echo

HOME=$ALICE_HOME
eval dfx canister call token approve "'($BOB_PUBLIC_KEY, 100)'"

echo
echo == Alice allowances
echo

echo Alices allowance for Bob = $( \
    eval dfx canister call token allowance "'($ALICE_PUBLIC_KEY, $BOB_PUBLIC_KEY)'" \
)
echo Alices allowance for Dan = $( \
    eval dfx canister call token allowance "'($ALICE_PUBLIC_KEY, $DAN_PUBLIC_KEY)'" \
)

echo
echo == Bob transfers 99 tokens from Alice to Dan
echo

HOME=$BOB_HOME
eval dfx canister call token transferFrom "'($ALICE_PUBLIC_KEY, $DAN_PUBLIC_KEY, 99)'"

echo
echo == Balances
echo

echo Alice = $( \
    eval dfx canister call token balanceOf "'($ALICE_PUBLIC_KEY)'" \
)
echo Bob = $( \
    eval dfx canister call token balanceOf "'($BOB_PUBLIC_KEY)'" \
)
echo Dan = $( \
    eval dfx canister call token balanceOf "'($DAN_PUBLIC_KEY)'" \
)

echo
echo == Alice allowances
echo

echo Alices allowance for Bob = $( \
    eval dfx canister call token allowance "'($ALICE_PUBLIC_KEY, $BOB_PUBLIC_KEY)'" \
)
echo Alices allowance for Dan = $( \
    eval dfx canister call token allowance "'($ALICE_PUBLIC_KEY, $DAN_PUBLIC_KEY)'" \
)

echo
echo == Dan grants Bob permission to spend 100 of this tokens: Should fail, dan only has 99 tokens
echo

HOME=$DAN_HOME
eval dfx canister call token approve "'($BOB_PUBLIC_KEY, 100)'"

echo
echo == Dan grants Bob permission to spend 50 of this tokens
echo

eval dfx canister call token approve "'($BOB_PUBLIC_KEY, 50)'"

echo
echo == Dan allowances
echo

echo Dan allowance for Bob = $( \
    eval dfx canister call token allowance "'($DAN_PUBLIC_KEY, $BOB_PUBLIC_KEY)'" \
)
echo Dan allowance for Alice = $( \
    eval dfx canister call token allowance "'($DAN_PUBLIC_KEY, $ALICE_PUBLIC_KEY)'" \
)

echo
echo == Dan change Bobs permission to spend 40 of this tokens instead of 50
echo

eval dfx canister call token approve "'($BOB_PUBLIC_KEY, 40)'"

echo
echo == Dan allowances
echo

echo Dan allowance for Bob = $( \
    eval dfx canister call token allowance "'($DAN_PUBLIC_KEY, $BOB_PUBLIC_KEY)'" \
)
echo Dan allowance for Alice = $( \
    eval dfx canister call token allowance "'($DAN_PUBLIC_KEY, $ALICE_PUBLIC_KEY)'" \
)

echo
echo == Dan grants Alice permission to spend 60 of this tokens: Should fail, bob can already spend 40 so there is only 59 left
echo

eval dfx canister call token approve "'($ALICE_PUBLIC_KEY, 60)'"

echo
echo == Dan allowances
echo

echo Dan allowance for Bob = $( \
    eval dfx canister call token allowance "'($DAN_PUBLIC_KEY, $BOB_PUBLIC_KEY)'" \
)
echo Dan allowance for Alice = $( \
    eval dfx canister call token allowance "'($DAN_PUBLIC_KEY, $ALICE_PUBLIC_KEY)'" \
)

echo
echo == Dan grants Alice permission to spend 59 of his tokens 
echo

eval dfx canister call token approve "'($ALICE_PUBLIC_KEY, 59)'"

echo
echo == Dan allowances
echo

echo Dan allowance for Bob = $( \
    eval dfx canister call token allowance "'($DAN_PUBLIC_KEY, $BOB_PUBLIC_KEY)'" \
)
echo Dan allowance for Alice = $( \
    eval dfx canister call token allowance "'($DAN_PUBLIC_KEY, $ALICE_PUBLIC_KEY)'" \
)

dfx stop