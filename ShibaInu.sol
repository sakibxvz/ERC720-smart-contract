// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract MemeCoin is ERC20, Pausable {
    address public liquidityPool;
    address public multiSigWallet;
    uint256 public liquidityPoolRatio;
    uint256 public redistributionRatio;
    mapping(address => uint256) public allocations;

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address _liquidityPool,
        address _multiSigWallet,
        uint256 _liquidityPoolRatio,
        uint256 _redistributionRatio
    ) ERC20(name, symbol) {
        liquidityPool = _liquidityPool;
        multiSigWallet = _multiSigWallet;
        liquidityPoolRatio = _liquidityPoolRatio;
        redistributionRatio = _redistributionRatio;
        _mint(msg.sender, initialSupply);
    }

    function transfer(address recipient, uint256 amount) public whenNotPaused override returns (bool) {
        uint256 transferAmount = _calculateTransferAmount(amount);
        super.transfer(recipient, transferAmount);
        _redistribute(transferAmount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public whenNotPaused override returns (bool) {
        uint256 transferAmount = _calculateTransferAmount(amount);
        super.transferFrom(sender, recipient, transferAmount);
        _redistribute(transferAmount);
        return true;
    }

    function approve(address spender, uint256 amount) public whenNotPaused override returns (bool) {
        super.approve(spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public whenNotPaused override returns (bool) {
        super.increaseAllowance(spender, addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public whenNotPaused override returns (bool) {
        super.decreaseAllowance(spender, subtractedValue);
        return true;
    }

    function addSignatory(address signatory) public onlyMultiSigWallet {
        allocations[signatory] = 10; // 10% allocation for new signatory
    }

    function removeSignatory(address signatory) public onlyMultiSigWallet {
        allocations[signatory] = 0;
    }

    function addLiquidity(uint256 amount) public onlyLiquidityPool {
        require(amount > 0, "Amount cannot be zero");
        uint256 totalSupply = totalSupply();
        uint256 liquidityPoolTokens = totalSupply * liquidityPoolRatio / 100;
        uint256 tokensToAdd = amount * totalSupply / liquidityPoolTokens;
        _mint(liquidityPool, amount);
        _mint(multiSigWallet, tokensToAdd);
    }

    function removeLiquidity(uint256 amount) public onlyLiquidityPool {
        require(amount > 0, "Amount cannot be zero");
        uint256 liquidityPoolBalance = balanceOf(liquidityPool);
        require(amount <= liquidityPoolBalance, "Insufficient liquidity balance");
        uint256 totalSupply = totalSupply();
        uint256 tokensToRemove = amount * totalSupply / liquidityPoolBalance;
        _burn(liquidityPool, amount);
        _burn(multiSigWallet, tokensToRemove);
    }

    function pause() public onlyMultiSigWallet {
        _pause();
    }

    function unpause() public onlyMultiSigWallet {
    _unpause();
}

function _calculateTransferAmount(uint256 amount) private view returns (uint256) {
    uint256 totalSupply = totalSupply();
    uint256 redistributionAmount = amount * redistributionRatio / 100;
    uint256 redistributionPerAllocation = redistributionAmount / 10; // distribute equally among 10 signatories
    uint256 remainingAmount = amount - redistributionAmount;
    uint256 signatoriesAllocation = 0;
    for (uint256 i = 0; i < 10; i++) {
        signatoriesAllocation += allocations[_owners[i]];
    }
    uint256 signatoriesPercentage = signatoriesAllocation / 100;
    uint256 allocationPerToken = signatoriesPercentage / totalSupply;
    uint256 allocationPerTransfer = allocationPerToken * remainingAmount;
    return remainingAmount - redistributionPerAllocation - allocationPerTransfer;
}

function _redistribute(uint256 amount) private {
    uint256 totalSupply = totalSupply();
    uint256 redistributionAmount = amount * redistributionRatio / 100;
    uint256 redistributionPerAllocation = redistributionAmount / 10; // distribute equally among 10 signatories
    for (uint256 i = 0; i < 10; i++) {
        address recipient = _owners[i];
        uint256 allocationPercentage = allocations[recipient];
        uint256 allocationAmount = allocationPercentage * totalSupply / 100;
        uint256 allocationTokens = redistributionPerAllocation * allocationAmount / redistributionAmount;
        _transfer(multiSigWallet, recipient, allocationTokens);
    }
}

modifier onlyLiquidityPool() {
    require(msg.sender == liquidityPool, "Only liquidity pool can call this function");
    _;
}

modifier onlyMultiSigWallet() {
    require(msg.sender == multiSigWallet, "Only multi-sig wallet can call this function");
    _;
}
