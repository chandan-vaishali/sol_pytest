// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IERC20.sol";
import "./interfaces/IExchange.sol";

contract RUExchange is IExchange {
    IERC20 public token;
    uint8 public feePercent;
    uint public tokenReserve;
    uint public ethReserve;
    bool private initialized;

    string public name = "RU Liquidity Token";
    string public symbol = "RULT";
    uint8 public decimals = 18;
    uint public totalSupply;

    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    constructor() {}

    function initialize(IERC20 _token, uint8 _feePercent, uint _initialTokens, uint _initialETH) external payable override returns (uint) {
        require(!initialized, "Already initialized");
        require(msg.value >= _initialETH, "Not enough ETH sent");
        require(_initialTokens > 0 && _initialETH > 0, "Initial amounts must be greater than 0");
        
        token = _token;
        feePercent = _feePercent;
        tokenReserve = _initialTokens;
        ethReserve = _initialETH;
        initialized = true;

        require(token.transferFrom(msg.sender, address(this), _initialTokens), "Token transfer failed");

        uint initialLiquidity = sqrt(_initialTokens * _initialETH);
        _mint(msg.sender, initialLiquidity);

        if (msg.value > _initialETH) {
            payable(msg.sender).transfer(msg.value - _initialETH);
        }
        return initialLiquidity;
    }

    // Helper function to calculate square root
    function sqrt(uint x) internal pure returns (uint y) {
        if (x == 0) return 0;
        if (x <= 3) return 1;
        
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function buyTokens(uint amount, uint maxPrice) external payable override returns (uint, uint, uint) {
        require(initialized, "Not initialized");
        require(amount > 0, "Amount must be greater than 0");
        require(msg.value > 0, "ETH required to buy tokens");

        uint newTokenReserve = tokenReserve - amount;
        uint newEthReserve = (tokenReserve * ethReserve) / newTokenReserve;
        uint ethRequired = newEthReserve - ethReserve;

        // Calculate total payment including fee
        uint totalEthRequired = (ethRequired * 100) / (100 - feePercent);
        
        // Calculate fee
        uint ethFee = totalEthRequired - ethRequired;

        require(msg.value >= totalEthRequired, "Insufficient ETH provided");
        require(maxPrice >= totalEthRequired, "ETH exceeds max price");

        // Calculate token fee
        uint tokenFee = (amount * feePercent + 99) / 100; // Round up
        uint tokensToTransfer = amount - tokenFee;

        require(token.transfer(msg.sender, tokensToTransfer), "Token transfer failed");

        // Update reserves
        tokenReserve = newTokenReserve + tokenFee; // Add tokenFee back to reserve
        ethReserve = newEthReserve;

        if (msg.value > totalEthRequired) {
            payable(msg.sender).transfer(msg.value - totalEthRequired);
        }

        emit FeeDetails(totalEthRequired, ethFee, tokenFee);
        return (totalEthRequired, ethFee, tokenFee);
    }

    function sellTokens(uint amount, uint minPrice) external override returns (uint, uint, uint) {
        require(initialized, "Not initialized");
        require(amount > 0, "Amount must be greater than 0");

        uint tokenFee = (amount * feePercent) / 100;
        uint tokensToSwap = amount - tokenFee;

        uint ethAmount = (ethReserve * tokensToSwap) / (tokenReserve + tokensToSwap);
        uint ethFee = (ethAmount * feePercent) / 100;
        uint ethToTransfer = ethAmount - ethFee;

        require(ethToTransfer >= minPrice, "Price below minimum");

        tokenReserve += amount;
        ethReserve -= ethAmount;

        require(token.transferFrom(msg.sender, address(this), amount), "Token transfer failed");
        payable(msg.sender).transfer(ethToTransfer);

        emit FeeDetails(ethAmount, ethFee, tokenFee);
        return (ethAmount, ethFee, tokenFee);
    }

    function mintLiquidityTokens(uint amount, uint maxTokens, uint maxETH) external payable override returns (uint, uint) {
        require(initialized, "Not initialized");
        require(amount > 0, "Amount must be greater than 0");
        require(totalSupply > 0, "No liquidity tokens exist");

        uint tokenAmount = (amount * tokenReserve) / totalSupply;
        uint ethAmount = (amount * ethReserve) / totalSupply;

        require(tokenAmount <= maxTokens, "Token amount exceeds maximum");
        require(ethAmount <= maxETH, "ETH amount exceeds maximum");
        require(msg.value >= ethAmount, "Not enough ETH sent");

        // Transfer tokens from the user to the contract
        require(token.transferFrom(msg.sender, address(this), tokenAmount), "Token transfer failed");

        // Update reserves
        tokenReserve += tokenAmount;
        ethReserve += ethAmount;

        // Mint liquidity tokens
        _mint(msg.sender, amount);

        // Refund excess ETH
        if (msg.value > ethAmount) {
            payable(msg.sender).transfer(msg.value - ethAmount);
        }

        emit MintBurnDetails(tokenAmount, ethAmount);
        return (tokenAmount, ethAmount);
    }

    function burnLiquidityTokens(uint amount, uint minTokens, uint minETH) external payable override returns (uint, uint) {
        require(initialized, "Not initialized");
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");

        uint tokenAmount = (amount * tokenReserve) / totalSupply;
        uint ethAmount = (amount * ethReserve) / totalSupply;

        require(tokenAmount >= minTokens, "Token amount below minimum");
        require(ethAmount >= minETH, "ETH amount below minimum");

        tokenReserve -= tokenAmount;
        ethReserve -= ethAmount;

        _burn(msg.sender, amount);
        require(token.transfer(msg.sender, tokenAmount), "Token transfer failed");
        payable(msg.sender).transfer(ethAmount);

        emit MintBurnDetails(tokenAmount, ethAmount);
        return (tokenAmount, ethAmount);
    }

    function getToken() external view override returns (IERC20) {
        return token;
    }

    function tokenBalance() external view override returns (uint) {
        return tokenReserve;
    }

    function transfer(address recipient, uint amount) external override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint amount) external override returns (bool) {
        require(allowance[sender][msg.sender] >= amount, "Transfer amount exceeds allowance");
        allowance[sender][msg.sender] -= amount;
        _transfer(sender, recipient, amount);
        return true;
    }

    function _transfer(address sender, address recipient, uint amount) internal {
        require(sender != address(0), "Transfer from the zero address");
        require(recipient != address(0), "Transfer to the zero address");
        require(balanceOf[sender] >= amount, "Transfer amount exceeds balance");
        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint amount) internal {
        require(account != address(0), "Mint to the zero address");
        totalSupply += amount;
        balanceOf[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint amount) internal {
        require(account != address(0), "Burn from the zero address");
        require(balanceOf[account] >= amount, "Burn amount exceeds balance");
        totalSupply -= amount;
        balanceOf[account] -= amount;
        emit Transfer(account, address(0), amount);
    }

    receive() external payable {}
}