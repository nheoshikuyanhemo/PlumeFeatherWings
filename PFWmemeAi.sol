// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPlumeSwapRouter {
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

contract PFWMeme is ERC20, Ownable {
    uint256 public constant MAX_SUPPLY = 12_000_000_000 * 10 ** 18;
    uint256 public transferFee = 1; // 0.01% in basis points (1/10000)
    address public feeReceiver;

    address public router;
    mapping(address => bool) public isExcludedFromFee;

    constructor(address _feeReceiver, address _router) ERC20("Plume Feathers Wing", "PFWMeme") {
        require(_feeReceiver != address(0), "Fee receiver cannot be zero address");
        feeReceiver = _feeReceiver;
        router = _router;
        _mint(msg.sender, MAX_SUPPLY);
    }

    function _transfer(address from, address to, uint256 amount) internal override {
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

    function updateFeeReceiver(address _newReceiver) external onlyOwner {
        require(_newReceiver != address(0), "Invalid address");
        feeReceiver = _newReceiver;
    }

    function updateTransferFee(uint256 newFee) external onlyOwner {
        require(newFee <= 100, "Max fee is 1%");
        transferFee = newFee;
    }

    function setRouter(address newRouter) external onlyOwner {
        require(newRouter != address(0), "Invalid router");
        router = newRouter;
    }

    function setExcludedFromFee(address wallet, bool excluded) external onlyOwner {
        isExcludedFromFee[wallet] = excluded;
    }

    function rescueNative() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function rescueToken(address tokenAddr) external onlyOwner {
        require(tokenAddr != address(this), "Cannot rescue PFWMeme token");
        IERC20(tokenAddr).transfer(owner(), IERC20(tokenAddr).balanceOf(address(this)));
    }

    // 🔄 Swap PFWMeme to PLUME
    function swapTokensForPlume(uint256 tokenAmount) external onlyOwner {
        require(router != address(0), "Router not set");

        address ;
        path[0] = address(this);
        path[1] = IPlumeSwapRouter(router).WETH(); // Assume PLUME is "WETH" alias on Plume

        _approve(address(this), router, tokenAmount);

        IPlumeSwapRouter(router).swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount
            path,
            owner(),
            block.timestamp
        );
    }

    // 🔄 Swap PLUME to PFWMeme
    function swapPlumeForTokens() external payable onlyOwner {
        require(router != address(0), "Router not set");
        require(msg.value > 0, "Send PLUME to swap");

        address ;
        path[0] = IPlumeSwapRouter(router).WETH();
        path[1] = address(this);

        IPlumeSwapRouter(router).swapExactETHForTokensSupportingFeeOnTransferTokens{value: msg.value}(
            0, // accept any amount
            path,
            owner(),
            block.timestamp
        );
    }

    receive() external payable {}
}
