pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/EverduesErrors.sol";
import "libraries/EverduesGas.sol";
import "libraries/MsgFlag.sol";

contract SubscriptionServiceIndex {
	string public static service_name;
	address public service_address;
	address public service_owner;
	address public root;

	modifier onlyOwner() {
		require(
			msg.sender == service_address,
			EverduesErrors.error_message_sender_is_not_service_owner
		);
		_;
	}

	constructor(address serviceAddress_) public {
		optional(TvmCell) salt = tvm.codeSalt(tvm.code());
		require(salt.hasValue(), EverduesErrors.error_salt_is_empty);
		(address service_owner_, address root_) = salt.get().toSlice().decode(
			address,
			address
		);
		require(
			msg.sender == root_,
			EverduesErrors.error_message_sender_is_not_everdues_root
		);
		tvm.rawReserve(EverduesGas.INDEX_INITIAL_BALANCE, 2);
		service_owner = service_owner_;
		root = root_;
		service_address = serviceAddress_;
		service_owner.transfer({
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}

	function cancel() external onlyOwner {
		selfdestruct(service_owner);
	}
}
