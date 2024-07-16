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

interface IGovernance {
    function miningShareRate() external view returns (uint256);
    function sendReward(address user, uint256 amount) external;
    function rateNumerator() external view returns (uint256);
    function governor() external view returns (address);
    function vRewardToken() external view returns (address);
    function setExecutor(address _executor) external;
    function nextTime() external view returns (uint256);
    function implAdmin() external view returns (address);
    function isInitialized() external view returns (bool);
    function _setVotingRewardTokenImplementation(address _newImp) external;
    function epochRates(uint256, address) external view returns (uint256);
    function singlePoolFactory() external view returns (address);
    function version() external pure returns (string memory);
    function implementation() external view returns (address);
    function changeNextOwner(address _nextOwner) external;
    function treasury() external view returns (address);
    function changeOwner() external;
    function nextOwner() external view returns (address);
    function singlePoolMiningRate() external view returns (uint256);
    function getEpochMining(
        address pool
    )
        external
        view
        returns (
            uint256 curEpoch,
            uint256 prevEpoch,
            uint256[] memory rates,
            uint256[] memory mined
        );
    function _setExchangeImplementation(address _newImp) external;
    function lastEpoch(address) external view returns (uint256);
    function setImplAdmin(address _implAdmin) external;
    function changeMiningRates(
        uint256 singlePoolRate,
        uint256 pairPoolRate,
        uint256 vRewardTokenRate
    ) external;
    function owner() external view returns (address);
    function setMiningShareRate(uint256 rate) external;
    function epoch() external view returns (uint256);
    function interval() external view returns (uint256);
    function setTeamAdmin(address _teamAdmin) external;
    function setMiningRate() external;
    function acceptEpoch() external;
    function entered() external view returns (bool);
    function transactionValue(uint256) external view returns (uint256);
    function getBoostingMining(
        address pool
    )
        external
        view
        returns (
            uint256 curEpoch,
            uint256 prevEpoch,
            uint256[] memory mined,
            uint256[] memory rates
        );
    function changeTeamWallet(address _teamWallet) external;
    function setVotingRewardTokenMiningRate(uint256 rate) external;
    function transactionData(uint256) external view returns (bytes memory);
    function prevTime() external view returns (uint256);
    function teamAdmin() external view returns (address);
    function transactionCount() external view returns (uint256);
    function _setImplementation(address _newImp) external;
    function transactionExecuted(uint256) external view returns (bool);
    function executor() external view returns (address);
    function factory() external view returns (address);
    function v3Factory() external view returns (address);
    function epochMined(uint256) external view returns (uint256);
    function _setFactoryImplementation(address _newImp) external;
    function transactionDestination(uint256) external view returns (address);
    function buybackRate() external view returns (uint256);
    function treasuryMiningRate() external view returns (uint256);
    function addTransaction(
        address destination,
        uint256 value,
        bytes calldata data
    ) external;
    function executeTransaction(uint256 tid) external;
    function setSinglePoolMiningRate(uint256 rate) external;
    function rewardToken() external view returns (address);
    function vRewardTokenMiningRate() external view returns (uint256);
    function changePoolFee(address pool, uint256 fee) external;
    function setTimeParams(uint256 _interval, uint256 _nextTime) external;
    function buyback() external view returns (address);
    function router() external view returns (address);
    function setFeeShareRate(uint256 rate) external;
}
