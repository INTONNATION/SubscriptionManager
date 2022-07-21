pragma ton-solidity >=0.56.0;

import "./EverduesServiceStorage.sol";
import "../libraries/EverduesErrors.sol";
import "../interfaces/IEverduesIndex.sol";

abstract contract EverduesServiceBase is
	IEverduesService,
	EverduesServiceStorage
{
	constructor() public {
		revert();
	}

	modifier onlyRoot() {
		require(
			msg.sender == root,
			EverduesErrors.error_message_sender_is_not_everdues_root
		);
		_;
	}

	modifier onlyOwner() {
		require(
			msg.pubkey() == owner_pubkey,
			EverduesErrors.error_message_sender_is_not_owner
		);
		_;
	}

	function updateServiceParams(TvmCell new_service_params)
		external
		onlyOwner
	{
		tvm.accept();
		TvmCell subscription_plans_cell;
		(service_params, subscription_plans_cell) = abi.decode(
			new_service_params,
			(TvmCell, TvmCell)
		);
		subscription_plans = abi.decode(
			subscription_plans_cell,
			mapping(uint8 => TvmCell)
		);
	}

	function updateIdentificator(TvmCell index_data)
		external
		view
		onlyOwner
	{
		IEverduesIndex(subscription_service_index_identificator_address)
			.updateIndexData{value: 0, flag: MsgFlag.REMAINING_GAS}(
			index_data,
			address(this)
		);
	}

	function pause() external onlyOwner {
		tvm.accept();
		status = 1;
	}

	function resume() external onlyOwner {
		tvm.accept();
		status = 0;
	}

	function cancel() external override(IEverduesService) onlyOwner {
		emit ServiceDeleted();
		IEverduesIndex(subscription_service_index_address).cancel();
		IEverduesIndex(subscription_service_index_identificator_address)
			.cancel();
		selfdestruct(account_address);
	}
}
