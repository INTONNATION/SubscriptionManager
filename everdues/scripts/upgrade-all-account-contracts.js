const { abiContract, TonClient, signerKeys, signerNone } = require("@eversdk/core");
const { Account } = require("@eversdk/appkit");
const { libNode } = require("@eversdk/lib-node");
const fs = require('fs');
const path = require('path');

const KeyPairFileName = 'owner.msig.keys.json';
const msigAbiFileName = '../abi/SafeMultisigWallet.abi.json';
const rootAbiFileName = '../abi/EverduesRoot.abi.json';
const accAbiFile = require("../abi/EverduesAccountV1.abi.json");

const KeyPairFile = path.join(__dirname, KeyPairFileName);
const rootAbiFile = path.join(__dirname, rootAbiFileName);
const msigAbiFile = path.join(__dirname, msigAbiFileName);

const KeyPair = JSON.parse(fs.readFileSync(KeyPairFile, 'utf8'));


const rootType = process.argv[2];
const owner = process.argv[3];
const rootAddrFileName = './envs/'+rootType+'-EverduesRoot.addr';
const rootAddrFile = path.join(__dirname, rootAddrFileName);
const rootAddress = fs.readFileSync(rootAddrFile, 'utf8');


async function getExistingMultisigAccount(client) {
    const contractPackage = { abi: JSON.parse(fs.readFileSync(msigAbiFile, 'utf8'))};
    account = new Account(contractPackage, {
        address: owner,
        signer: signerKeys(KeyPair),
        client
    });
    address = await account.getAddress();

    console.log(`Multisig address: ${address}`);
    return account;
}

async function getExistingEverduesAccount(client, address) {
    const contractPackage = { abi: accAbiFile };
    account = new Account(contractPackage, {
        address: address,
        signer: signerKeys(KeyPair),
        client
    });
    address = await account.getAddress();

    console.log(`Account address: ${address}`);
    return account;
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
            function_name: "forceUpgradeAccount",
            input: {
                account_address: account,
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
	                abi: abiContract(accAbiFile),
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

        let response = await accountRoot.runLocal("getCodeHashes", {
            owner_pubkey: 0
        });
        formatCodeHashes0x = Object.keys(response.decoded.output.everdues_contracts_info.versions['1']);
	formatCodeHashes = []
	for (let i = 0; i < formatCodeHashes0x.length; i++) {
            formatCodeHashes.push(formatCodeHashes0x[i].replace(/^0x+/, ''));
        }

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
	    let accAccount = await getExistingEverduesAccount(client, account.id);
            const accAccountAddress = await accAccount.getAddress();
	    let accRoot = await accAccount.runLocal("root", {});
	    if (accRoot.decoded.output.root == RootAddress) {
	        // upgrade account
	        await executeUpgrade(client,account.id);
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
