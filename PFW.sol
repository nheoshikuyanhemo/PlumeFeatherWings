solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PFW is ERC20, ERC20Burnable, ReentrancyGuard, Ownable {
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 public constant _totalSupply = 1500000000 * 10**18; // 1.5 billion tokens with 18 decimals
    uint256 private buyTaxFee = 10; // 0.1% buy tax fee (out of 10000)
    uint256 private sellTaxFee = 10; // 0.1% sell tax fee (out of 10000)
    uint256 private liquidityTaxFee = 10; // 0.1% liquidity tax fee (out of 10000)
    uint256 private denominator = 10000; // denominator for tax calculations

    address private taxWallet;

    constructor(address _taxWallet) ERC20("Plume Feather Wings", "PFW") Ownable(msg.sender) {
        _mint(msg.sender, _totalSupply);
        taxWallet = _taxWallet;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        uint256 taxAmount;
        if (_isExcludedFromFee[sender] || _isExcludedFromFee[recipient]) {
            // No tax applied
            super._transfer(sender, recipient, amount);
        } else {
            // Calculate tax
            if (sender == uniswapV2Pair) {
                // Buy tax
                taxAmount = (amount * buyTaxFee) / denominator;
            } else if (recipient == uniswapV2Pair) {
                // Sell tax
                taxAmount = (amount * sellTaxFee) / denominator;
            } else {
                // Liquidity tax (for transfers between wallets)
                taxAmount = (amount * liquidityTaxFee) / denominator;
            }

            uint256 sendAmount = amount - taxAmount;
            super._transfer(sender, taxWallet, taxAmount);
            super._transfer(sender, recipient, sendAmount);
        }
    }

    // Function to set tax wallet
    function setTaxWallet(address _newTaxWallet) external onlyOwner {
        require(_newTaxWallet != address(0), "Tax wallet cannot be zero address");
        taxWallet = _newTaxWallet;
    }

    // Function to update tax fees
    function updateTaxFees(uint256 _buyTaxFee, uint256 _sellTaxFee, uint256 _liquidityTaxFee) external onlyOwner {
        buyTaxFee = _buyTaxFee;
        sellTaxFee = _sellTaxFee;
        liquidityTaxFee = _liquidityTaxFee;
    }

    // Uniswap pair address (to be set after deployment and creation of the pair)
    address public uniswapV2Pair;

    function setUniswapV2Pair(address _uniswapV2Pair) external onlyOwner {
        uniswapV2Pair = _uniswapV2Pair;
    }

    // Coin rescue function
    function rescueTokens(address tokenAddress, uint256 amount) external onlyOwner {
        require(tokenAddress != address(this), "Cannot rescue native token");
        IERC20(tokenAddress).transfer(owner(), amount);
    }

    function rescueETH() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
}
```
The added functions are:
- `rescueTokens`: Allows the contract owner to rescue tokens sent to the contract address accidentally.
- `rescueETH`: Allows the contract owner to rescue ETH sent to the contract address accidentally.

With these functions, you can now rescue tokens or ETH sent to the contract by mistake. Make sure to test these functions thoroughly before deploying the contract on the mainnet.
