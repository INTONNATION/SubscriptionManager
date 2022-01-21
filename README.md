### Project deployment guide
#### Required utilities:    
Install curl (used version 7.68.0).    
$ apt install curl    
Next, install nodejs (used version v17.x) and npm (used version 8.3.0).    
$ curl -fsSL https://deb.nodesource.com/setup_17.x | sudo -E bash -    
$ sudo apt-get install -y nodejs    
Install tondev using npm (used version 0.11.2).    
$ sudo npm install -g tondev    
Install the  solidity compiler (used version 0.51.0) through tondev.    
$ tondev sol update    
Also, through tondev, install the command utility for working with blockchain tonos-cli (used version 0.24.12).    
$ tondev tonos-cli install    
Install docker (used version 20.10.12).    
$ curl -fsSL https://get.docker.com -o get-docker.sh    
$ sh get-docker.sh    
Next, install yarn (used version 1.22.17) and jq (used version 1.6).    
$ npm install --global yarn    
$ apt install jq    
tvm_linker is installed along with the solidity compiler, but if the tvm_linker not found error occurs, run the following command:    
$ ln -s /home/ubuntu/.tondev/solidity/tvm_linker / usr / bin / tvm_linker    
Instead of ubuntu, substitute your user    

Then find the deploy-all.sh file, in it we uncomment the lines ./deploy-TIP-3.sh USDT and ./deploy-TIP-3.sh EUPI. Then execute ./deploy-all.sh and after ./build.sh.    
After successful compiletion, we go to localhost, log into the wallet and can proceed to familiarization.    
