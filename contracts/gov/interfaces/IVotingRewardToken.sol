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

interface IVotingRewardToken {
    function name() external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function changePaused(bool _paused) external;
    function getCurrentBalance(address user) external view returns (uint256);
    function unlockRewardTokenUnlimited() external;
    function version() external pure returns (string memory);
    function policyAdmin() external view returns (address);
    function governance() external view returns (address);
    function userRewardSum(address) external view returns (uint256);
    function implementation() external view returns (address);
    function paused() external view returns (bool);
    function mining() external view returns (uint256);
    function compoundReward() external;
    function balanceOf(address) external view returns (uint256);
    function getPriorBalance(
        address user,
        uint256 blockNumber
    ) external view returns (uint256);
    function unlockTime(address) external view returns (uint256);
    function lockPeriod(address) external view returns (uint256);
    function miningIndex() external view returns (uint256);
    function getUserUnlockTime(address user) external view returns (uint256);
    function symbol() external view returns (string memory);
    function unlockRewardToken() external;
    function refixBoosting(uint256 lockPeriodRequested) external;
    function entered() external view returns (bool);
    function setPolicyAdmin(address _policyAdmin) external;
    function lockRewardToken(uint256 amount, uint256 lockPeriodRequested) external;
    function lastMined() external view returns (uint256);
    function claimReward() external;
    function _setImplementation(address _newImp) external;
    function updateMiningIndex() external returns (uint256);
    function snapShotBalance(address, uint256) external view returns (uint256);
    function getPriorSupply(
        uint256 blockNumber
    ) external view returns (uint256);
    function userLastIndex(address) external view returns (uint256);
    function snapShotBlock(address, uint256) external view returns (uint256);
    function lockedRewardToken(address) external view returns (uint256);
    function snapShotCount(address) external view returns (uint256);
    function updateBuybackIndex(uint256 amount) external;
}
