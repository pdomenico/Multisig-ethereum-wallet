// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract Multisig {
    address[] public owners;
    uint256 public requiredConfirmations;
    mapping(address => bool) isOwner;
    struct Transaction {
        address payable to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
    }
    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) isConfirmed;

    event Deposit(address indexed from, uint256 amount, uint256 balance);
    event TxSubmitted(
        address indexed owner,
        uint256 txIndex,
        uint256 value,
        address indexed to,
        bytes data
    );
    event TxConfirmed(address indexed owner, uint256 txIndex);
    event TxExecuted(address indexed owner, uint256 txIndex);
    event ConfirmationRevoked(address indexed owner, uint256 txIndex);

    modifier onlyOwner() {
        require(isOwner[msg.sender]);
        _;
    }

    constructor(address[] memory _owners, uint256 _requiredConfirmations) {
        require(_owners.length > 0, "Need at least one owner!");
        require(
            _requiredConfirmations > 0 &&
                _requiredConfirmations <= _owners.length,
            "Invalid confirmations number!"
        );

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(!isOwner[owner], "Owners must be unique!");
            owners.push(owner);
            isOwner[owner] = true;
        }

        requiredConfirmations = _requiredConfirmations;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTx(
        address payable _to,
        uint256 _value,
        bytes calldata _data
    ) public onlyOwner {
        uint256 txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                confirmations: 0
            })
        );

        emit TxSubmitted(msg.sender, txIndex, _value, _to, _data);
    }

    function confirmTx(uint256 _txIndex) public onlyOwner {
        require(_txIndex < transactions.length);
        require(!isConfirmed[_txIndex][msg.sender]);
        require(!transactions[_txIndex].executed);

        isConfirmed[_txIndex][msg.sender] == true;
        transactions[_txIndex].confirmations++;
        emit TxConfirmed(msg.sender, _txIndex);
    }

    function executeTx(uint256 _txIndex) public onlyOwner {
        require(_txIndex < transactions.length);
        require(!transactions[_txIndex].executed);
        require(transactions[_txIndex].confirmations >= requiredConfirmations);

        (bool executed, ) = transactions[_txIndex].to.call{
            value: transactions[_txIndex].value
        }(transactions[_txIndex].data);

        transactions[_txIndex].executed = executed;
        require(executed, "Transaction failed!");
        emit TxExecuted(msg.sender, _txIndex);
    }

    function revokeConfirmation(uint256 _txIndex) public onlyOwner {
        require(_txIndex < transactions.length);
        require(!transactions[_txIndex].executed);
        require(isConfirmed[_txIndex][msg.sender]);

        transactions[_txIndex].confirmations--;
        isConfirmed[_txIndex][msg.sender] = false;
    }

    function getTransaction(uint256 _txIndex)
        public
        view
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 confirmations
        )
    {
        require(_txIndex < transactions.length);
        Transaction memory transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.confirmations
        );
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTxCount() public view returns (uint256) {
        return transactions.length;
    }
}
