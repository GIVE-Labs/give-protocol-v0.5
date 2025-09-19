// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IYieldAdapter
 * @dev Interface for yield adapters that invest vault assets into external protocols
 * @notice All adapters must implement this interface to be compatible with GiveVault4626
 */
interface IYieldAdapter {
    /**
     * @dev Returns the underlying asset that this adapter accepts
     * @return The ERC20 token address
     */
    function asset() external view returns (IERC20);

    /**
     * @dev Returns the total assets under management by this adapter
     * @return The total amount of underlying assets
     */
    function totalAssets() external view returns (uint256);

    /**
     * @dev Invests the specified amount of assets into the yield protocol
     * @param assets The amount of assets to invest
     * @notice Only callable by the vault
     */
    function invest(uint256 assets) external;

    /**
     * @dev Divests the specified amount of assets from the yield protocol
     * @param assets The amount of assets to divest
     * @return returned The actual amount of assets returned (may be less due to slippage)
     * @notice Only callable by the vault
     */
    function divest(uint256 assets) external returns (uint256 returned);

    /**
     * @dev Harvests yield and realizes profit/loss
     * @return profit The amount of profit realized
     * @return loss The amount of loss realized
     * @notice Only callable by the vault
     */
    function harvest() external returns (uint256 profit, uint256 loss);

    /**
     * @dev Emergency function to withdraw all assets from the protocol
     * @return returned The amount of assets returned
     * @notice Only callable by authorized emergency roles
     */
    function emergencyWithdraw() external returns (uint256 returned);

    /**
     * @dev Returns the vault address that owns this adapter
     * @return The vault contract address
     */
    function vault() external view returns (address);

    /**
     * @dev Emitted when assets are invested into the yield protocol
     * @param assets The amount of assets invested
     */
    event Invested(uint256 assets);

    /**
     * @dev Emitted when assets are divested from the yield protocol
     * @param requested The amount of assets requested
     * @param returned The actual amount of assets returned
     */
    event Divested(uint256 requested, uint256 returned);

    /**
     * @dev Emitted when yield is harvested
     * @param profit The amount of profit realized
     * @param loss The amount of loss realized
     */
    event Harvested(uint256 profit, uint256 loss);

    /**
     * @dev Emitted during emergency withdrawal
     * @param returned The amount of assets returned
     */
    event EmergencyWithdraw(uint256 returned);
}
