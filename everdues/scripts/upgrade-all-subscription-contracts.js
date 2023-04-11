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
const svcAbiFile = require("../abi/EverduesServiceV1.abi.json");
const subsAbiFile = path.join(__dirname, "../abi/EverduesSubscriptionV1.abi.json");
const subsIndexAbiFile = require("../abi/Index.abi.json");

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

async function eraseChainId(client, subscription_address) {
    const contractPackage = { abi: JSON.parse(fs.readFileSync(subsAbiFile, 'utf8'))};
    const account = new Account(contractPackage, {
        address: subscription_address,
        signer: signerNone(),
        client
    });
    let chain_id_ = await account.run("getMetadata", {});
    console.log(chain_id_);
    //await account.run("eraseChainId", {
    //    chain_id_: chain_id_,
    //});
}

async function executeUpgrade(client, subscription_address, subscription_owner) {
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
            function_name: "forceUpgradeSubscription",
            input: {
                subscription_address: subscription_address,
		subscription_owner: subscription_owner
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
            src: { eq: subscription_address },
            //dst: { eq: account },
        },
        result: "boc"
    });

    console.log('Service recieved upgrade message from root');
    try {
        const decoded = (await client.abi.decode_message({
                        abi: abiContract(subsAbiFile),
                            message: subscriptionMessage.result.boc,
        }));
        console.log(`External outbound message, event "${decoded.name}", parameters`, JSON.stringify(decoded.value));
    } catch {
        console.log(`Wrong subscription contract`);
    }
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

        let response = await accountRoot.runLocal("getCodeHashes", {
            owner_pubkey: 0
        });
        formatCodeHashes0x = Object.keys(response.decoded.output.everdues_contracts_info.versions['2']);
	formatCodeHashes = []
	for (let i = 0; i < formatCodeHashes0x.length; i++) {
            formatCodeHashes.push(formatCodeHashes0x[i].replace(/^0x+/, ''));
        }

        // In the following we query a collection. We get balance of the first wallet.
        // See https://github.com/tonlabs/ever-sdk/blob/master/docs/reference/types-and-methods/mod_net.md#query_collection
        console.log(">> query_collection contract hash");
        services = (await client.net.query_collection({
           collection: 'accounts',
           filter: { code_hash: { in: formatCodeHashes } },
           result: 'id,data,code_hash',
        })).result;
        for (const service of services) {
            console.log(service.id);
	    //upgrade account
	    subscribersHash0x = (await accountRoot.runLocal("subscribersOf", {
                service_address: service.id
	    })).decoded.output.subscribers_code_hash;
	    let subscribersHash = [];
            subscribersHash.push(subscribersHash0x.replace(/^0x+/, ''));
            subscriptionsIndexes = (await client.net.query_collection({
               collection: 'accounts',
               filter: { code_hash: { in: subscribersHash } },
               result: 'id,data,code_hash',
            })).result;
	    for (const subscriptionIndex of subscriptionsIndexes) {
		subscriptionIndexData = (await client.net.query_collection({
                    collection: 'accounts',
                    filter: { id: { eq: subscriptionIndex.id } },
                    result: 'data',
                })).result[0];
                const subscriptionIndexDecodedData = (await client.abi.decode_account_data({
                    abi: abiContract(subsIndexAbiFile),
                    data: subscriptionIndexData.data,
                })).data;
		console.log(subscriptionIndexDecodedData.index_owner);
                const subscriptionOwner = (await client.abi.decode_boc({
                               boc: subscriptionIndexDecodedData.index_static_data,
                               // check all abi types here https://github.com/tonlabs/ton-labs-abi/blob/master/docs/ABI_2.1_spec.md#types
                               params: [
		                   {
                                       name: "subscription_owner",
                                       type: "address",
                                   }
			       ],
                               allow_partial: true,
                })).data.subscription_owner;
		console.log(subscriptionOwner);
	        //await executeUpgrade(client,subscriptionIndexDecodedData.index_owner, subscriptionOwner);
            await eraseChainId(client,subscriptionIndexDecodedData.index_owner);
	    }
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
