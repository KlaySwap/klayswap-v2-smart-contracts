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
pragma experimental ABIEncoderV2;

import "../libraries/SafeERC20.sol";
import "../misc/IWETH.sol";
import "./interfaces/IGovernance.sol";
import "./interfaces/IVotingRewardToken.sol";
import "../interfaces/IUniversalRouter.sol";
import "../v2/interfaces/IFactory.sol";
import "../v2/interfaces/IExchange.sol";
import "../v2/interfaces/IRouter.sol";

contract BuybackFundImpl {
    bool public entered = false;

    address public owner;
    address public nextOwner;
    mapping(address => bool) public validOperator;

    address public governance;
    address public factory;
    address public rewardToken;
    address public vRewardToken;
    address public router;
    address public universalRouter;
    address public WETH;

    mapping(address => bool) public validToken;
    mapping(address => address[]) public paths;
    mapping(address => address[]) public pathPools;

    mapping(address => uint256) public fund0;
    mapping(address => uint256) public fund1;

    mapping(uint256 => uint256) public totalDailyBurnt;
    mapping(uint256 => uint256) public totalWeeklyBurnt;

    mapping(address => mapping(uint256 => uint256)) public dailyBurnt;
    mapping(address => mapping(uint256 => uint256)) public weeklyBurnt;

    mapping(uint256 => bool) public epochBurnt;
    address public v3Factory;

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event SetToken(address token, bool valid, address[] path, address[] pool);
    event UpdateFund0(address pool, uint256 amount, uint256 totalPending);
    event UpdateFund1(address pool, uint256 amount, uint256 totalPending);
    event Buyback(address pool, uint256 amountA, uint256 amountB, uint256 burnt, uint256 dailyBurnt, uint256 totalDailyBurnt);
    event EpochBurnt(uint256 epoch, uint256 amount);

    constructor() public {}

    function _initialize(
        address _owner,
        address _governance
    ) public {
        require(owner == address(0));
        owner = _owner;
        governance = _governance;
        if (governance != address(0)) {
            factory = IGovernance(governance).factory();
            rewardToken = IGovernance(governance).rewardToken();
            router = IFactory(factory).router();
            WETH = IFactory(factory).WETH();
        }

        validOperator[_owner] = true;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    modifier onlyOperator {
        require(validOperator[msg.sender] || msg.sender == owner);
        _;
    }

    modifier nonReentrant {
        require(!entered, "ReentrancyGuard: reentrant call");

        entered = true;

        _;

        entered = false;
    }

    function () external payable {}

    function version() public pure returns (string memory) {
        return "buybackFundImpl20240528";
    }

    //////////////////////////// view /////////////////////////////
    function getBuybackMining(address pool, uint256 epoch, uint256 rate) public view returns (uint256) {
        require(pool > address(2));
        require(epoch <= IGovernance(governance).epoch());
        require(epoch > IGovernance(governance).lastEpoch(pool));

        uint256 daily = dailyBurnt[pool][epoch];
        uint256 weekly = weeklyBurnt[pool][epoch];
        uint256 dailyTotal = totalDailyBurnt[epoch];
        uint256 weeklyTotal = totalWeeklyBurnt[epoch];

        uint256 dailyRate = rate.div(2);
        uint256 weeklyRate = dailyRate;

        return (dailyTotal == 0 ? 0 : dailyRate.mul(daily).div(dailyTotal)).add(weeklyTotal == 0 ? 0 : weeklyRate.mul(weekly).div(weeklyTotal));
    }

    function getPoolBurnt(address pool, uint256 epoch) public view returns (uint256 daily, uint256 weekly) {
        require(pool > address(2));
        daily = dailyBurnt[pool][epoch];

        uint256 si = epoch;
        uint256 wi = epoch < 7 ? 0 : epoch.sub(7);

        uint256 burnt = 0;
        for(uint256 i = si; i > wi; i--){
            burnt = dailyBurnt[pool][i];
            weekly = weekly.add(burnt);
        }
    }

    function getTotalBurnt(uint256 epoch) public view returns (uint256 daily, uint256 weekly) {
        daily = totalDailyBurnt[epoch];

        uint256 si = epoch;
        uint256 wi = epoch < 7 ? 0 : epoch.sub(7);

        uint256 burnt = 0;
        for(uint256 i = si; i > wi; i--){
            burnt = totalDailyBurnt[i];
            weekly = weekly.add(burnt);
        }
    }

    function estimateBuybackMining(address pool, uint256 epoch, uint256 rate) public view returns (uint256) {
        uint256 daily = dailyBurnt[pool][epoch];
        uint256 weekly = weeklyBurnt[pool][epoch];
        uint256 dailyTotal = totalDailyBurnt[epoch];
        uint256 weeklyTotal = totalWeeklyBurnt[epoch];

        uint256 dailyRate = rate.div(2);
        uint256 weeklyRate = dailyRate;

        return (dailyTotal == 0 ? 0 : dailyRate.mul(daily).div(dailyTotal)).add(weeklyTotal == 0 ? 0 : weeklyRate.mul(weekly).div(weeklyTotal));
    }

    function getBuybackPath(address token) public view returns (address[] memory path, address[] memory pool){
        require(validToken[token]);

        path = paths[token];
        pool = pathPools[token];
    }
    ///////////////////////////////////////////////////////////////

    //////////////////////////// Admin ////////////////////////////
    function changeNextOwner(address _nextOwner) external onlyOwner {
        nextOwner = _nextOwner;
    }

    function changeOwner() external {
        require(msg.sender == nextOwner);

        owner = nextOwner;
        nextOwner = address(0);
    }

    function setValidOperator(address operator, bool valid) external onlyOwner {
        validOperator[operator] = valid;
    }

    function setVotingRewardToken(address _vRewardToken) external onlyOwner {
        vRewardToken = _vRewardToken;
    }

    function setUniversalRouter(address _universalRouter) external onlyOwner {
        universalRouter = _universalRouter;
    }

    function setV3Factory(address _v3Factory) external onlyOwner {
        v3Factory = _v3Factory;
    }

    function emergencyWithdraw(address token) external onlyOwner {
        IERC20 Token = IERC20(token);

        if(token == address(0)){
            uint256 amount = (address(this)).balance;
            if(amount != 0){
                (bool success, ) = owner.call.value(amount)("");
                require(success, "Transfer failed.");
            }
        }
        else{
            uint256 amount = Token.balanceOf(address(this));
            if(amount != 0){
                Token.safeTransfer(owner, amount);
            }
        }
    }

    function setToken(address token, bool valid, address[] memory path, address[] memory pool) public onlyOperator {
        require(path[path.length - 1] == rewardToken);
        validToken[token] = valid;

        if (valid) {
            if (token != address(0))
                require(IERC20(token).approve(universalRouter, uint256(-1)));
            paths[token] = path;
            pathPools[token] = pool;
        } else {
            if (token != address(0))
                require(IERC20(token).approve(universalRouter, 0));
            delete paths[token];
            delete pathPools[token];
        }

        emit SetToken(token, valid, path, pool);
    }

    modifier onlyGovernance {
        require(msg.sender == governance);
        _;
    }

    function epochBurn() external onlyGovernance {
        uint256 epoch = IGovernance(governance).epoch();
        require(!epochBurnt[epoch]);
        epochBurnt[epoch] = true;

        uint256 amount = totalDailyBurnt[epoch].div(2);
        IERC20(rewardToken).burn(amount);

        emit EpochBurnt(epoch, amount);
    }
    ///////////////////////////////////////////////////////////////

    //////////////////////////// Pools ////////////////////////////
    modifier onlyExistPool {
        require(IFactory(factory).poolExist(msg.sender) || IFactory(v3Factory).poolExist(msg.sender));
        _;
    }

    function updateFund0(uint256 amount) external onlyExistPool {
        fund0[msg.sender] = fund0[msg.sender].add(amount);
        emit UpdateFund0(msg.sender, amount, fund0[msg.sender]);
    }

    function updateFund1(uint256 amount) external onlyExistPool {
        fund1[msg.sender] = fund1[msg.sender].add(amount);
        emit UpdateFund1(msg.sender, amount, fund1[msg.sender]);
    }

    ///////////////////////////////////////////////////////////////

    function buyback(address pool) public nonReentrant onlyOperator {
        require(IFactory(factory).poolExist(pool) || IFactory(v3Factory).poolExist(pool));

        buybackInternal(pool);
    }

    function buybackPools(address[] memory pools) public nonReentrant onlyOperator {
        for(uint256 i = 0; i < pools.length; i++){
            require(IFactory(factory).poolExist(pools[i]) || IFactory(v3Factory).poolExist(pools[i]));
            buybackInternal(pools[i]);
        }
    }

    function buybackInternal(address pool) private {
        address token0 = IExchange(pool).token0();
        uint256 amountA = 0;
        uint256 burntA = 0;
        if(validToken[token0]){
            amountA = fund0[pool];
            fund0[pool] = 0;
            burntA = exchange(token0, amountA);
        }

        address token1 = IExchange(pool).token1();
        uint256 amountB = 0;
        uint256 burntB = 0;
        if(validToken[token1]){
            amountB = fund1[pool];
            fund1[pool] = 0;
            burntB = exchange(token1, amountB);
        }

        uint256 nextEpoch = (IGovernance(governance).epoch()).add(1);
        uint256 burnt = burntA.add(burntB);
        if(burnt != 0){
            totalDailyBurnt[nextEpoch] = totalDailyBurnt[nextEpoch].add(burnt);
            dailyBurnt[pool][nextEpoch] = dailyBurnt[pool][nextEpoch].add(burnt);

            emit Buyback(pool, amountA, amountB, burnt, dailyBurnt[pool][nextEpoch], totalDailyBurnt[nextEpoch]);

            // send buyback half amount
            IERC20(rewardToken).transfer(rewardToken, burnt.div(2));
            IVotingRewardToken(vRewardToken).updateBuybackIndex(burnt.div(2));
        }

        updateBoostingBurnt(pool, nextEpoch);
    }

    function exchange(address token, uint256 amount) private returns (uint256) {
        if(token == rewardToken || amount == 0) return amount;

        uint256 bal = token == address(0) ? (address(this)).balance : IERC20(token).balanceOf(address(this));
        if(bal < amount) amount = bal;

        uint256 diff = IERC20(rewardToken).balanceOf(address(this));

        if (pathPools[token].length > 0) {
            IUniversalRouter(universalRouter).swapExactTokensForTokens(
                amount,
                1,
                IUniversalRouter.SwapParams({
                    to: address(this),
                    path: paths[token],
                    pool: pathPools[token],
                    deadline: block.timestamp
                })
            );
        }

        diff = (IERC20(rewardToken).balanceOf(address(this))).sub(diff);

        return diff;
    }

    function updateBoostingBurnt(address pool, uint256 nextEpoch) private {
        totalDailyBurnt[nextEpoch] = totalDailyBurnt[nextEpoch].sub(dailyBurnt[pool][nextEpoch]);
        totalWeeklyBurnt[nextEpoch] = totalWeeklyBurnt[nextEpoch].sub(weeklyBurnt[pool][nextEpoch]);

        (uint256 daily, uint256 weekly) = getPoolBurnt(pool, nextEpoch);

        dailyBurnt[pool][nextEpoch] = daily;
        totalDailyBurnt[nextEpoch] = totalDailyBurnt[nextEpoch].add(daily);

        weeklyBurnt[pool][nextEpoch] = weekly;
        totalWeeklyBurnt[nextEpoch] = totalWeeklyBurnt[nextEpoch].add(weekly);
    }

    function forceUpdateBoostingBurnt(address[] memory pools) public {
        uint256 nextEpoch = (IGovernance(governance).epoch()).add(1);
        for(uint256 i = 0; i < pools.length; i++){
            updateBoostingBurnt(pools[i], nextEpoch);
        }
    }
}