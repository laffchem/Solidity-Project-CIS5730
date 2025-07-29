// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract LendingPlatform is ReentrancyGuard {
    IERC20 public token;          
    uint256 public interestRate;  

    mapping(address => uint256) public lendingBalance;   // Tracks how much each lender has provided
    mapping(address => uint256) public borrowingBalance; // Tracks how much each borrower has borrowed
    mapping(address => uint256) public borrowStartTime;  // Tracks when a borrower took the loan


    constructor(IERC20 _token, uint256 _interestRate) {
        token = _token;
        interestRate = _interestRate;
    }

    // Lend function to transfer tokens from a lender to contract
    function lend(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be greater than zero");
        require(token.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");
        // Update lending balance
        lendingBalance[msg.sender] += _amount;
    }
    
    // Borrow tokens
    function borrow(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be greater than zero");

        // Record borrowing details
        borrowingBalance[msg.sender] += _amount;
        borrowStartTime[msg.sender] = block.timestamp;

        // Transfer borrowed tokens to borrower
        require(token.transfer(msg.sender, _amount), "Token transfer failed");
    }

    // Repay a balance + interest from the borrow to a contract
    function repay() external nonReentrant {
        uint256 borrowedAmount = borrowingBalance[msg.sender];
        require(borrowedAmount > 0, "No outstanding loan");

        uint256 duration = block.timestamp - borrowStartTime[msg.sender];
        uint256 interest = calculateInterest(borrowedAmount, duration);
        uint256 totalRepayment = borrowedAmount + interest;
        require(token.transferFrom(msg.sender, address(this), totalRepayment), "Token transfer failed");
        borrowingBalance[msg.sender] = 0;
        borrowStartTime[msg.sender] = 0;
    }
    // Calculates interest
    function calculateInterest(uint256 _amount, uint256 _duration) public view returns (uint256) {
        return (_amount * interestRate * _duration) / (365 days * 100);
    }
}
