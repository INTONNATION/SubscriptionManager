### Required utilities:

- nodejs (used version v17.x)
- npm (used version 8.3.0)
- everdev (used version 1.2.2)
- jq
- curl

Before do any action please install Everdev utility and use the following command to install the optimal versions:

 - Everdev installation guide: 
    https://github.com/tonlabs/everdev

 - Use this command to configure expected versions:
   `$everdev sol set --compiler 0.61.2 --linker 0.14.37 --stdlib 0.57.3`

###### JUST NOTE you must have cloned all git submodules of this repo, check this point in other case use this command: 

`git pull --recurse-submodules`

###### To checkout proper commits in your submodules you should update them after pulling using

`git submodule update --recursive`

### Deploy:

Find the deployment script in `everdues/scripts` folder and run the script:

`./deploy-all.sh $ENVIRONMENT_NAME`

The list of environments you can find in the envs/ folder.
#### Existing list of environments:
- dev
- test
- prod

###### Just note that in current stage deployment script have a lot hard-coded values, please check it before you want to configure the new root contract.

### Upgrade existing root contract:

Find the deployment script in `everdues/scripts` folder and run the script:

`./upgrade-all.sh $ENVIRONMENT_NAME`

The list of environments you can find in the envs/ folder.
#### Existing list of environments:
- dev
- test
- prod

##### Public/Private keys and owner address for root contract you can find in `everdues/scripts` folder. Just note that production environment use multisig owner account. Someone from the team have to sign every transaction during deploy/upgrade process:
 - Owner address for development environments: 
     `dev-single.msig.addr`
 - Owner address for prod environment: 
    `prod-multisig.msig.addr`

Keys: `owner.msig.keys.json `