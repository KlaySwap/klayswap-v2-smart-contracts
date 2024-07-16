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

interface IDistribution {
    function targetEntries(uint256) external view returns (address);
    function distributedAmount() external view returns (uint256);
    function userLastIndex(address, address) external view returns (uint256);
    function estimateEndBlock() external view returns (uint256);
    function totalAmount() external view returns (uint256);
    function distributionIndex(address) external view returns (uint256);
    function updateDistributionIndex(address target) external;
    function init(
        address _token,
        uint256 _blockAmount,
        uint256 _blockNumber,
        address[] calldata _targets,
        uint256[] calldata _rates
    ) external;
    function isInitialized() external view returns (bool);
    function version() external pure returns (string memory);
    function operator() external view returns (address);
    function distributionRate(address) external view returns (uint256);
    function distribution() external view returns (uint256);
    function treasury() external view returns (address);
    function depositToken(uint256 amount) external;
    function blockAmount() external view returns (uint256);
    function refixDistributionRate(
        address[] calldata targets,
        uint256[] calldata rates
    ) external;
    function userRewardSum(address, address) external view returns (uint256);
    function removeDistribution() external;
    function distributableBlock() external view returns (uint256);
    function distribute(address user, address target) external;
    function entered() external view returns (bool);
    function targetCount() external view returns (uint256);
    function refixBlockAmount(uint256 _blockAmount) external;
    function lastDistributed(address) external view returns (uint256);
    function token() external view returns (address);
}
