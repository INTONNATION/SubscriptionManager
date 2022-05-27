#Enviroments:

>>main - stable branch
>>test - main branch
>>dev - development branch

# Scripts

1. ```deploy-all.sh``` - generate new keypair and deploy new root from scratch and store address at scripts/EverduesRoot.addr
2. ```upgrade-all.sh``` - compile and set new version for all contracts on current root (EverduesRoot.addr). After upgrade deploy new contracts or upgrade existing one by tonos-cli.
3. ```upgrade-account-code.sh``` - compile and set new account version in root. After code upgrade do not forget to upgrade your currect account by ```tonos-cli call <account_address> upgradeAccount "{\"additional_gas\":0}" --abi ../abi/EverduesAccount.abi.json --sign <account seed>``` execution 
4. ```upgrade-everdues-root.sh``` - updates only root (without data modification)
5. ```upgrade-feeproxy-code.sh``` - compile and set new feeproxy version in root. Call ```tonos-cli call <account_address> upgradeFeeProxy "{}" --abi ../abi/EverduesRoot.abi.json --sign devnet.keys.json```
6. ```upgrade-service-code.sh``` - compile and set new service version in root. After code upgrade do not forget to upgrade your service by ```tonos-cli call <account_address> upgradeService "{\"service_name\":"","category":"","additional_gas":0}" --abi ../abi/EverduesAccount.abi.json --sign <account seed>``` 