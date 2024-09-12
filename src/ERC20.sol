// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Used in the `name()` function
// "Yul Token"
bytes32 constant nameLength = 0x0000000000000000000000000000000000000000000000000000000000000009;
bytes32 constant nameData = 0x59756c20546f6b656e0000000000000000000000000000000000000000000000;

// Used in the `symbol()` function
// "YUL"
bytes32 constant symbolLength = 0x0000000000000000000000000000000000000000000000000000000000000003;
bytes32 constant symbolData = 0x59554c0000000000000000000000000000000000000000000000000000000000;

// `bytes4(keccak256("InsufficientBalance()"))`
bytes32 constant insufficientBalanceSelector = 0xf4d678b800000000000000000000000000000000000000000000000000000000;

// `bytes4(keccak256("InsufficientAllowance(address,address)"))`
bytes32 constant insufficientAllowanceSelector = 0xf180d8f900000000000000000000000000000000000000000000000000000000;

bytes32 constant transferEventHash = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

bytes32 constant approveEventHash = 0x8c5be1e5ebec7d5bd14f71427d1e84f3ddbc0c6c0675175b23b6b09cb0a8cce8; // copilot generated

error InsufficientBalance();
error InsufficientAllowance(address owner, address spender);

/// @title Yul ERC20
/// @author Richu A Kuttikattu
/// @notice For demo purposes ONLY.
contract YulERC20 {
    // uint256 public constant MAX_UINT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    // owner -> balance
    mapping(address => uint256) internal _balances;
    // owner -> spender -> allowance
    mapping(address => mapping(address => uint256)) internal _allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() public pure returns (string memory) {
        // solidity needs three slots to store a string(or any dynamic array, I guess?):
        // the first slot holds the pointer to the location where the size of the string is stored,
        // the second is the size of the string, and then the last is the string itself.
        // this loads from the free memory pointer, although it's not required since we're returning from assembly itself
        assembly {
            let memptr := mload(0x40)
            mstore(memptr, 0x20)
            mstore(add(memptr, 0x20), nameLength)
            mstore(add(memptr, 0x40), nameData)
            mstore(0x40, add(memptr, 0x60)) // to update the free memory pointer
            return(memptr, 0x60)
        }
    }

    function symbol() public pure returns (string memory) {
        // this one doesn't do anything with the free memory pointer,
        // since the whole of function body is assembly and we can safely ignore the memptr
        assembly {
            mstore(0x00, 0x20)
            mstore(0x20, symbolLength)
            mstore(0x40, symbolData)
            return(0x00, 0x60)
        }
    }

    function decimals() public pure returns (uint8) {
        assembly {
            mstore(0x00, 0x12)
            return(0x00, 0x20) // the number 18 is stored right most at the 0th slot, hence gotta return the whole 32 bytes
        }
    }

    function balanceOf(address) public view returns (uint256) {
        // return _balances[msg.sender];
        assembly {
            let memptr := mload(0x40) //maybe we need it. Also, safe practice.
            // loads the calldata with 4 byte offset. Calldata would be the 4 byte function selector and the arguments
            // in this case the argument should be just an address
            let account := calldataload(0x04)
            // storing the address and 0x00 to memory, to be passed to keccak256 to find the slot at which the balance is stored
            // value storage slot = keccak256(key, mapping slot)  Is the order important?
            mstore(memptr, account)
            mstore(add(memptr, 0x20), 0x00)
            let balanceSlot := keccak256(memptr, 0x40)
            let accountBalance := sload(balanceSlot)
            mstore(memptr, accountBalance) // overwriting all other stuff, since we got the data now
            return(memptr, 0x20)
        }
    }

    /// an optimised version of the above function with lesser opcodes and less verbosity
    function optimisedBalanceOf(address) public view returns (uint256) {
        assembly {
            mstore(0x00, calldataload(4))
            mstore(0x20, 0x00)
            mstore(0x00, sload(keccak256(0x00, 0x40)))
            return(0x00, 0x20)
        }
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        // require(_balances[msg.sender] >= amount, "InsufficientBalance");
        // _balances[msg.sender] = _balances[msg.sender] - amount;
        // _balances[recipient] = _balances[recipient] + amount;
        // emit Transfer(msg.sender, recipient, amount);
        // return true;

        assembly {
            // loads the sender balance
            let memptr := mload(0x40)
            mstore(memptr, caller())
            mstore(add(memptr, 0x20), 0x00) //because the balance mapping slot is 0x00
            let senderBalanceSlot := keccak256(memptr, 0x40)
            let senderBalance := sload(senderBalanceSlot)

            if lt(senderBalance, amount) {
                // stores the custom error selector to memory to revert
                mstore(memptr, insufficientAllowanceSelector)
                revert(memptr, 0x20)
            }

            // updates sender balance before doing anything else
            let newSenderBalance := sub(senderBalance, amount)
            sstore(senderBalanceSlot, newSenderBalance)

            // loads recipient balance
            // can overwrite the old balances, but just being verbose here
            mstore(memptr, recipient)
            mstore(add(memptr, 0x20), 0x00)
            let recipientBalanceSlot := keccak256(memptr, 0x40)
            let recipientBalance := sload(recipientBalanceSlot)
            let newRecipientBalance := add(recipientBalance, amount)

            sstore(recipientBalanceSlot, newRecipientBalance)

            // emits the transfer event
            mstore(memptr, amount)
            log3(memptr, 0x20, transferEventHash, caller(), recipient)

            mstore(memptr, 0x01)
            return(memptr, 0x20) // returns true
        }
    }
}
