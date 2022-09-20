pragma ton-solidity >=0.56.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./EverduesFeeProxyStorage.sol";
import "../../libraries/ContractTypes.sol";
import "../../libraries/EverduesErrors.sol";
import "../../libraries/EverduesGas.sol";

abstract contract EverduesFeeProxySettings is EverduesFeeProxyStorage {
	modifier onlyRoot() {
		require(
			msg.sender == root,
			EverduesErrors.error_message_sender_is_not_everdues_root
		);
		_;
	}

	modifier onlyDexRoot() {
		require(
			msg.sender == dex_root_address,
			EverduesErrors.error_message_sender_is_not_dex_root
		);
		_;
	}

	modifier onlySubscriptionContract(
		address account_address,
		address service_address
	) {
		address subscription_contract_address = address(
			tvm.hash(
				_buildInitData(
					ContractTypes.Subscription,
					_buildSubscriptionParams(account_address, service_address)
				)
			)
		);
		require(
			msg.sender == subscription_contract_address,
			EverduesErrors.error_message_sender_is_not_my_subscription
		);
		_;
	}

	function setDUESRootAddress(address dues_root, address send_gas_to)
		external
		onlyRoot
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.FEE_PROXY_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		dues_root_address = dues_root;
		send_gas_to.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function setDexRootAddress(address dex_root, address send_gas_to)
		external
		onlyRoot
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.FEE_PROXY_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		dex_root_address = dex_root;
		send_gas_to.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function setRecurringPaymentGas(uint128 recurring_payment_gas_)
		external
		onlyRoot
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.FEE_PROXY_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		recurring_payment_gas = recurring_payment_gas_;
		msg.sender.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function setAccountGasThreshold(
		uint128 account_threshold_,
		address send_gas_to
	) external onlyRoot {
		tvm.rawReserve(
			math.max(
				EverduesGas.FEE_PROXY_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		account_threshold = account_threshold_;
		send_gas_to.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}
}
