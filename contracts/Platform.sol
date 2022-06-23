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
	uint8 constant ERROR_MESSAGE_SENDER_IS_NOT_EVERDUES_ROOT = 113;
	uint8 constant ERROR_MESSAGE_SENDER_IS_NOT_OWNER = 112;

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
			require(msg.pubkey() == pubkey, error_message_sender_is_not_owner);
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
		require(msg.sender == root, error_message_sender_is_not_everdues_root);
		TvmCell data = abi.encode(
			root,
			uint32(0),
			version,
			type_id,
			tvm.code(),
			platform_params,
			contract_params,
			code
		);

		tvm.setcode(code);
		tvm.setCurrentCode(code);

		onCodeUpgrade(data);
	}

	function _initialize(
		TvmCell code,
		TvmCell contract_params,
		uint32 version,
		address send_gas_to
	) private {
		require(msg.sender == root, error_message_sender_is_not_everdues_root);
		TvmCell data = abi.encode(
			root,
			send_gas_to,
			uint32(0),
			version,
			type_id,
			tvm.code(),
			platform_params,
			contract_params,
			code
		);

		tvm.setcode(code);
		tvm.setCurrentCode(code);

		onCodeUpgrade(data);
	}

	function onCodeUpgrade(TvmCell data) private {}
}
