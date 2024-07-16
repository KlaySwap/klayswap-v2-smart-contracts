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

import "./Exchange.sol";
import "../libraries/Math.sol";
import "../libraries/SafeMath.sol";
import "../libraries/UQ112x112.sol";
import "../misc/IERC20.sol";
import "../misc/IWETH.sol";
import "./interfaces/IFactory.sol";
import "./interfaces/IRewardToken.sol";
import "./interfaces/IRouter.sol";
import "../gov/interfaces/IGovernance.sol";
import "../gov/interfaces/IBuybackFund.sol";
import "../treasury/interfaces/ITreasury.sol";

contract ExchangeImpl is Exchange {
    using SafeMath for uint256;
    using UQ112x112 for uint224;

    uint256 public constant MINIMUM_LIQUIDITY = 10**3;

    event Sync(uint112 reserveA, uint112 reserveB);

    function version() public pure returns (string memory) {
        return "ExchangeImpl20240528";
    }

    modifier nonReentrant() {
        require(!entered, "ReentrancyGuard: reentrant call");

        entered = true;

        _;

        entered = false;
    }

    constructor() public Exchange(address(0), address(1), 0) {}

    function transfer(
        address _to,
        uint256 _value
    ) public nonReentrant returns (bool) {
        decreaseBalance(msg.sender, _value);
        increaseBalance(_to, _value);

        emit Transfer(msg.sender, _to, _value);

        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public nonReentrant returns (bool) {
        decreaseBalance(_from, _value);
        increaseBalance(_to, _value);

        allowance[_from][msg.sender] = allowance[_from][msg.sender].sub(_value);

        emit Transfer(_from, _to, _value);

        return true;
    }

    function _approve(address owner, address spender, uint256 value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        require(_spender != address(0));
        _approve(msg.sender, _spender, _value);

        return true;
    }

    function _update() private {
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        require(balance0 <= uint112(-1) && balance1 <= uint112(-1), "OVERFLOW");

        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired

        if (timeElapsed > 0 && reserve0 != 0 && reserve1 != 0) {
            // * never overflows, and + overflow is desired
            price0CumulativeLast +=
                uint256(UQ112x112.encode(reserve1).uqdiv(reserve0)) *
                timeElapsed;
            price1CumulativeLast +=
                uint256(UQ112x112.encode(reserve0).uqdiv(reserve1)) *
                timeElapsed;
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;

        emit Sync(reserve0, reserve1);
    }

    function getReserves()
        public
        view
        returns (
            uint112 _reserve0,
            uint112 _reserve1,
            uint32 _blockTimestampLast
        )
    {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    // ======== Change supply & balance ========

    function increaseTotalSupply(uint256 amount) private {
        ITreasury(getTreasury()).updateDistributionIndex(address(this));
        updateMiningIndex();
        totalSupply = totalSupply.add(amount);
    }

    function decreaseTotalSupply(uint256 amount) private {
        ITreasury(getTreasury()).updateDistributionIndex(address(this));
        updateMiningIndex();
        totalSupply = totalSupply.sub(amount);
    }

    function increaseBalance(address user, uint256 amount) private {
        giveReward(user);
        balanceOf[user] = balanceOf[user].add(amount);
    }

    function decreaseBalance(address user, uint256 amount) private {
        giveReward(user);
        balanceOf[user] = balanceOf[user].sub(amount);
    }

    function getTreasury() public view returns (address) {
        return IGovernance(IFactory(factory).owner()).treasury();
    }

    function getTokenSymbol(
        address token
    ) private view returns (string memory) {
        return IERC20(token).symbol();
    }

    function initPool() external {
        require(msg.sender == factory);

        IGovernance(IFactory(factory).owner()).acceptEpoch();

        string memory symbolA = getTokenSymbol(token0);
        string memory symbolB = getTokenSymbol(token1);

        name = string(abi.encodePacked(name, " ", symbolA, "-", symbolB));

        decimals = IERC20(token0).decimals();
        WETH = IFactory(factory).WETH();

        uint256 chainId = IFactory(factory).chainId();
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256(bytes(version())),
                chainId,
                address(this)
            )
        );

        _update();
    }

    // ======== Administration ========

    event ChangeMiningRate(uint256 _mining);
    event ChangeFee(uint256 _fee);
    event ChangeRateNumerator(uint256 rateNumerator);

    function setEpochMining() private {
        (
            uint256 curEpoch,
            uint256 prevEpoch,
            uint256[] memory mined,
            uint256[] memory rates
        ) = IGovernance(IFactory(factory).owner()).getBoostingMining(
                address(this)
            );
        if (curEpoch == prevEpoch) return;

        uint256 epoch = curEpoch.sub(prevEpoch);
        require(rates.length == epoch);
        require(mined.length == epoch);

        uint256 thisMined;
        for (uint256 i = 0; i < epoch; i++) {
            thisMined = mining.mul(mined[i].sub(lastMined)).div(1e18);

            require(rates[i] <= 1e18);
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

        IGovernance(IFactory(factory).owner()).acceptEpoch();
    }

    function changeFee(uint256 _fee) public {
        require(msg.sender == factory);
        require(_fee >= 5 && _fee <= 100);

        fee = _fee;

        emit ChangeFee(_fee);
    }

    // ======== Mining & Reward ========

    event UpdateMiningIndex(uint256 lastMined, uint256 miningIndex);
    event GiveReward(
        address user,
        uint256 amount,
        uint256 lastIndex,
        uint256 rewardSum
    );

    function updateMiningIndex() public returns (uint256) {
        setEpochMining();

        uint256 mined = IRewardToken(rewardToken).newMined();

        if (mined > lastMined) {
            uint256 thisMined = mining.mul(mined.sub(lastMined)).div(1e18);

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

    function giveReward(address user) private {
        ITreasury(getTreasury()).claim(user, address(this));

        uint256 lastIndex = userLastIndex[user];
        uint256 currentIndex = updateMiningIndex();

        uint256 have = balanceOf[user];

        if (currentIndex > lastIndex) {
            userLastIndex[user] = currentIndex;

            if (have != 0) {
                uint256 amount = have.mul(currentIndex.sub(lastIndex)).div(1e18);
                IRewardToken(rewardToken).sendReward(user, amount);

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

    function claimReward() public nonReentrant {
        giveReward(msg.sender);
    }

    function claimReward(address user) public nonReentrant {
        giveReward(user);
    }

    // ======== Exchange ========

    event ExchangePos(
        address token0,
        uint256 amount0,
        address token1,
        uint256 amount1
    );
    event ExchangeNeg(
        address token0,
        uint256 amount0,
        address token1,
        uint256 amount1
    );

    function calcPos(
        uint256 poolIn,
        uint256 poolOut,
        uint256 input
    ) private view returns (uint256) {
        if (totalSupply == 0) return 0;

        uint256 num = poolOut.mul(input).mul(uint256(10000).sub(fee));
        uint256 den = poolIn.mul(10000).add(input.mul(uint256(10000).sub(fee)));

        return num.div(den);
    }

    function calcNeg(
        uint256 poolIn,
        uint256 poolOut,
        uint256 output
    ) private view returns (uint256) {
        if (output >= poolOut) return uint256(-1);

        uint256 num = poolIn.mul(output).mul(10000);
        uint256 den = poolOut.sub(output).mul(uint256(10000).sub(fee));

        return num.ceilDiv(den);
    }

    function getCurrentPool() public view returns (uint256, uint256) {
        (uint256 pool0, uint256 pool1, ) = getReserves();

        return (pool0, pool1);
    }

    function estimatePos(
        address token,
        uint256 amount
    ) public view returns (uint256) {
        require(token == token0 || token == token1);

        (uint256 pool0, uint256 pool1) = getCurrentPool();

        if (token == token0) {
            return calcPos(pool0, pool1, amount);
        }

        return calcPos(pool1, pool0, amount);
    }

    function estimateNeg(
        address token,
        uint256 amount
    ) public view returns (uint256) {
        require(token == token0 || token == token1);

        (uint256 pool0, uint256 pool1) = getCurrentPool();

        if (token == token0) {
            return calcNeg(pool1, pool0, amount);
        }

        return calcNeg(pool0, pool1, amount);
    }

    function grabToken(address token, uint256 amount) private {
        uint256 userBefore = IERC20(token).balanceOf(msg.sender);
        uint256 thisBefore = IERC20(token).balanceOf(address(this));

        require(
            IERC20(token).transferFrom(msg.sender, address(this), amount),
            "grabToken failed"
        );

        uint256 userAfter = IERC20(token).balanceOf(msg.sender);
        uint256 thisAfter = IERC20(token).balanceOf(address(this));

        require(userAfter.add(amount) == userBefore);
        require(thisAfter == thisBefore.add(amount));
    }

    function sendToken(address token, uint256 amount, address user) private {
        uint256 userBefore = IERC20(token).balanceOf(user);
        uint256 thisBefore = IERC20(token).balanceOf(address(this));

        require(
            IERC20(token).transfer(user, amount),
            "Exchange: sendToken failed"
        );

        uint256 userAfter = IERC20(token).balanceOf(user);
        uint256 thisAfter = IERC20(token).balanceOf(address(this));

        require(
            userAfter == userBefore.add(amount),
            "Exchange: user balance not equal"
        );
        require(
            thisAfter.add(amount) == thisBefore,
            "Exchange: this balance not equal"
        );
    }

    function exchangePos(
        address tokenIn,
        uint256 amountIn
    ) public nonReentrant returns (uint256) {
        require(msg.sender == router);

        require(tokenIn == token0 || tokenIn == token1);
        require(amountIn != 0);

        uint256 output = 0;
        (uint256 pool0, uint256 pool1) = getCurrentPool();

        if (tokenIn == token0) {
            output = calcPos(pool0, pool1, amountIn);
            require(output != 0);

            IRouter(router).sendTokenToExchange(token0, amountIn);
            sendToken(token1, output, router);

            emit ExchangePos(token0, amountIn, token1, output);

            address governance = IFactory(factory).owner();
            uint256 buybackRate = IGovernance(governance).buybackRate();
            uint256 exchangeFee = amountIn.mul(fee).div(10000);
            uint256 buybackFee = exchangeFee.mul(buybackRate).div(100);
            address buyback = IGovernance(governance).buyback();

            if (buybackFee != 0) {
                sendToken(token0, buybackFee, buyback);
                IBuybackFund(buyback).updateFund0(buybackFee);
            }
        } else {
            output = calcPos(pool1, pool0, amountIn);
            require(output != 0);

            IRouter(router).sendTokenToExchange(token1, amountIn);
            sendToken(token0, output, router);

            emit ExchangePos(token1, amountIn, token0, output);

            address governance = IFactory(factory).owner();
            uint256 buybackRate = IGovernance(governance).buybackRate();
            uint256 exchangeFee = amountIn.mul(fee).div(10000);
            uint256 buybackFee = exchangeFee.mul(buybackRate).div(100);
            address buyback = IGovernance(governance).buyback();
            if (buybackFee != 0) {
                sendToken(token1, buybackFee, buyback);
                IBuybackFund(buyback).updateFund1(buybackFee);
            }
        }

        _update();

        return output;
    }

    function exchangeNeg(
        address tokenOut,
        uint256 amountOut
    ) public nonReentrant returns (uint256) {
        require(msg.sender == router);

        require(tokenOut == token0 || tokenOut == token1);
        require(amountOut != 0);

        uint256 input = 0;
        (uint256 pool0, uint256 pool1) = getCurrentPool();

        if (tokenOut == token0) {
            input = calcNeg(pool1, pool0, amountOut);
            require(input != 0);

            IRouter(router).sendTokenToExchange(token1, input);
            sendToken(token0, amountOut, router);

            emit ExchangeNeg(token1, input, token0, amountOut);

            address governance = IFactory(factory).owner();
            uint256 buybackRate = IGovernance(governance).buybackRate();
            uint256 exchangeFee = input.mul(fee).div(10000);
            uint256 buybackFee = exchangeFee.mul(buybackRate).div(100);
            address buyback = IGovernance(governance).buyback();

            if (buybackFee != 0) {
                sendToken(token1, buybackFee, buyback);
                IBuybackFund(buyback).updateFund1(buybackFee);
            }
        } else {
            input = calcNeg(pool0, pool1, amountOut);
            require(input != 0);

            IRouter(router).sendTokenToExchange(token0, input);
            sendToken(token1, amountOut, router);

            emit ExchangeNeg(token0, input, token1, amountOut);

            address governance = IFactory(factory).owner();
            uint256 buybackRate = IGovernance(governance).buybackRate();
            uint256 exchangeFee = input.mul(fee).div(10000);
            uint256 buybackFee = exchangeFee.mul(buybackRate).div(100);
            address buyback = IGovernance(governance).buyback();

            if (buybackFee != 0) {
                sendToken(token0, buybackFee, buyback);
                IBuybackFund(buyback).updateFund0(buybackFee);
            }
        }

        _update();

        return input;
    }

    // ======== Add/remove Liquidity ========

    event AddLiquidity(
        address user,
        address token0,
        uint256 amount0,
        address token1,
        uint256 amount1,
        uint256 liquidity
    );
    event RemoveLiquidity(
        address user,
        address token0,
        uint256 amount0,
        address token1,
        uint256 amount1,
        uint256 liquidity
    );

    function addLiquidity(
        uint256 amount0,
        uint256 amount1,
        address user
    ) private returns (uint256 real0, uint256 real1, uint256 amountLP) {
        require(amount0 != 0 && amount1 != 0);
        real0 = amount0;
        real1 = amount1;

        (uint256 pool0, uint256 pool1) = getCurrentPool();

        if (totalSupply == 0) {
            grabToken(token0, amount0);
            grabToken(token1, amount1);

            amountLP = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);

            increaseTotalSupply(amountLP.add(MINIMUM_LIQUIDITY));
            increaseBalance(address(0), MINIMUM_LIQUIDITY);
            increaseBalance(user, amountLP);


            emit AddLiquidity(user, token0, amount0, token1, amount1, amountLP);

            emit Transfer(address(0), address(0), MINIMUM_LIQUIDITY);
            emit Transfer(address(0), user, amountLP);
        } else {
            uint256 with0 = totalSupply.mul(amount0).div(pool0);
            uint256 with1 = totalSupply.mul(amount1).div(pool1);

            if (with0 < with1) {
                require(with0 > 0);

                grabToken(token0, amount0);

                real1 = with0.mul(pool1).ceilDiv(totalSupply);
                require(real1 <= amount1);

                grabToken(token1, real1);

                increaseTotalSupply(with0);
                increaseBalance(user, with0);

                amountLP = with0;

                emit AddLiquidity(user, token0, amount0, token1, real1, with0);

                emit Transfer(address(0), user, with0);
            } else {
                require(with1 > 0);

                grabToken(token1, amount1);

                real0 = with1.mul(pool0).ceilDiv(totalSupply);
                require(real0 <= amount0);

                grabToken(token0, real0);

                increaseTotalSupply(with1);
                increaseBalance(user, with1);

                amountLP = with1;

                emit AddLiquidity(user, token0, real0, token1, amount1, with1);

                emit Transfer(address(0), user, with1);
            }
        }

        _update();

        return (real0, real1, amountLP);
    }

    function addTokenLiquidityWithLimit(
        uint256 amount0,
        uint256 amount1,
        uint256 minAmount0,
        uint256 minAmount1,
        address user
    )
        public
        nonReentrant
        returns (uint256 real0, uint256 real1, uint256 amountLP)
    {
        (real0, real1, amountLP) = addLiquidity(amount0, amount1, user);
        require(real0 >= minAmount0, "minAmount0 is not satisfied");
        require(real1 >= minAmount1, "minAmount1 is not satisfied");
    }

    function removeLiquidityWithLimit(
        uint256 amount,
        uint256 minAmount0,
        uint256 minAmount1,
        address user
    ) public nonReentrant returns (uint256, uint256) {
        require(amount != 0);

        (uint256 pool0, uint256 pool1) = getCurrentPool();

        uint256 amount0 = pool0.mul(amount).div(totalSupply);
        uint256 amount1 = pool1.mul(amount).div(totalSupply);

        require(amount0 >= minAmount0, "minAmount0 is not satisfied");
        require(amount1 >= minAmount1, "minAmount1 is not satisfied");

        decreaseTotalSupply(amount);
        decreaseBalance(msg.sender, amount);

        emit Transfer(msg.sender, address(0), amount);

        if (amount0 > 0) sendToken(token0, amount0, user);
        if (amount1 > 0) sendToken(token1, amount1, user);

        _update();

        emit RemoveLiquidity(
            msg.sender,
            token0,
            amount0,
            token1,
            amount1,
            amount
        );

        return (amount0, amount1);
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(deadline >= block.timestamp, "UniswapV2: EXPIRED");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH,
                        owner,
                        spender,
                        value,
                        nonces[owner]++,
                        deadline
                    )
                )
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(
            recoveredAddress != address(0) && recoveredAddress == owner,
            "UniswapV2: INVALID_SIGNATURE"
        );
        _approve(owner, spender, value);
    }

    function sync() external nonReentrant {
        _update();
    }

    function() external payable {
        require(msg.sender == WETH);
    }
}
