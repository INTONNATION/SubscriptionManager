pragma ton-solidity >=0.56.0;

library EverduesSubscriptionStatus {
	uint8 constant STATUS_ACTIVE = 1;
	uint8 constant STATUS_NONACTIVE = 2;
	uint8 constant STATUS_PROCESSING = 3;
	uint8 constant STATUS_STOPPED = 4;
	uint8 constant STATUS_EXECUTE = 5;
}
