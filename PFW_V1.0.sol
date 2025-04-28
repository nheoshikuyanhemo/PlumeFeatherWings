// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract PFW is ERC20, ERC20Burnable, Pausable, Ownable {
    // Router for MaverickV2Router
    address public constant MAVERICK_V2_ROUTER = 0x816FA4266396b4a99390106617eE7bA9104018Fe;

    // Total supply
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10 ** 18;

    // Transaction limit
    uint256 private constant TRANSACTION_LIMIT = 100_000_000 * 10 ** 18;

    // Mapping for sniper list
    mapping(address => bool) private sniperList;

    // Fee (private)
    uint256 private constant TAX_FEE = 10; // 0.1%
    uint256 private constant FEE_DENOMINATOR = 10000;
    uint256 private constant SNIPER_FEE = 50; // 50%

    // Wallets for fee distribution (private)
    address private constant FEE_WALLET_OWNER = 0xb50b87cca4fd3cc57bf253507abf09cede3072a1;
    address private constant FEE_WALLET_MARKETING = 0x4097c93769d76eb70a37982fd23ab0f0eed820d5;

    // PLUME token address (update this with the correct address)
    address private constant PLUME_TOKEN_ADDRESS = 0x...; // PLUME token address

    constructor() ERC20("Plume Feather Wings", "PFW") {
        _mint(msg.sender, TOTAL_SUPPLY);
    }

    // Override transfer function to implement tax and sniper logic
    function _transfer(address from, address to, uint256 amount) internal override {
        // Check if transaction is buy or sell
        bool isBuy = from == MAVERICK_V2_ROUTER;
        bool isSell = to == MAVERICK_V2_ROUTER;

        // Check if transaction exceeds limit
        require(amount <= TRANSACTION_LIMIT, "Transaction exceeds limit");

        // Calculate tax fee
        uint256 feeAmount = amount * TAX_FEE / FEE_DENOMINATOR;

        // Check if transaction is a sniper
        if (sniperList[msg.sender] && isBuy) {
            feeAmount = amount * SNIPER_FEE / 100;
        }

        // Transfer token to the recipient minus the fee
        super._transfer(from, to, amount - feeAmount);

        // Distribute the fee to the fee wallets
        super._transfer(from, FEE_WALLET_OWNER, feeAmount / 2);
        super._transfer(from, FEE_WALLET_MARKETING, feeAmount / 2);
    }

    // Swap tokens for PLUME token
    function swapTokensForPlume(uint256 tokenAmount) public whenNotPaused {
        // Ensure the caller has enough tokens to swap
        require(balanceOf(msg.sender) >= tokenAmount, "Insufficient token balance");

        // Approve the router to spend tokens
        _approve(msg.sender, MAVERICK_V2_ROUTER, tokenAmount);

        // Perform token swap via Uniswap
        IUniswapV2Router02(MAVERICK_V2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            getPathForPlume(),
            msg.sender,
            block.timestamp
        );
    }

    // Define the token swap path from PFW to PLUME token
    function getPathForPlume() public view returns (address[] memory) {
        address ;
        path[0] = address(this);
        path[1] = PLUME_TOKEN_ADDRESS; // PLUME token address
        return path;
    }

    // Add an address to the sniper list (onlyOwner)
    function addSniper(address sniper) public onlyOwner {
        sniperList[sniper] = true;
    }

    // Remove an address from the sniper list (onlyOwner)
    function removeSniper(address sniper) public onlyOwner {
        sniperList[sniper] = false;
    }

    // Pause the contract in case of emergency
    function pause() public onlyOwner {
        _pause();
    }

    // Unpause the contract after the emergency is resolved
    function unpause() public onlyOwner {
        _unpause();
    }
}
