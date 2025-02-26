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

interface IRewardToken {
    function mined() external view returns (uint256 res);
    function newMined() external view returns (uint256 res);
    function name() external view returns (string memory);
    function sendReward(address user, uint256 amount) external;
    function approve(address _spender, uint256 _value) external returns (bool);
    function totalSupply() external view returns (uint256);
    function claimTeamAward() external;
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool);
    function minableTime() external view returns (uint256);
    function decimals() external view returns (uint8);
    function burn(uint256 amount) external;
    function teamWallet() external view returns (address);
    function changeNextOwner(address _nextOwner) external;
    function changeOwner() external;
    function nextOwner() external view returns (address);
    function balanceOf(address) external view returns (uint256);
    function rewarded() external view returns (uint256);
    function blockAmount() external view returns (uint256);
    function halfLife() external view returns (uint256);
    function miningAmount() external view returns (uint256);
    function setMinableBlock() external;
    function owner() external view returns (address);
    function teamAward() external view returns (uint256);
    function symbol() external view returns (string memory);
    function teamRatio() external view returns (uint256);
    function entered() external view returns (bool);
    function transfer(address _to, uint256 _value) external returns (bool);
    function changeTeamWallet(address _teamWallet) external;
    function getCirculation()
        external
        view
        returns (uint256 blockNumber, uint256 nowCirculation);
    function allowance(address, address) external view returns (uint256);
    function refixMining(uint256 newBlockAmount, uint256 newHalfLife) external;
    function minableBlock() external view returns (uint256);
}
