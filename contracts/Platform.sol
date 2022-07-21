pragma ton-solidity >=0.39.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/MsgFlag.sol";
import "libraries/PlatformConstants.sol";
import "interfaces/IEverduesRoot.sol";

contract Platform {
	address static root;
	uint8 static type_id;
	TvmCell static platform_params;

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
			require(
				msg.pubkey() == pubkey,
				PlatformConstants.ERROR_MESSAGE_SENDER_IS_NOT_OWNER
			);
			tvm.accept();
			IEverduesRoot(root).deployAccount{
				value: PlatformConstants.DEPLOY_ACCOUNT_MIN_VALUE +
					additional_gas,
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
		require(
			msg.sender == root,
			PlatformConstants.ERROR_MESSAGE_SENDER_IS_NOT_EVERDUES_ROOT
		);
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
		require(
			msg.sender == root,
			PlatformConstants.ERROR_MESSAGE_SENDER_IS_NOT_EVERDUES_ROOT
		);
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
