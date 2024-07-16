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

import "../libraries/Address.sol";
import "../libraries/SafeMath.sol";
import "../misc/IERC20.sol";
import "./interfaces/IGovernance.sol";
import "../v2/interfaces/IRewardToken.sol";

contract VotingRewardTokenImpl {
    using SafeMath for uint256;

    // ======== ERC20 =========
    event Transfer(address indexed from, address indexed to, uint256 amount);

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply = 0;
    mapping(address => uint256) public balanceOf;

    address public governance;
    address public buyback;
    address public policyAdmin;

    // ========= Staking =============
    mapping(address => uint256) public lockedRewardToken;
    mapping(address => uint256) public unlockTime;
    mapping(address => uint256) public lockPeriod;

    mapping(address => uint256) public snapShotCount;
    mapping(address => mapping(uint256 => uint256)) public snapShotBlock;
    mapping(address => mapping(uint256 => uint256)) public snapShotBalance;

    // ========== Mining ==============
    uint256 public mining;
    uint256 public lastMined;
    uint256 public miningIndex;
    mapping(address => uint256) public userLastIndex;
    mapping(address => uint256) public userRewardSum;

    bool public paused = false;
    bool public entered = false;


    event SetPolicyAdmin(address policyAdmin);
    event ChangePaused(bool paused);
    event LockRewardToken(
        address user,
        uint256 lockPeriod,
        uint256 rewardTokenAmount,
        uint256 totalLockedRewardToken,
        uint256 totalLockedvRewardToken,
        uint256 unlockTime
    );
    event RefixBoosting(
        address user,
        uint256 lockPeriod,
        uint256 boostingAmount,
        uint256 unlockTime
    );
    event UnlockRewardToken(address user, uint256 vRewardTokenAmount, uint256 rewardTokenAmount);
    event UnlockRewardTokenUnlimited(
        address user,
        uint256 vRewardTokenBefore,
        uint256 vRewardTokenAfter,
        uint256 rewardTokenAmount,
        uint256 unlockTime
    );

    event ChangeMiningRate(uint256 _mining);
    event UpdateMiningIndex(uint256 lastMined, uint256 miningIndex);
    event UpdateBuybackIndex(uint256 amount, uint256 miningIndex);
    event GiveReward(
        address user,
        uint256 amount,
        uint256 lastIndex,
        uint256 rewardSum
    );
    event Compound(
        address user,
        uint256 reward,
        uint256 compoundAmount,
        uint256 transferAmount,
        uint256 mintAmount
    );

    constructor() public {}

    function _initialize(
        string memory _name,
        string memory _symbol,
        address _governance
    ) public {
        require(governance == address(0));
        name = _name;
        symbol = _symbol;
        governance = _governance;
        buyback = IGovernance(governance).buyback();
        policyAdmin = msg.sender;
    }

    modifier nonReentrant() {
        require(!entered, "ReentrancyGuard: reentrant call");

        entered = true;

        _;

        entered = false;
    }

    function version() external pure returns (string memory) {
        return "VotingRewardTokenImpl20240528";
    }

    function setPolicyAdmin(address _policyAdmin) external {
        require(msg.sender == policyAdmin);
        policyAdmin = _policyAdmin;

        emit SetPolicyAdmin(_policyAdmin);
    }

    function changePaused(bool _paused) external {
        require(msg.sender == policyAdmin);

        paused = _paused;
        emit ChangePaused(_paused);
    }

    // ============================ Staking =========================================

    function getUserUnlockTime(address user) public view returns (uint256) {
        if (unlockTime[user] == 0) return 0;

        if (now <= unlockTime[user]) {
            return unlockTime[user];
        } else if (now.sub(unlockTime[user]).mod(lockPeriod[user]) > 30 days) {
            return
                unlockTime[user].add(
                    now.sub(unlockTime[user]).div(lockPeriod[user]).add(1).mul(
                        lockPeriod[user]
                    )
                );
        } else {
            return
                unlockTime[user].add(
                    now.sub(unlockTime[user]).div(lockPeriod[user]).mul(
                        lockPeriod[user]
                    )
                );
        }
    }

    function getCurrentBalance(address user) public view returns (uint256) {
        require(user != address(0));

        uint256 index = snapShotCount[user];
        return index > 0 ? snapShotBalance[user][index - 1] : 0;
    }

    function getPriorBalance(
        address user,
        uint256 blockNumber
    ) public view returns (uint256) {
        require(blockNumber < block.number);
        require(user != address(0));

        uint256 index = snapShotCount[user];
        if (index == 0) {
            return 0;
        }

        if (snapShotBlock[user][index - 1] <= blockNumber) {
            return snapShotBalance[user][index - 1];
        }

        if (snapShotBlock[user][0] > blockNumber) {
            return 0;
        }

        uint256 lower = 0;
        uint256 upper = index - 1;
        while (upper > lower) {
            uint256 center = upper - ((upper - lower) / 2);
            uint256 centerBlock = snapShotBlock[user][center];
            uint256 centerBalance = snapShotBalance[user][center];

            if (centerBlock == blockNumber) {
                return centerBalance;
            } else if (centerBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return snapShotBalance[user][lower];
    }

    function getPriorSupply(uint256 blockNumber) public view returns (uint256) {
        require(blockNumber < block.number);
        require(
            snapShotBlock[address(0)][0] != 0 &&
                blockNumber >= snapShotBlock[address(0)][0]
        );

        uint256 index = snapShotCount[address(0)];
        if (index == 0) {
            return 0;
        }

        if (snapShotBlock[address(0)][index - 1] <= blockNumber) {
            return snapShotBalance[address(0)][index - 1];
        }

        uint256 lower = 0;
        uint256 upper = index - 1;
        while (upper > lower) {
            uint256 center = upper - ((upper - lower) / 2);
            uint256 centerBlock = snapShotBlock[address(0)][center];
            uint256 centerBalance = snapShotBalance[address(0)][center];

            if (centerBlock == blockNumber) {
                return centerBalance;
            } else if (centerBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return snapShotBalance[address(0)][lower];
    }

    function vRewardTokenAmountByPeriod(
        uint256 amount,
        uint256 period
    ) internal pure returns (uint256) {
        if (period == 120 days) {
            return amount;
        } else if (period == 240 days) {
            return amount.mul(2);
        } else if (period == 360 days) {
            return amount.mul(4);
        } else if (period == 18000 days) {
            return amount.mul(8);
        } else {
            require(false);
        }
    }

    function lockRewardToken(
        uint256 amount,
        uint256 lockPeriodRequested
    ) public nonReentrant {
        require(!paused, "Voting: Paused");
        if (Address.isContract(msg.sender)) {
            require(lockPeriodRequested == 18000 days);
        } else {
            require(
                lockPeriodRequested == 120 days ||
                    lockPeriodRequested == 240 days ||
                    lockPeriodRequested == 360 days ||
                    lockPeriodRequested == 18000 days
            );
        }

        giveReward(msg.sender, msg.sender);

        if (amount > 0) {
            amount = amount.mul(1e18);
            require(
                IERC20(IGovernance(governance).rewardToken()).transferFrom(
                    msg.sender,
                    address(this),
                    amount
                )
            );

            if (lockPeriod[msg.sender] == 18000 days) {
                require(lockPeriodRequested == 18000 days);
            }

            uint256 mintAmount = (lockPeriod[msg.sender] <= lockPeriodRequested)
                ? vRewardTokenAmountByPeriod(
                    lockedRewardToken[msg.sender].add(amount),
                    lockPeriodRequested
                ).sub(balanceOf[msg.sender])
                : vRewardTokenAmountByPeriod(amount, lockPeriodRequested);

            updateMiningIndex();
            lockedRewardToken[msg.sender] = lockedRewardToken[msg.sender].add(amount);
            balanceOf[msg.sender] = balanceOf[msg.sender].add(mintAmount);
            totalSupply = totalSupply.add(mintAmount);
            emit Transfer(address(0), msg.sender, mintAmount);

            if (now.add(lockPeriodRequested) > getUserUnlockTime(msg.sender)) {
                unlockTime[msg.sender] = now.add(lockPeriodRequested);
            }

            if (lockPeriod[msg.sender] < lockPeriodRequested) {
                lockPeriod[msg.sender] = lockPeriodRequested;
            }

            addSnapShot(msg.sender);
            addSupplySnapShot();
        } else {
            require(lockedRewardToken[msg.sender] > 0);

            if (lockPeriod[msg.sender] <= lockPeriodRequested) {
                updateMiningIndex();
                uint256 mintAmount = vRewardTokenAmountByPeriod(
                    lockedRewardToken[msg.sender],
                    lockPeriodRequested
                ).sub(balanceOf[msg.sender]);
                if (mintAmount > 0) {
                    balanceOf[msg.sender] = balanceOf[msg.sender].add(
                        mintAmount
                    );
                    totalSupply = totalSupply.add(mintAmount);
                    emit Transfer(address(0), msg.sender, mintAmount);
                }
                lockPeriod[msg.sender] = lockPeriodRequested;

                addSnapShot(msg.sender);
                addSupplySnapShot();
            }

            uint256 userUnlockTime = getUserUnlockTime(msg.sender);

            if (now.add(lockPeriodRequested) > userUnlockTime) {
                unlockTime[msg.sender] = (now > userUnlockTime)
                    ? userUnlockTime.add(lockPeriodRequested)
                    : now.add(lockPeriodRequested);
            }
        }

        emit LockRewardToken(
            msg.sender,
            lockPeriodRequested,
            amount,
            lockedRewardToken[msg.sender],
            balanceOf[msg.sender],
            getUserUnlockTime(msg.sender)
        );
    }

    function refixBoosting(uint256 lockPeriodRequested) public nonReentrant {
        require(!paused, "Voting: Paused");
        require(lockedRewardToken[msg.sender] > 0);
        require(
            lockPeriodRequested == 240 days ||
                lockPeriodRequested == 360 days ||
                lockPeriodRequested == 18000 days
        );

        giveReward(msg.sender, msg.sender);

        uint256 boostingAmount = vRewardTokenAmountByPeriod(
            lockedRewardToken[msg.sender],
            lockPeriodRequested
        );
        require(boostingAmount > balanceOf[msg.sender]);

        updateMiningIndex();
        uint256 mintAmount = boostingAmount.sub(balanceOf[msg.sender]);
        totalSupply = totalSupply.add(mintAmount);
        emit Transfer(address(0), msg.sender, mintAmount);

        balanceOf[msg.sender] = boostingAmount;

        if (now.add(lockPeriodRequested) > getUserUnlockTime(msg.sender)) {
            unlockTime[msg.sender] = now.add(lockPeriodRequested);
        }

        if (lockPeriod[msg.sender] < lockPeriodRequested) {
            lockPeriod[msg.sender] = lockPeriodRequested;
        }

        addSnapShot(msg.sender);
        addSupplySnapShot();

        emit RefixBoosting(
            msg.sender,
            lockPeriodRequested,
            boostingAmount,
            getUserUnlockTime(msg.sender)
        );
    }

    function unlockRewardToken() public nonReentrant {
        require(!Address.isContract(msg.sender));
        require(unlockTime[msg.sender] != 0 && balanceOf[msg.sender] != 0);
        require(now > getUserUnlockTime(msg.sender));
        require(lockPeriod[msg.sender] <= 360 days);

        giveReward(msg.sender, msg.sender);

        uint256 userLockedRewardToken = lockedRewardToken[msg.sender];
        uint256 userBalance = balanceOf[msg.sender];

        require(
            IERC20(IGovernance(governance).rewardToken()).transfer(
                msg.sender,
                lockedRewardToken[msg.sender]
            )
        );

        updateMiningIndex();
        totalSupply = totalSupply.sub(balanceOf[msg.sender]);
        emit Transfer(msg.sender, address(0), balanceOf[msg.sender]);

        lockedRewardToken[msg.sender] = 0;
        balanceOf[msg.sender] = 0;
        unlockTime[msg.sender] = 0;
        lockPeriod[msg.sender] = 0;

        addSnapShot(msg.sender);
        addSupplySnapShot();

        emit UnlockRewardToken(msg.sender, userBalance, userLockedRewardToken);
    }

    function unlockRewardTokenUnlimited() public nonReentrant {
        require(!Address.isContract(msg.sender));
        require(lockedRewardToken[msg.sender] > 0);
        require(lockPeriod[msg.sender] == 18000 days);
        require(lockedRewardToken[msg.sender].mul(8) == balanceOf[msg.sender]);

        giveReward(msg.sender, msg.sender);

        uint256 userBalanceBefore = balanceOf[msg.sender];
        uint256 userBalanceAfter = balanceOf[msg.sender].div(2);

        updateMiningIndex();
        totalSupply = totalSupply.sub(userBalanceAfter);
        emit Transfer(msg.sender, address(0), userBalanceAfter);

        balanceOf[msg.sender] = userBalanceAfter;
        require(lockedRewardToken[msg.sender].mul(4) == balanceOf[msg.sender]);

        unlockTime[msg.sender] = now.add(360 days);
        lockPeriod[msg.sender] = 360 days;

        addSnapShot(msg.sender);
        addSupplySnapShot();

        emit UnlockRewardTokenUnlimited(
            msg.sender,
            userBalanceBefore,
            userBalanceAfter,
            lockedRewardToken[msg.sender],
            unlockTime[msg.sender]
        );
    }

    function addSnapShot(address user) private {
        uint256 index = snapShotCount[user];

        if (index == 0 && snapShotBlock[user][index] == block.number) {
            snapShotBalance[user][index] = balanceOf[user];
        } else if (
            index != 0 && snapShotBlock[user][index - 1] == block.number
        ) {
            snapShotBalance[user][index - 1] = balanceOf[user];
        } else {
            snapShotBlock[user][index] = block.number;
            snapShotBalance[user][index] = balanceOf[user];
            snapShotCount[user] = snapShotCount[user].add(1);
        }
    }

    function addSupplySnapShot() private {
        uint256 index = snapShotCount[address(0)];

        if (index == 0 && snapShotBlock[address(0)][index] == block.number) {
            snapShotBalance[address(0)][index] = totalSupply;
        } else if (
            index != 0 && snapShotBlock[address(0)][index - 1] == block.number
        ) {
            snapShotBalance[address(0)][index - 1] = totalSupply;
        } else {
            snapShotBlock[address(0)][index] = block.number;
            snapShotBalance[address(0)][index] = totalSupply;
            snapShotCount[address(0)] = snapShotCount[address(0)].add(1);
        }
    }

    // ==================================== Mining =====================================
    function setEpochMining() private {
        (
            uint256 curEpoch,
            uint256 prevEpoch,
            uint256[] memory rates,
            uint256[] memory mined
        ) = IGovernance(governance).getEpochMining(address(0));
        if (curEpoch == prevEpoch) return;

        uint256 epoch = curEpoch.sub(prevEpoch);
        require(rates.length == epoch);
        require(rates.length == mined.length);

        uint256 thisMined;
        for (uint256 i = 0; i < epoch; i++) {
            thisMined = mining.mul(mined[i].sub(lastMined)).div(10000);

            require(rates[i] <= 10000);
            mining = rates[i];
            lastMined = mined[i];
            if (thisMined != 0 && totalSupply != 0) {
                miningIndex = miningIndex.add(
                    thisMined.mul(1e18).div(totalSupply)
                );
            }

            emit ChangeMiningRate(mining);
            emit UpdateMiningIndex(lastMined, miningIndex);
        }

        IGovernance(governance).acceptEpoch();
    }

    function updateMiningIndex() public returns (uint256) {
        setEpochMining();

        uint256 mined = IRewardToken(IGovernance(governance).rewardToken()).newMined();

        if (mined > lastMined) {
            uint256 thisMined = mining.mul(mined.sub(lastMined)).div(10000);

            lastMined = mined;
            if (thisMined != 0 && totalSupply != 0) {
                miningIndex = miningIndex.add(
                    thisMined.mul(1e18).div(totalSupply)
                );
            }

            emit UpdateMiningIndex(lastMined, miningIndex);
        }

        return miningIndex;
    }

    function giveReward(address user, address to) private {
        uint256 lastIndex = userLastIndex[user];
        uint256 currentIndex = updateMiningIndex();

        uint256 have = balanceOf[user];

        if (currentIndex > lastIndex) {
            userLastIndex[user] = currentIndex;

            if (have != 0) {
                uint256 amount = have.mul(currentIndex.sub(lastIndex)).div(1e18);
                IGovernance(governance).sendReward(to, amount);

                userRewardSum[user] = userRewardSum[user].add(amount);
                emit GiveReward(
                    user,
                    amount,
                    currentIndex,
                    userRewardSum[user]
                );
            }
        }
    }

    function claimReward() external nonReentrant {
        giveReward(msg.sender, msg.sender);
    }

    function compoundReward() external nonReentrant {
        require(!paused, "Voting: Paused");
        address user = msg.sender;
        IERC20 rewardToken = IERC20(IGovernance(governance).rewardToken());

        uint256 diff = rewardToken.balanceOf(address(this));
        giveReward(user, address(this));
        diff = rewardToken.balanceOf(address(this)).sub(diff);
        require(diff >= 1e18);

        uint256 compoundAmount = (diff / 1e18) * 1e18;
        uint256 transferAmount = diff.sub(compoundAmount);
        if (transferAmount != 0) {
            require(rewardToken.transfer(user, transferAmount));
        }

        uint256 mintAmount = vRewardTokenAmountByPeriod(
            compoundAmount,
            lockPeriod[user]
        );
        require(mintAmount != 0);

        updateMiningIndex();
        lockedRewardToken[user] = lockedRewardToken[user].add(compoundAmount);
        balanceOf[user] = balanceOf[user].add(mintAmount);
        totalSupply = totalSupply.add(mintAmount);
        emit Transfer(address(0), user, mintAmount);

        addSnapShot(user);
        addSupplySnapShot();

        emit Compound(user, diff, compoundAmount, transferAmount, mintAmount);
    }

    function updateBuybackIndex(uint256 amount) external nonReentrant {
        require(msg.sender == buyback);

        if (amount != 0 && totalSupply != 0) {
            miningIndex = miningIndex.add(amount.mul(1e18).div(totalSupply));
        }
        emit UpdateBuybackIndex(amount, miningIndex);
    }

    function() external payable {
        revert();
    }
}
