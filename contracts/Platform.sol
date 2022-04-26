pragma ton-solidity >=0.39.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/MsgFlag.sol";

interface IPlatformRoot {
	function deployAccount(uint256 pubkey) external;
}

contract Platform {
	address static root;
	uint8 static type_id;
	TvmCell static platform_params;
	uint128 constant DEPLOY_ACCOUNT_MIN_VALUE = 1 ton;
	uint8 constant error_message_sender_is_not_metadues_root = 113;

	constructor(
		TvmCell code,
		TvmCell contract_params,
		uint32 version,
		address send_gas_to,
		uint128 additional_gas
	) public {
		if (msg.isInternal) {
			if (msg.sender == root) {
				_initialize(code, contract_params, version, send_gas_to);
			} else {
				send_gas_to.transfer({
					value: 0,
					flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.DESTROY_IF_ZERO,
					bounce: false
				});
			}
		} else if (msg.isExternal) {
			uint256 pubkey = tvm.pubkey();
			require(msg.pubkey() == pubkey, 100);
			tvm.accept();
			IPlatformRoot(root).deployAccount{
				value: DEPLOY_ACCOUNT_MIN_VALUE + additional_gas,
				bounce: false,
				flag: 0
			}(pubkey);
		}
	}

	function initializeByRoot(
		TvmCell code,
		TvmCell contract_params,
		uint32 version
	) external {
		require(msg.sender == root, error_message_sender_is_not_metadues_root);
		TvmBuilder builder;

		builder.store(root);
		builder.store(uint32(0));
		builder.store(version);
		builder.store(type_id);
		builder.store(tvm.code());
		builder.store(platform_params);
		builder.store(contract_params);
		builder.store(code);

		tvm.setcode(code);
		tvm.setCurrentCode(code);

		onCodeUpgrade(builder.toCell());
	}

	function _initialize(
		TvmCell code,
		TvmCell contract_params,
		uint32 version,
		address send_gas_to
	) private {
		require(msg.sender == root, error_message_sender_is_not_metadues_root);
		TvmBuilder builder;

		builder.store(root);
		builder.store(send_gas_to);
		builder.store(uint32(0));
		builder.store(version);
		builder.store(type_id);
		builder.store(tvm.code());
		builder.store(platform_params);
		builder.store(contract_params);
		builder.store(code);

		tvm.setcode(code);
		tvm.setCurrentCode(code);

		onCodeUpgrade(builder.toCell());
	}

	function onCodeUpgrade(TvmCell data) private {}
}
