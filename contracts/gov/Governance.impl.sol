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

import "../libraries/SafeMath.sol";
import "./interfaces/IVotingRewardToken.sol";
import "./interfaces/IGovernor.sol";
import "./interfaces/IBuybackFund.sol";
import "../v2/interfaces/IRewardToken.sol";
import "../v2/interfaces/IFactory.sol";
import "../v2/interfaces/IExchange.sol";

contract GovernanceImpl {
    using SafeMath for uint256;

    address public owner;
    address public nextOwner;
    address public executor;

    address public factory;
    address public rewardToken;
    address public vRewardToken;
    address public router;
    address public buyback;
    address public treasury;
    address public governor;
    address public singlePoolTransferStrategy;
    address public rewardTreasury;
    address public v3Factory;

    uint256 public vRewardTokenMiningRate;
    uint256 public treasuryMiningRate;
    uint256 public singlePoolMiningRate;
    uint256 public miningShareRate;
    uint256 public buybackRate;
    uint256 public rateNumerator;

    uint256 public interval;
    uint256 public nextTime;
    uint256 public prevTime;
    uint256 public epoch;

    bool public isInitialized = false;
    bool public entered = false;

    uint256 public transactionCount = 0;
    mapping(uint256 => bool) public transactionExecuted;
    mapping(uint256 => address) public transactionDestination;
    mapping(uint256 => uint256) public transactionValue;
    mapping(uint256 => bytes) public transactionData;

    mapping(uint256 => uint256) public epochMined;
    mapping(address => uint256) public lastEpoch;
    mapping(uint256 => mapping(address => uint256)) public epochRates;

    event Submission(
        uint256 transactionId,
        address destination,
        uint256 value,
        bytes data
    );
    event Execution(uint256 transactionId);
    event ExecutionFailure(uint256 transactionId);

    event ChangeNextOwner(address nextOwner);
    event ChangeOwner(address owner);
    event ChangeExecutor(address executor);
    event ChangeVotingRewardTokenMiningRate(uint256 vRewardTokenMiningRate);
    event ChangeTreasuryRate(uint256 treasuryRate);
    event ChangeSinglePoolMiningRate(uint256 singlePoolMiningRate);

    event UpdateEpoch(
        uint256 epoch,
        uint256 mined,
        uint256 vRewardTokenMining,
        uint256 singlePoolMining,
        uint256 treasuryMining,
        uint256 pairMining,
        uint256 prevTime,
        uint256 nextTime
    );

    constructor() public {}

    function _initialize(
        address _owner,
        address _executor,
        address _treasury
    ) public {
        require(owner == address(0));
        owner = _owner;
        executor = _executor;
        treasury = _treasury;
        vRewardTokenMiningRate = 6500;
        treasuryMiningRate = 2000;
        singlePoolMiningRate = 500;
        buybackRate = 20;
        rateNumerator = 1e14;
    }

    modifier nonReentrant() {
        require(!entered, "ReentrancyGuard: reentrant call");

        entered = true;

        _;

        entered = false;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyExecutor() {
        require(msg.sender == owner || msg.sender == executor);
        _;
    }

    modifier onlyWallet() {
        require(msg.sender == owner || msg.sender == address(this));
        _;
    }

    modifier onlyGovernor() {
        require(msg.sender == governor);
        _;
    }

    function version() external pure returns (string memory) {
        return "GovernanceImpl20240528";
    }

    function changeNextOwner(address _nextOwner) external onlyOwner {
        nextOwner = _nextOwner;

        emit ChangeNextOwner(_nextOwner);
    }

    function changeOwner() external {
        require(msg.sender == nextOwner);

        owner = nextOwner;
        nextOwner = address(0);

        emit ChangeOwner(owner);
    }

    function setExecutor(address _executor) external onlyOwner {
        require(_executor != address(0));

        executor = _executor;

        emit ChangeExecutor(executor);
    }

    function setV2Addresses(
        address _factory,
        address _router,
        address _rewardToken
    ) external onlyOwner {
        factory = _factory;
        router = _router;
        rewardToken = _rewardToken;
    }

    function setvRewardToken(address _vRewardToken) external onlyOwner {
        vRewardToken = _vRewardToken;
    }

    function setBuyback(address _buyback) external onlyOwner {
        buyback = _buyback;
    }

    function setGovernor(address _governor) external onlyOwner {
        governor = _governor;
    }

    function setRewardTreasury(address _rewardTreasury) external onlyOwner {
        rewardTreasury = _rewardTreasury;
    }

    function setV3Factory(address _v3Factory) external onlyOwner {
        require(_v3Factory != address(0));

        v3Factory = _v3Factory;
    }

    function setSinglePoolTransferStrategy(address _transferStrategy) external onlyOwner {
        require(_transferStrategy != address(0));

        singlePoolTransferStrategy = _transferStrategy;
    }

    function setTimeParams(
        uint256 _interval,
        uint256 _nextTime
    ) public onlyOwner {
        require(_interval != 0);
        require(_nextTime > now);

        interval = _interval;
        nextTime = _nextTime;
    }

    // rewardToken 분배
    // Pair : Single : vRewardToken : Treasury
    function setTreasuryRate(uint256 rate) public onlyWallet {
        require(rate <= 10000);

        treasuryMiningRate = rate;

        emit ChangeTreasuryRate(treasuryMiningRate);
    }

    function setVotingRewardTokenMiningRate(uint256 rate) public onlyWallet {
        require(rate <= 10000);

        vRewardTokenMiningRate = rate;
        emit ChangeVotingRewardTokenMiningRate(vRewardTokenMiningRate);
    }

    function setSinglePoolMiningRate(uint256 rate) public onlyWallet {
        require(rate <= 10000);

        singlePoolMiningRate = rate;
        emit ChangeSinglePoolMiningRate(singlePoolMiningRate);
    }

    function changeMiningRates(
        uint256 _singlePoolRate,
        uint256 _pairPoolRate,
        uint256 _vRewardTokenRate,
        uint256 _treasuryRate
    ) public {
        require(msg.sender == address(this));
        require(_singlePoolRate.add(_pairPoolRate).add(_vRewardTokenRate).add(_treasuryRate) == 10000);

        setVotingRewardTokenMiningRate(_vRewardTokenRate);
        setSinglePoolMiningRate(_singlePoolRate);
        setTreasuryRate(_treasuryRate);
    }

    function addTransaction(
        address destination,
        uint256 value,
        bytes calldata data
    ) external onlyGovernor {
        uint256 tid = transactionCount;
        transactionDestination[tid] = destination;
        transactionValue[tid] = value;
        transactionData[tid] = data;

        transactionCount = tid + 1;

        emit Submission(tid, destination, value, data);
    }

    function executeTransaction(uint256 tid) external onlyExecutor nonReentrant {
        require(!transactionExecuted[tid]);

        transactionExecuted[tid] = true;

        address dest = transactionDestination[tid];
        uint256 value = transactionValue[tid];
        bytes memory data = transactionData[tid];

        bool result;
        if (dest != address(0)) {
            (result, ) = dest.call.value(value)(data);
        } else {
            result = true;
        }

        if (result) emit Execution(tid);
        else {
            emit ExecutionFailure(tid);
        }

        IGovernor(governor).executed(tid, result);
    }

    function sendReward(address user, uint256 amount) external nonReentrant {
        require(
            msg.sender == vRewardToken ||
            msg.sender == singlePoolTransferStrategy ||
            msg.sender == rewardTreasury
        );
        IRewardToken(rewardToken).sendReward(user, amount);
    }

    // epochRate [0]: vRewardToken [1]: singlePool [2]: treasury [3]: pair
    function setMiningRate() external {
        require(msg.sender == tx.origin);
        require(vRewardTokenMiningRate != 0);
        require(singlePoolMiningRate != 0);
        require(nextTime < now);

        epoch = epoch + 1;
        epochMined[epoch] = IRewardToken(rewardToken).newMined();
        epochRates[epoch][address(0)] = vRewardTokenMiningRate;
        epochRates[epoch][address(1)] = singlePoolMiningRate;
        epochRates[epoch][address(2)] = treasuryMiningRate;
        epochRates[epoch][address(3)] = uint256(10000).sub(
                vRewardTokenMiningRate.add(singlePoolMiningRate).add(treasuryMiningRate));

        prevTime = nextTime;
        nextTime = nextTime.add(
            now.sub(prevTime).div(interval).add(1).mul(interval)
        );

        IBuybackFund(buyback).epochBurn();

        emit UpdateEpoch(
            epoch,
            epochMined[epoch],
            epochRates[epoch][address(0)],
            epochRates[epoch][address(1)],
            epochRates[epoch][address(2)],
            epochRates[epoch][address(3)],
            prevTime,
            nextTime
        );
    }

    function acceptEpoch() external {
        require(
            IFactory(factory).poolExist(msg.sender) ||
            IFactory(v3Factory).poolExist(msg.sender) ||
            msg.sender == vRewardToken ||
            msg.sender == singlePoolTransferStrategy||
            msg.sender == rewardTreasury
        );

        address pool = msg.sender;
        if (pool == vRewardToken) {
            pool = address(0);
        } else if (pool == singlePoolTransferStrategy) {
            pool = address(1);
        } else if (pool == rewardTreasury) {
            pool = address(2);
        }

        lastEpoch[pool] = epoch;
    }

    // For VotingRewardToken mining, SinglePool mining
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
        )
    {
        require(pool != address(3));

        curEpoch = epoch;
        prevEpoch = lastEpoch[pool];

        uint256 len = curEpoch.sub(prevEpoch);
        mined = new uint256[](len);
        rates = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            mined[i] = epochMined[i + prevEpoch + 1];
            rates[i] = epochRates[i + prevEpoch + 1][pool];
        }
    }

    // For Liquidity Pool
    // totalSum = 10000 * rateNumerator
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
        )
    {
        require(IFactory(factory).poolExist(pool) || IFactory(v3Factory).poolExist(pool));
        require(pool > address(3));

        curEpoch = epoch;
        prevEpoch = lastEpoch[pool];

        uint256 len = curEpoch.sub(prevEpoch);
        mined = new uint256[](len);
        rates = new uint256[](len);

        uint256 e = 0;
        for (uint256 i = 0; i < len; i++) {
            e = i + prevEpoch + 1;

            mined[i] = epochMined[e];
            rates[i] = IBuybackFund(buyback).getBuybackMining(
                pool,
                e,
                epochRates[e][address(3)].mul(rateNumerator)
            );
        }
    }

    function execute(address _to, uint256 _value, bytes calldata _data) external onlyOwner {
        (bool result,) = _to.call.value(_value)(_data);
        if (!result) {
            revert();
        }
    }

    function() external payable {
        revert();
    }
}
