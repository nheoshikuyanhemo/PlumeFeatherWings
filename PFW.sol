// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PFWToken is ERC20, ERC20Burnable, Ownable {
    using SafeERC20 for IERC20;

    // State Variables
    mapping(address => bool) private _isExcludedFromFee;
    uint256 public constant TOTAL_SUPPLY = 1500000000 * 10**18; // 1.5 billion tokens with 18 decimals
    uint256 private buyTaxFee = 10; // 0.1% buy tax fee (out of 10000)
    uint256 private sellTaxFee = 10; // 0.1% sell tax fee (out of 10000)
    uint256 private liquidityTaxFee = 10; // 0.1% liquidity tax fee (out of 10000)
    uint256 private denominator = 10000; // denominator for tax calculations
    address private taxWallet;
    address public uniswapV2Pair;
    address public routerSwapAddress = 0x816FA4266396b4a99390106617eE7bA9104018Fe;

    // Events
    event TaxWalletUpdated(address indexed newTaxWallet);
    event TaxFeesUpdated(uint256 buyTax, uint256 sellTax, uint256 liquidityTax);
    event UniswapPairUpdated(address indexed newUniswapV2Pair);
    event RouterSwapAddressUpdated(address indexed newRouterSwapAddress);

    constructor(address _taxWallet) ERC20("Plume Feather Wings", "PFW") {
        require(_taxWallet != address(0), "Tax wallet cannot be zero address");
        taxWallet = _taxWallet;
        _mint(msg.sender, TOTAL_SUPPLY);
        
        // Exclude owner and contract address from tax
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
    }

    // Internal transfer function with tax calculation
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        uint256 taxAmount = 0;
        
        if (!_isExcludedFromFee[sender] && !_isExcludedFromFee[recipient]) {
            // Check if it's a buy, sell, or liquidity transfer
            if (uniswapV2Pair != address(0)) {
                if (sender == uniswapV2Pair) {
                    // Buy tax
                    taxAmount = (amount * buyTaxFee) / denominator;
                } else if (recipient == uniswapV2Pair) {
                    // Sell tax
                    taxAmount = (amount * sellTaxFee) / denominator;
                } else {
                    // Liquidity tax for transfers between wallets
                    taxAmount = (amount * liquidityTaxFee) / denominator;
                }
            } else {
                // Default to liquidity tax if uniswap pair is not set
                taxAmount = (amount * liquidityTaxFee) / denominator;
            }
        }

        // Transfer the tax amount to the tax wallet and the rest to recipient
        uint256 sendAmount = amount - taxAmount;
        if (taxAmount > 0) {
            super._transfer(sender, taxWallet, taxAmount);
        }
        super._transfer(sender, recipient, sendAmount);
    }

    // Only owner can update tax wallet
    function setTaxWallet(address _newTaxWallet) external onlyOwner {
        require(_newTaxWallet != address(0), "Tax wallet cannot be zero address");
        taxWallet = _newTaxWallet;
        emit TaxWalletUpdated(_newTaxWallet);
    }

    // Only owner can update tax fees
    function updateTaxFees(uint256 _buyTaxFee, uint256 _sellTaxFee, uint256 _liquidityTaxFee) external onlyOwner {
        buyTaxFee = _buyTaxFee;
        sellTaxFee = _sellTaxFee;
        liquidityTaxFee = _liquidityTaxFee;
        emit TaxFeesUpdated(_buyTaxFee, _sellTaxFee, _liquidityTaxFee);
    }

    // Set Uniswap V2 Pair address
    function setUniswapV2Pair(address _uniswapV2Pair) external onlyOwner {
        uniswapV2Pair = _uniswapV2Pair;
        emit UniswapPairUpdated(_uniswapV2Pair);
    }

    // Set Router Swap Address
    function setRouterSwapAddress(address _newRouterSwapAddress) external onlyOwner {
        require(_newRouterSwapAddress != address(0), "Router swap address cannot be zero address");
        routerSwapAddress = _newRouterSwapAddress;
        emit RouterSwapAddressUpdated(_newRouterSwapAddress);
    }

    // Coin rescue function for external tokens
    function rescueTokens(address tokenAddress, uint256 amount) external onlyOwner {
        require(tokenAddress != address(this), "Cannot rescue native token");
        IERC20(tokenAddress).safeTransfer(owner(), amount);
    }

    // Rescue ETH from contract
    function rescueETH() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
