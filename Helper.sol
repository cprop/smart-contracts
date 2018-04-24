pragma solidity ^0.4.19;

contract owned {
    address public owner;

    function owned() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner public {
        owner = newOwner;
    }
}

contract admined is owned {
    address public admin;

    function admined() public {
        admin = msg.sender;
    }

    modifier onlyAdmin {
        require(msg.sender == admin || msg.sender == owner);
        _;
    }

    function transferAdmin(address newAdmin) onlyOwner public {
        admin = newAdmin;
    }
}
