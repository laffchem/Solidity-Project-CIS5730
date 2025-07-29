// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract LendingPlatformWithCollateral is ReentrancyGuard {
    IERC20 public token;
    uint256 public interestRate;

    mapping(address => uint256) public lendingBalance;
    mapping(address => uint256) public borrowingBalance;
    mapping(address => uint256) public borrowStartTime;
    mapping(address => uint256) public collateralBalance;

    uint256 public collateralRatio = 150; // Requires 150% collateral

    constructor(IERC20 _token, uint256 _interestRate) {
        token = _token;
        interestRate = _interestRate;
    }

    // lending function for tokens on the platform
    function lend(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be greater than zero");
        require(token.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");
        lendingBalance[msg.sender] += _amount;
    }

    // Ether as collateral
    function depositCollateral() external payable nonReentrant {
        require(msg.value > 0, "Must send Ether");
        collateralBalance[msg.sender] += msg.value;
    }

    // Borrow tokens against provided collateral
    function borrow(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be greater than zero");
        uint256 requiredCollateral = (_amount * collateralRatio) / 100;
        require(collateralBalance[msg.sender] >= requiredCollateral, "Insufficient collateral");

        borrowingBalance[msg.sender] += _amount;
        borrowStartTime[msg.sender] = block.timestamp;

        require(token.transfer(msg.sender, _amount), "Token transfer failed");
    }

    // Repay the borrowed amount, collateral is released
    function repay() external nonReentrant {
        uint256 borrowedAmount = borrowingBalance[msg.sender];
        require(borrowedAmount > 0, "No outstanding loan");

        uint256 duration = block.timestamp - borrowStartTime[msg.sender];
        uint256 interest = calculateInterest(borrowedAmount, duration);
        uint256 totalRepayment = borrowedAmount + interest;

        require(token.transferFrom(msg.sender, address(this), totalRepayment), "Token transfer failed");

        borrowingBalance[msg.sender] = 0;
        borrowStartTime[msg.sender] = 0;

        uint256 releasedCollateral = collateralBalance[msg.sender];
        collateralBalance[msg.sender] = 0;

        payable(msg.sender).transfer(releasedCollateral);
    }

    // withdraw collateral function, will not allow if an outstanding loan exists.
    function withdrawCollateral(uint256 _amount) external nonReentrant {
        require(borrowingBalance[msg.sender] == 0, "Outstanding loan exists");
        require(_amount <= collateralBalance[msg.sender], "Not enough collateral");

        collateralBalance[msg.sender] -= _amount;
        payable(msg.sender).transfer(_amount);
    }

    // Calculate interest based on time
    function calculateInterest(uint256 _amount, uint256 _duration) public view returns (uint256) {
        return (_amount * interestRate * _duration) / (365 days * 100);
    }

    // Fallback to receive Ether
    receive() external payable {
        collateralBalance[msg.sender] += msg.value;
    }
}
