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

interface ITreasury {
    function createTokenDistribution(
        address token,
        uint256 amount,
        uint256 blockAmount,
        uint256 blockNumber,
        address[] calldata targets,
        uint256[] calldata rates
    ) external;
    function claim(address target) external;
    function updateDistributionIndex(address target) external;
    function claim(address user, address target) external;
    function setValidOperatorList(address[] calldata operators) external;
    function refixDistributionRate(
        address token,
        address[] calldata targets,
        uint256[] calldata rates
    ) external;
    function distributionOperator(address) external view returns (address);
    function depositToken(address token, uint256 amount) external;
    function distributions(address, address) external view returns (address);
    function removeDistribution(address operator, address token) external;
    function version() external pure returns (string memory);
    function setOperator(address _operator, bool _valid) external;
    function policyAdmin() external view returns (address);
    function implementation() external view returns (address);
    function changeNextOwner(address _nextOwner) external;
    function changeOwner() external;
    function nextOwner() external view returns (address);
    function _setDistributionImplementation(
        address _newDistributionImp
    ) external;
    function validOperator(address) external view returns (bool);
    function getDistributionImplementation() external view returns (address);
    function owner() external view returns (address);
    function distributionCount(address) external view returns (uint256);
    function distributionImplementation() external view returns (address);
    function changeCreationFee(uint256 _fee) external;
    function entered() external view returns (bool);
    function setPolicyAdmin(address _policyAdmin) external;
    function _setImplementation(address _newImp) external;
    function distributionEntries(
        address,
        uint256
    ) external view returns (address);
    function fee() external view returns (uint256);
    function rewardToken() external view returns (address);
    function refixBlockAmount(address token, uint256 blockAmount) external;
}
