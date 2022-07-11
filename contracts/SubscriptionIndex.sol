pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/EverduesErrors.sol";
import "libraries/EverduesGas.sol";
import "libraries/MsgFlag.sol";

contract SubscriptionIndex {
	address public static subscription_owner;
	address public subscription_address;
	address public root;
	address public service_address;

	modifier onlyOwner() {
		require(
			msg.sender == subscription_address,
			EverduesErrors.error_message_sender_is_not_my_owner
		);
		_;
	}

	constructor(address subscription_address_) public {
		optional(TvmCell) salt = tvm.codeSalt(tvm.code());
		(address service_address_, address root_) = salt.get().toSlice().decode(
			address,
			address
		);
		require(
			msg.sender == root_,
			EverduesErrors.error_message_sender_is_not_root
		);
		tvm.rawReserve(EverduesGas.INDEX_INITIAL_BALANCE, 2);
		root = root_;
		service_address = service_address_;
		subscription_address = subscription_address_;
		subscription_owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}

	function cancel() external onlyOwner {
		selfdestruct(subscription_owner);
	}
}
