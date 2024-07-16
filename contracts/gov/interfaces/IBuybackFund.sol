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

interface IBuybackFund {
    function paths(address, uint256) external view returns (address);
    function changeNextOwner(address _nextOwner) external;
    function universalRouter() external view returns (address);
    function totalDailyBurnt(uint256) external view returns (uint256);
    function setToken(
        address token,
        bool valid,
        address[] calldata path,
        address[] calldata pool
    ) external;
    function getTotalBurnt(
        uint256 epoch
    ) external view returns (uint256 daily, uint256 weekly);
    function estimateBuybackMining(
        address pool,
        uint256 epoch,
        uint256 rate
    ) external view returns (uint256);
    function getBuybackMining(
        address pool,
        uint256 epoch,
        uint256 rate
    ) external view returns (uint256);
    function getBuybackPath(
        address token
    ) external view returns (address[] memory path, address[] memory pool);
    function vRewardToken() external view returns (address);
    function setValidOperator(address operator, bool valid) external;
    function version() external pure returns (string memory);
    function governance() external view returns (address);
    function getPools(address token) external view returns (address[] memory);
    function implementation() external view returns (address);
    function changeOwner() external;
    function nextOwner() external view returns (address);
    function getPoolBurnt(
        address pool,
        uint256 epoch
    ) external view returns (uint256 daily, uint256 weekly);
    function validOperator(address) external view returns (bool);
    function emergencyWithdraw(address token) external;
    function _setImplementation(address _newImp, string calldata _version) external;
    function forceUpdateBoostingBurnt(address[] calldata pools) external;
    function epochBurnt(uint256) external view returns (bool);
    function owner() external view returns (address);
    function pathPools(address, uint256) external view returns (address);
    function updateFund0(uint256 amount) external;
    function fund1(address) external view returns (uint256);
    function buybackRange(uint256 si, uint256 ei) external;
    function entered() external view returns (bool);
    function WETH() external view returns (address);
    function weeklyBurnt(address, uint256) external view returns (uint256);
    function factory() external view returns (address);
    function fund0(address) external view returns (uint256);
    function validToken(address) external view returns (bool);
    function buybackPools(address[] calldata pools) external;
    function epochBurn() external;
    function dailyBurnt(address, uint256) external view returns (uint256);
    function rewardToken() external view returns (address);
    function router() external view returns (address);
    function totalWeeklyBurnt(uint256) external view returns (uint256);
    function updateFund1(uint256 amount) external;
    function buyback(address pool) external;
}
