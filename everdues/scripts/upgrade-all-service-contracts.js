const { abiContract, TonClient, signerKeys, signerNone } = require("@eversdk/core");
const { Account } = require("@eversdk/appkit");
const { libNode } = require("@eversdk/lib-node");
const fs = require('fs');
const path = require('path');

const KeyPairFileName = 'owner.msig.keys.json';
const msigAbiFileName = '../abi/SafeMultisigWallet.abi.json';
const rootAbiFileName = '../abi/EverduesRoot.abi.json';

const KeyPairFile = path.join(__dirname, KeyPairFileName);
const rootAbiFile = path.join(__dirname, rootAbiFileName);
const msigAbiFile = path.join(__dirname, msigAbiFileName);
const svcAbiFile = path.join(__dirname, "../abi/EverduesServiceV1.abi.json");

const KeyPair = JSON.parse(fs.readFileSync(KeyPairFile, 'utf8'));


const rootType = process.argv.slice(2);
const rootAddrFileName = './envs/'+rootType+'-EverduesRoot.addr';
const rootAddrFile = path.join(__dirname, rootAddrFileName);
const rootAddress = fs.readFileSync(rootAddrFile, 'utf8');


async function getExistingMultisigAccount(client) {
    const contractPackage = { abi: JSON.parse(fs.readFileSync(msigAbiFile, 'utf8'))};
    const account = new Account(contractPackage, {
        address: "0:aba04121a9e69a0140e072ce770ddb012aa828279b1a7c2e6d6f1dbe38e4ceb0",
        signer: signerKeys(KeyPair),
        client
    });
    const address = await account.getAddress();

    console.log(`Multisig address: ${address}`);
    return account;
}
async function getSupportedChains(client, subscription_address) {
    const contractPackage = { abi: JSON.parse(fs.readFileSync(svcAbiFile, 'utf8'))};
    const account = new Account(contractPackage, {
        address: subscription_address,
        signer: signerNone(),
        client
    });
    let supported_chains = await account.runLocal("supported_chains", {});
    console.log(supported_chains);
    return supported_chains.supported_chains;
}

async function getSupportedTokens(client, subscription_address) {
    const contractPackage = { abi: JSON.parse(fs.readFileSync(svcAbiFile, 'utf8'))};
    const account = new Account(contractPackage, {
        address: subscription_address,
        signer: signerNone(),
        client
    });
    let external_supported_tokens = await account.runLocal("external_supported_tokens", {});
    console.log(external_supported_tokens);
    return external_supported_tokens.external_supported_tokens;
}
async function updateData(client,account, supported_chains, external_supported_tokens) {
    const contractPackage = { abi: JSON.parse(fs.readFileSync(svcAbiFile, 'utf8'))};
    const account = new Account(contractPackage, {
        address: subscription_address,
        signer: signerNone(),
        client
    });
    await account.run("updateMapping1", {external_supported_tokens_: external_supported_tokens});
    await account.run("updateMapping2", {supported_chains_: supported_chains});

}
async function executeUpgrade(client, account) {
    if (!fs.existsSync(KeyPairFile)) {
        console.log(`Please place ${KeyPairFileName} file in project root folder with Everdues Root's keys`);
        process.exit(1);
    }
    let multisigAccount = await getExistingMultisigAccount(client);
    const multisigAccountAddress = await multisigAccount.getAddress();

    const payload = (await client.abi.encode_message_body({
        abi: {
                type: 'Contract',
                value: JSON.parse(fs.readFileSync(rootAbiFile, 'utf8')),
        },
        call_set: {
            function_name: "forceUpgradeService",
            input: {
                service_address: account,
        	      category: "Other",
                publish_to_catalog: true
            },
        },
        is_internal: true,
        signer: signerNone(),
    })).body;

	 await multisigAccount.run("sendTransaction", {
   	     dest: rootAddress,
   	     value: 1_000_000_000, 
   	     bounce: false,
   	     flags: 0,
   	     payload
   	 });

   	 console.log("Wait for upgrade answer:");

   	 // Wait for transaction
   	 const subscriptionMessage = await client.net.wait_for_collection({
   	     collection: 'messages',
   	     filter: {
   	         src: { eq: account },
   	         //dst: { eq: account },
   	     },
   	     result: "boc"
   	 });

   	 console.log('Service recieved upgrade message from root');

   	 const decoded = (await client.abi.decode_message({
   	                     abi: abiContract(svcAbiFile),
   	                     message: subscriptionMessage.result.boc,
   	 }));

        console.log(`External outbound message, event "${decoded.name}", parameters`, JSON.stringify(decoded.value));
}

(async () => {
    try {
        // Link the platform-dependable ever-sdk binary with the target Application in Typescript
        // This is a Node.js project, so we link the application with `libNode` binary 
        // from `@eversdk/lib-node` package
        // If you want to use this code on other platforms, such as Web or React-Native,
        // use  `@eversdk/lib-web` and `@eversdk/lib-react-native` packages accordingly
        // (see README in  https://github.com/tonlabs/ever-sdk-js )
        TonClient.useBinaryLibrary(libNode);
        client = new TonClient({
            network: {
                server_address: "https://mainnet.evercloud.dev/a0b43df808ec4afe8d75ef8bdc3054d3"
            }
        });

        // Query the GraphQL API version.
        console.log(">> query without params sample");
        result = (await client.net.query({ "query": "{info{version}}" })).result;
        console.log("GraphQL API version is " + result.data.info.version + '\n');

        rootContractPackage = { abi: JSON.parse(fs.readFileSync(rootAbiFile, 'utf8'))};
        accountRoot = new Account(rootContractPackage, {
           address: rootAddress,
           signer: signerNone(),
           client
        });

        RootAddress = await accountRoot.getAddress();
        console.log(`Everdues Root address: ${RootAddress}`);

        let response = await accountRoot.runLocal("getCatalogCodeHashes", {});
        console.log(response.decoded.output.value0);
        formatCodeHashes0x = ["69c39cff60a06ade6925289ce8f08d1c5e21c19a5cde384e4686ca67fd3a7f2c"];
	    formatCodeHashes = []
        let categories_hash = Object.keys(response.decoded.output.value0);
        
        categories_hash.forEach((hash) => {
            formatCodeHashes.push(response.decoded.output.value0[hash].replace(/^0x+/, ''));
            //formatCodeHashes.push(formatCodeHashes0x[0].replace(/^0x+/, ''));
            console.log(formatCodeHashes);
        });
        // In the following we query a collection. We get balance of the first wallet.
        // See https://github.com/tonlabs/ever-sdk/blob/master/docs/reference/types-and-methods/mod_net.md#query_collection
        console.log(">> query_collection contract hash");
        accounts = (await client.net.query_collection({
           collection: 'accounts',
           filter: { code_hash: { in: formatCodeHashes } },
           result: 'id,data,code_hash',
        })).result;
        for (const account of accounts) {
            console.log(account.id);
	    //upgrade account
        // read external
        let supported_chains = getSupportedChains(client,account.id);
        let external_supported_tokens = getSupportedTokens(client,account.id);
	    await executeUpgrade(client,account.id);
        await updateData(client,account.id,supported_chains,external_supported_tokens);
        
	}

        process.exit(0);
    } catch (error) {
        if (error.code === 504) {
            console.error(`Network is inaccessible. You have to start Evernode SE using \`everdev se start\`.\n If you run SE on another port or ip, replace http://localhost endpoint with http://localhost:port or http://ip:port in index.js file.`);
        } else {
            console.error(error);
        }
    }
})();
