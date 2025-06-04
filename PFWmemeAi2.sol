// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPlumeSwapRouter {
    function WETH() external pure returns (address);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
}

contract PFWMeme is ERC20, Ownable, Pausable {
    uint256 public constant MAX_SUPPLY = 12_000_000_000 * 10 ** 18;
    uint256 public transferFee = 1; // 0.01% (bps)
    uint256 public maxTxAmount = 100_000_000 * 10 ** 18; // max 100M tokens per tx (anti-whale)

    address public feeReceiver;
    address public router;

    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public isExcludedFromMaxTx;

    event FeeReceiverUpdated(address indexed oldReceiver, address indexed newReceiver);
    event TransferFeeUpdated(uint256 oldFee, uint256 newFee);
    event RouterUpdated(address indexed oldRouter, address indexed newRouter);
    event ExcludedFromFee(address indexed account, bool isExcluded);
    event ExcludedFromMaxTx(address indexed account, bool isExcluded);
    event MaxTxAmountUpdated(uint256 oldAmount, uint256 newAmount);

    constructor(address _feeReceiver, address _router) ERC20("Plume Feathers Wing", "PFWMeme") {
        require(_feeReceiver != address(0), "Fee receiver invalid");
        feeReceiver = _feeReceiver;
        router = _router;
        _mint(msg.sender, MAX_SUPPLY);

        // Owner & contract exclude from fees and max tx limits
        isExcludedFromFee[msg.sender] = true;
        isExcludedFromFee[address(this)] = true;
        isExcludedFromMaxTx[msg.sender] = true;
        isExcludedFromMaxTx[address(this)] = true;
    }

    // Override transfer with pause and fee logic
    function _transfer(address from, address to, uint256 amount) internal override whenNotPaused {
        require(amount <= maxTxAmount || isExcludedFromMaxTx[from] || isExcludedFromMaxTx[to], "Exceeds max tx amount");

        if (isExcludedFromFee[from] || isExcludedFromFee[to]) {
            super._transfer(from, to, amount);
            return;
        }

        uint256 fee = (amount * transferFee) / 10_000;
        uint256 remaining = amount - fee;

        if (fee > 0) {
            super._transfer(from, feeReceiver, fee);
        }
        super._transfer(from, to, remaining);
    }

    // Pause contract transfers (emergency)
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Update fee receiver
    function updateFeeReceiver(address newReceiver) external onlyOwner {
        require(newReceiver != address(0), "Invalid address");
        emit FeeReceiverUpdated(feeReceiver, newReceiver);
        feeReceiver = newReceiver;
    }

    // Update transfer fee (max 1%)
    function updateTransferFee(uint256 newFee) external onlyOwner {
        require(newFee <= 100, "Max fee 1%");
        emit TransferFeeUpdated(transferFee, newFee);
        transferFee = newFee;
    }

    // Update max tx amount
    function updateMaxTxAmount(uint256 newAmount) external onlyOwner {
        require(newAmount >= 1_000_000 * 10 ** 18, "Too low"); // minimal 1M tokens
        emit MaxTxAmountUpdated(maxTxAmount, newAmount);
        maxTxAmount = newAmount;
    }

    // Set router address
    function setRouter(address newRouter) external onlyOwner {
        require(newRouter != address(0), "Invalid router");
        emit RouterUpdated(router, newRouter);
        router = newRouter;
    }

    // Exclude/include wallet from fees
    function setExcludedFromFee(address account, bool excluded) external onlyOwner {
        isExcludedFromFee[account] = excluded;
        emit ExcludedFromFee(account, excluded);
    }

    // Exclude/include wallet from max tx limit
    function setExcludedFromMaxTx(address account, bool excluded) external onlyOwner {
        isExcludedFromMaxTx[account] = excluded;
        emit ExcludedFromMaxTx(account, excluded);
    }

    // Batch transfer tokens (gas optimized)
    function batchTransfer(address[] calldata recipients, uint256[] calldata amounts) external whenNotPaused {
        require(recipients.length == amounts.length, "Array length mismatch");
        for (uint i = 0; i < recipients.length; i++) {
            _transfer(msg.sender, recipients[i], amounts[i]);
        }
    }

    // Burn tokens from owner
    function burn(uint256 amount) external onlyOwner {
        _burn(msg.sender, amount);
    }

    // Mint additional tokens (max supply limit)
    function mint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
    }

    // Rescue native tokens (PLUME)
    function rescueNative() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    // Rescue stuck ERC20 tokens (except PFWMeme)
    function rescueToken(address tokenAddr) external onlyOwner {
        require(tokenAddr != address(this), "Cannot rescue PFWMeme");
        IERC20(tokenAddr).transfer(owner(), IERC20(tokenAddr).balanceOf(address(this)));
    }

    // Swap PFWMeme tokens for PLUME (native)
    function swapTokensForPlume(uint256 tokenAmount) external onlyOwner {
        require(router != address(0), "Router not set");
        address ;
        path[0] = address(this);
        path[1] = IPlumeSwapRouter(router).WETH();

        _approve(address(this), router, tokenAmount);

        IPlumeSwapRouter(router).swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            owner(),
            block.timestamp
        );
    }

    // Swap PLUME (native) for PFWMeme tokens
    function swapPlumeForTokens() external payable onlyOwner {
        require(router != address(0), "Router not set");
        require(msg.value > 0, "Must send PLUME");

        address ;
        path[0] = IPlumeSwapRouter(router).WETH();
        path[1] = address(this);

        IPlumeSwapRouter(router).swapExactETHForTokensSupportingFeeOnTransferTokens{value: msg.value}(
            0,
            path,
            owner(),
            block.timestamp
        );
    }

    receive() external payable {}
}
