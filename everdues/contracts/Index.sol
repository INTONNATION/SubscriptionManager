pragma ton-solidity >=0.56.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../libraries/EverduesErrors.sol";
import "../libraries/EverduesGas.sol";
import "../libraries/MsgFlag.sol";

contract Index {
	TvmCell public static index_static_data;
	TvmCell public index_salt_data;
	TvmCell public index_constructor_data;
	address public index_owner;
	address public root;

	modifier onlyOwner() {
		require(
			msg.sender == index_owner,
			EverduesErrors.error_message_sender_is_not_service_owner
		);
		_;
	}

	constructor(TvmCell index_constructor_data_, address send_gas_to) public {
		optional(TvmCell) salt = tvm.codeSalt(tvm.code());
		require(salt.hasValue(), EverduesErrors.error_salt_is_empty);
		(index_salt_data, root) = salt.get().toSlice().decode(TvmCell, address);
		require(
			msg.sender == root,
			EverduesErrors.error_message_sender_is_not_everdues_root
		);
		tvm.rawReserve(EverduesGas.INDEX_INITIAL_BALANCE, 2);
		index_owner = index_constructor_data_.toSlice().decode(address);
		index_constructor_data = index_constructor_data_;
		send_gas_to.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}

	function updateIndexData(TvmCell index_data, address send_gas_to)
		external
		onlyOwner
	{
		index_constructor_data = index_data;
		send_gas_to.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.REMAINING_GAS + MsgFlag.IGNORE_ERRORS
		});
	}

	function cancel(address send_gas_to) external onlyOwner {
		selfdestruct(send_gas_to);
	}
}
