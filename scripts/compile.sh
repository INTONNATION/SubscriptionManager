#!/bin/bash
set -xe

tondev sol compile ../contracts/EverduesRoot.sol -o ../abi;
tondev sol compile ../contracts/EverduesAccount.sol -o ../abi;
tondev sol compile ../contracts/Platform.sol -o ../abi;
tondev sol compile ../contracts/Subscription.sol -o ../abi;
tondev sol compile ../contracts/SubscriptionIndex.sol -o ../abi;
tondev sol compile ../contracts/SubscriptionIdentificatorIndex.sol -o ../abi;
tondev sol compile ../contracts/SubscriptionService.sol -o ../abi;
tondev sol compile ../contracts/SubscriptionServiceIndex.sol -o ../abi;
tondev sol compile ../contracts/SubscriptionServiceIdentificatorIndex.sol -o ../abi;
tondev sol compile ../contracts/EverduesFeeProxy.sol -o ../abi;
