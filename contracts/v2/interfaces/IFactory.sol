// SPDX-License-Identifier: MPL-2.0

// Copyright OZYS Co., Ltd
// OZYS Co., Ltd strives to create a friendly environment where more people can experience the positive functions of blockchain, such as decentralization, non-discrimination, and transparency. As part of the efforts of Web3 mass adoption OZYS Co., Ltd is releasing the source code as shown below. OZYS Co., Ltd hopes that releasing the source code will serve as an opportunity for various projects at home and abroad to participate in, grow, and contribute towards the Web 3 ecosystem.

// Licensed under the Mozilla Public License, Version 2.0 (the "License");
// You may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    https://www.mozilla.org/en-US/MPL/2.0

// Unless required by applicable law or agreed to in writing, software distributed under the license is distributed on an 'AS IS' basis, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

// Respectfully, If you distribute the software in executable format, please email us as a courtesy( support@ozys.io ).
pragma solidity 0.5.6;

interface IFactory {
    function getPoolAddress(uint256 idx) external view returns (address);
    function allPairs(uint256 idx) external view returns (address pair);
    function createETHPool(
        address token,
        uint256 amount,
        uint256 fee
    ) external payable;
    function version() external pure returns (string memory);
    function allPairsLength() external view returns (uint256);
    function getExchangeImplementation() external view returns (address);
    function implementation() external view returns (address);
    function changeNextOwner(address _nextOwner) external;
    function changeOwner() external;
    function nextOwner() external view returns (address);
    function _setExchangeImplementation(address _newExImp) external;
    function poolExist(address) external view returns (bool);
    function owner() external view returns (address);
    function getPoolCount() external view returns (uint256);
    function chainId() external view returns (uint256);
    function entered() external view returns (bool);
    function pools(uint256) external view returns (address);
    function WETH() external view returns (address);
    function createTokenPool(
        address token0,
        uint256 amount0,
        address token1,
        uint256 amount1,
        uint256 fee
    ) external;
    function createFee() external view returns (uint256);
    function _setImplementation(address _newImp) external;
    function setRouter(address _router) external;
    function exchangeImplementation() external view returns (address);
    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);
    function changeCreateFee(uint256 _createFee) external;
    function changePoolFee(
        address token0,
        address token1,
        uint256 fee
    ) external;
    function rewardToken() external view returns (address);
    function router() external view returns (address);
    function tokenToPool(address, address) external view returns (address);
}
