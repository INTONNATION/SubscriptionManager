pragma ton-solidity >=0.56.0;

interface IEverduesIndex {
    function cancel() external;
    function updateIdentificator(TvmCell identificator_, address send_gas_to) external;
}