pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/MetaduesErrors.sol";
import "libraries/MetaduesGas.sol";
import "libraries/MsgFlag.sol";

contract SubscriptionServiceIdentificatorIndex {
	address static service_owner;
	address public static service_address;
	address public root;
	TvmCell public identificator;

	modifier onlyOwner() {
		require(
			msg.sender == service_address,
			MetaduesErrors.error_message_sender_is_not_service_owner
		);
		_;
	}

	constructor() public {
		optional(TvmCell) salt = tvm.codeSalt(tvm.code());
		require(salt.hasValue(), MetaduesErrors.error_salt_is_empty);
		(TvmCell identificator_, address root_) = salt.get().toSlice().decode(
			TvmCell,
			address
		);
		require(
			msg.sender == root_,
			MetaduesErrors.error_message_sender_is_not_metadues_root
		);
		tvm.rawReserve(MetaduesGas.INDEX_INITIAL_BALANCE, 2);
		root = root_;
		identificator = identificator_;
		service_owner.transfer({
			value: 0,
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
			flag: MsgFlag.REMAINING_GAS + MsgFlag.IGNORE_ERRORS
		});
	}
}
