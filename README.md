### Required utilities:

- nodejs (used version v17.x)
- npm (used version 8.3.0)
- tondev (used version 0.11.2)
- solidity compiler(used version 0.57.3)
- tonos-cli(used version 0.24.12)
- tvm_linker(used version 0.14.9)
- stdlib(used version 0.57.3)
- jq
- curl

If you have problems with Solidity compiler, tvm_linker or stdlib versions(after installation higher versions were installed) use the following command to install the optimal versions:

`$tondev sol set --compiler 0.57.3 --linker 0.14.37 --stdlib 0.57.3`

### Installation:

First you need to find the deploy-all.sh file (located in the scipts folder).

Then uncomment the ./deploy-TIP-3.sh USDT and ./deploy-TIP-3.sh EUPI lines and run the `./deploy-all.sh` script itself.

This script deploys TIP-3 tokens(emulation of main net), main smart contract subscription manager, config versions and convert system(which includes mTIP-3 and TIP-3 convert system wallets and mTIP-3 root) with configs.

### Required external repositories 

https://github.com/broxus/ton-eth-bridge-token-contracts.git
https://github.com/broxus/ton-labs-contracts.git
