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

import "./libraries/SafeMath.sol";
import "./gov/interfaces/IGovernance.sol";
import "./v2/interfaces/IRewardToken.sol";

/// @title Contract that only just receives reward tokens
contract RewardTreasury {
    using SafeMath for uint256;

    address public owner;
    address public nextOwner;
    address public governance;
    uint256 public mining;
    uint256 public lastMined;
    uint256 public claimedAmount;

    constructor(address _governance) public {
        owner = msg.sender;
        governance = _governance;
    }

    event ChangeNextOwner(address nextOwner);
    event ChangeOwner(address owner);
    event SetEpochMining(uint256 mining, uint256 lastMined, uint256 amount);
    event Claim(uint256 amount, uint256 claimedAmount);

    function changeNextOwner(address _nextOwner) public {
        require(msg.sender == owner);
        nextOwner = _nextOwner;

        emit ChangeNextOwner(_nextOwner);
    }

    function changeOwner() public {
        require(msg.sender == nextOwner);
        owner = nextOwner;
        nextOwner = address(0);

        emit ChangeOwner(owner);
    }

    function setEpochMining() private returns (uint256 amount) {
        (uint256 curEpoch, uint256 prevEpoch, uint256[] memory rates, uint256[] memory mined)
            = IGovernance(governance).getEpochMining(address(2));
        if (curEpoch == prevEpoch) return 0;

        uint256 epoch = curEpoch.sub(prevEpoch);
        require(rates.length == epoch);
        require(rates.length == mined.length);

        uint256 thisMined;
        for(uint256 i = 0; i < epoch; i++){
            thisMined = mining.mul(mined[i].sub(lastMined)).div(10000);

            require(rates[i] <= 10000);
            mining = rates[i];
            lastMined = mined[i];

            amount = amount.add(thisMined);
            emit SetEpochMining(mining, lastMined, amount);
        }

        IGovernance(governance).acceptEpoch();

    }

    function getMiningIndex() private view returns (uint256 thisMined) {
        uint256 mined = IRewardToken(IGovernance(governance).rewardToken()).newMined();

        if (mined > lastMined) {
            thisMined = mining.mul(mined - lastMined).div(10000);
        }
    }

    function giveReward() private {
        uint256 amount = setEpochMining();

        amount = amount.add(getMiningIndex());
        IGovernance(governance).sendReward(owner, amount);

        claimedAmount = claimedAmount.add(amount);

        emit Claim(amount, claimedAmount);
    }

    function claim() external {
        giveReward();
    }

    function getClaimedAmount() external view returns (uint256) {
        return claimedAmount;
    }
}
