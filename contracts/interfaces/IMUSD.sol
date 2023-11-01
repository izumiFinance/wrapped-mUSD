// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.19;
/**
 * @dev interfaces of MUSD
 */
interface IMUSD {
    function sharesOf(address _account) external view returns (uint256);

    /**
     * @dev get share amount from amount of mUSD
     */
    function getSharesByRUSDY(
        uint256 _rUSDYAmount
    ) external view returns (uint256);

    function decimals() external view returns (uint8);

    /**
     * @dev transfer `amount` of mUSD
     */
    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) external returns (bool);
    /**
     * @dev transfer shares of mUSD directly
     */
    function transferShares(
        address _recipient,
        uint256 _sharesAmount
    ) external returns (uint256);
}