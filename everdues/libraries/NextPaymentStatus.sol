pragma ton-solidity >=0.56.0;

library NextPaymentStatus {
	uint8 constant STATUS_BALANCE_ENOUGH = 0;
	uint8 constant STATUS_BALANCE_NOT_ENOUGH = 1;
	uint8 constant STATUS_ALLOWANCE_ENOUGH = 2;
	uint8 constant STATUS_ALLOWANCE_NOT_ENOUGH = 3;
	uint8 constant STATUS_ALLOWANCE_AND_BALANCE_ENOUGH = 4;
	uint8 constant STATUS_ALLOWANCE_AND_BALANCE_NOT_ENOUGH = 5;
}