pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/EverduesErrors.sol";
import "libraries/EverduesGas.sol";
import "libraries/MsgFlag.sol";

contract ServiceIdentificatorIndex {
	address static service_owner;
	address public static service_address;
	address public root;
	TvmCell public identificator;

	modifier onlyOwner() {
		require(
			msg.sender == service_address,
			EverduesErrors.error_message_sender_is_not_service_owner
		);
		_;
	}

	constructor() public {
		optional(TvmCell) salt = tvm.codeSalt(tvm.code());
		require(salt.hasValue(), EverduesErrors.error_salt_is_empty);
		(TvmCell identificator_, address root_) = salt.get().toSlice().decode(
			TvmCell,
			address
		);
		require(
			msg.sender == root_,
			EverduesErrors.error_message_sender_is_not_everdues_root
		);
		tvm.rawReserve(EverduesGas.INDEX_INITIAL_BALANCE, 2);
		root = root_;
		identificator = identificator_;
		service_owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}

	function cancel() external onlyOwner {
		selfdestruct(service_owner);
	}

	function updateIdentificator(TvmCell identificator_, address send_gas_to)
		external
		onlyOwner
	{
		identificator = identificator_;
		send_gas_to.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.REMAINING_GAS + MsgFlag.IGNORE_ERRORS
		});
	}
}
