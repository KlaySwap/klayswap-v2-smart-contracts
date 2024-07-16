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

import "./Distribution.sol";
import "../libraries/SafeMath.sol";
import "../misc/IERC20.sol";

contract DistributionImpl is Distribution {
    using SafeMath for uint256;

    event Initialized(
        address token,
        uint256 amountPerBlock,
        uint256 distributableBlock,
        address[] targets,
        uint256[] rates
    );
    event Deposit(uint256 amount, uint256 totalAmount);
    event RefixBlockAmount(uint256 amountPerBlock);
    event RefixDistributionRate(address[] targets, uint256[] rates);

    event ChangeDistributionRate(address target, uint256 rate);
    event UpdateDistributionIndex(
        address target,
        uint256 distributed,
        uint256 distributionIndex
    );
    event Distribute(
        address user,
        address target,
        uint256 amount,
        uint256 currentIndex,
        uint256 userRewardSum
    );

    constructor() public Distribution(address(0)) {}

    modifier onlyTreasury() {
        require(msg.sender == treasury);
        _;
    }

    modifier nonReentrant() {
        require(!entered, "ReentrancyGuard: reentrant call");

        entered = true;

        _;

        entered = false;
    }

    function version() public pure returns (string memory) {
        return "DistributionImpl20240528";
    }

    function estimateEndBlock() public view returns (uint256) {
        return
            distributableBlock.add(
                totalAmount.sub(distributedAmount).ceilDiv(blockAmount)
            );
    }

    function init(
        address _token,
        uint256 _blockAmount,
        uint256 _blockNumber,
        address[] memory _targets,
        uint256[] memory _rates
    ) public onlyTreasury {
        require(!isInitialized);
        isInitialized = true;

        require(_blockAmount != 0);
        require(_blockNumber > block.number);
        require(_targets.length <= 10);
        require(_targets.length == _rates.length);

        token = _token;
        blockAmount = _blockAmount;
        distributableBlock = _blockNumber;
        distributedAmount = 0;

        changeDistributionRate(_targets, _rates);

        emit Initialized(_token, _blockAmount, _blockNumber, _targets, _rates);
    }

    function depositToken(uint256 amount) public onlyTreasury {
        require(IERC20(token).transferFrom(treasury, address(this), amount));

        deposit(amount);
    }

    function deposit(uint256 amount) private {
        require(amount != 0);

        if (totalAmount != 0) {
            distributedAmount = distribution();
            distributableBlock = block.number;
        }
        totalAmount = totalAmount.add(amount);

        emit Deposit(amount, totalAmount);
    }

    function refixBlockAmount(uint256 _blockAmount) public onlyTreasury {
        require(_blockAmount != 0);

        for (uint256 i = 0; i < targetCount; i++) {
            updateDistributionIndex(targetEntries[i]);
        }

        distributedAmount = distribution();
        blockAmount = _blockAmount;
        distributableBlock = block.number;

        emit RefixBlockAmount(blockAmount);
    }

    function refixDistributionRate(
        address[] memory targets,
        uint256[] memory rates
    ) public onlyTreasury {
        require(totalAmount > distribution());

        changeDistributionRate(targets, rates);

        emit RefixDistributionRate(targets, rates);
    }

    function changeDistributionRate(
        address[] memory targets,
        uint256[] memory rate
    ) private {
        uint256 n = targets.length;

        require(n <= 20);
        require(rate.length == n);

        uint256 i;
        uint256 j;
        uint256 rateSum = 0;
        for (i = 0; i < n; i++) {
            require(rate[i] != 0);
            rateSum = rateSum.add(rate[i]);

            for (j = 0; j < i; j++) {
                require(targets[j] != targets[i]);
            }
        }
        require(rateSum == 100);

        uint256 cnt = 0;
        address[] memory removeTargets = new address[](targetCount);
        for (i = 0; i < targetCount; i++) {
            address target = targetEntries[i];
            bool exist = false;

            for (j = 0; j < n; j++) {
                if (targets[j] == target) {
                    exist = true;
                    break;
                }
            }

            if (!exist) {
                removeTargets[cnt] = target;
                cnt = cnt + 1;
            }
        }

        for (i = 0; i < cnt; i++) {
            setDistributionRate(removeTargets[i], 0);
        }

        for (i = 0; i < n; i++) {
            if (distributionRate[targets[i]] != rate[i]) {
                setDistributionRate(targets[i], rate[i]);
            }
        }
    }

    function removeDistribution() public onlyTreasury {
        require(estimateEndBlock().add(7 days) < block.number);

        uint256 balance = 0;
        balance = IERC20(token).balanceOf(address(this));
        require(IERC20(token).transfer(operator, balance));
    }

    // ================================= Distribution =======================================

    function distribution() public view returns (uint256) {
        if (distributableBlock == 0 || distributableBlock > block.number)
            return distributedAmount;

        uint256 amount = distributedAmount.add(
            block.number.sub(distributableBlock).mul(blockAmount)
        );

        return amount > totalAmount ? totalAmount : amount;
    }

    function setDistributionRate(address target, uint256 rate) private {
        require(rate <= 100);

        if (distributionRate[target] == 0 && rate != 0) {
            require(targetCount < 20);

            targetEntries[targetCount] = target;
            targetCount = targetCount + 1;
        }

        if (rate == 0) {
            bool targetExist = false;
            uint256 targetIndex;

            for (uint256 i = 0; i < targetCount; i++) {
                if (targetEntries[i] == target) {
                    targetExist = true;
                    targetIndex = i;
                    break;
                }
            }
            require(targetExist);

            targetEntries[targetIndex] = targetEntries[targetCount - 1];
            targetEntries[targetCount - 1] = address(0);
            targetCount = targetCount - 1;
        }

        updateDistributionIndex(target);
        distributionRate[target] = rate;

        emit ChangeDistributionRate(target, rate);
    }

    function getDistributionIndex(
        address target
    ) private view returns (uint256) {
        uint256 distributed = distribution();

        if (distributed > lastDistributed[target]) {
            uint256 thisDistributed = distributionRate[target]
                .mul(distributed.sub(lastDistributed[target]))
                .div(100);
            uint256 totalSupply = IERC20(target).totalSupply();
            if (thisDistributed != 0 && totalSupply != 0) {
                return
                    distributionIndex[target].add(
                        thisDistributed.mul(1e18).div(totalSupply)
                    );
            }
        }

        return distributionIndex[target];
    }

    function updateDistributionIndex(address target) public {
        uint256 distributed = distribution();

        if (distributed > lastDistributed[target]) {
            uint256 thisDistributed = distributionRate[target].mul(
                distributed.sub(lastDistributed[target]).div(100)
            );
            uint256 totalSupply = IERC20(target).totalSupply();

            lastDistributed[target] = distributed;
            if (thisDistributed != 0 && totalSupply != 0) {
                distributionIndex[target] = distributionIndex[target].add(
                    thisDistributed.mul(1e18).div(totalSupply)
                );
            }

            emit UpdateDistributionIndex(
                target,
                distributed,
                distributionIndex[target]
            );
        }
    }

    function distribute(
        address user,
        address target
    ) public onlyTreasury nonReentrant {
        uint256 lastIndex = userLastIndex[target][user];
        uint256 currentIndex = getDistributionIndex(target);

        uint256 have = IERC20(target).balanceOf(user);

        if (currentIndex > lastIndex) {
            userLastIndex[target][user] = currentIndex;

            if (have != 0) {
                uint256 amount = have.mul(currentIndex.sub(lastIndex)).div(1e18);

                require(IERC20(token).transfer(user, amount));

                userRewardSum[target][user] = userRewardSum[target][user].add(
                    amount
                );
                emit Distribute(
                    user,
                    target,
                    amount,
                    currentIndex,
                    userRewardSum[target][user]
                );
            }
        }
    }

    function() external payable {
        revert();
    }
}
