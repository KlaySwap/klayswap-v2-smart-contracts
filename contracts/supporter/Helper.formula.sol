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
import "../misc/IERC20.sol";
import "../misc/IWETH.sol";
import "../v2/interfaces/IFactory.sol";
import "../v2/interfaces/IExchange.sol";
import "../v2/interfaces/IRouter.sol";
import "../gov/interfaces/IGovernance.sol";

contract Helper {
    using SafeMath for uint256;

    string public constant version = "Helper20240715";
    address public governance;
    address public factory;
    address public router;
    address payable public withdraw;

    constructor () public {}

    function _initialize(address _governance, address payable _withdraw) public {
        require(governance == address(0));
        governance = _governance;
        factory = IGovernance(governance).factory();
        router = IFactory(factory).router();

        require(_withdraw != address(0));
        withdraw = _withdraw;
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function getSwapAmt(
        address lp,
        address token,
        uint256 amtA
    ) public view returns (uint256 maxSwap, uint256 estimateTarget) {
        IExchange pool = IExchange(lp);

        uint256 fee = pool.fee();
        require(fee < 10000);

        uint256 resA = 0;
        bool exist = false;
        if (token == pool.token0()) {
            exist = true;
            (resA, ) = pool.getCurrentPool();
        }
        if (token == pool.token1()) {
            exist = true;
            (, resA) = pool.getCurrentPool();
        }
        require(exist);

        uint256 addA = (20000 - fee).mul(20000 - fee).mul(resA);
        uint256 addB = (10000 - fee).mul(40000).mul(amtA);
        uint256 sqrtRes = sqrt(resA.mul(addA.add(addB)));
        uint256 subRes = resA.mul(20000 - fee);
        uint256 divRes = (10000 - fee).mul(2);

        maxSwap = (sqrtRes.sub(subRes)).div(divRes);
        estimateTarget = pool.estimatePos(token, maxSwap);
    }

    function addLiquidityWithETH(
        address lp,
        uint256 inputForLiquidity,
        uint256 targetForLiquidity
    ) public payable {
        IFactory Factory = IFactory(factory);
        IRouter Router = IRouter(router);
        IExchange pool = IExchange(lp);
        address WETH = Router.WETH();

        require(Factory.poolExist(lp));
        require(pool.token0() == WETH || pool.token1() == WETH);
        bool isWETH0 = (WETH == pool.token0());
        uint256 amount = msg.value;

        (uint256 maxSwap, ) = getSwapAmt(lp, WETH, amount);
        address target = isWETH0 ? pool.token1() : pool.token0();

        uint256 balanceTarget = balanceOf(target);

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = target;

        IWETH(WETH).deposit.value(msg.value)();
        approve(WETH, router, maxSwap);

        Router.swapExactTokensForTokens(
            maxSwap,
            1,
            path,
            address(this),
            block.timestamp + 600
        );
        balanceTarget = (balanceOf(target)).sub(balanceTarget);

        require(targetForLiquidity <= balanceTarget);
        require(inputForLiquidity <= (amount).sub(maxSwap));

        if (isWETH0) {
            addLiquidity(lp, (amount).sub(maxSwap), balanceTarget, true);
        } else {
            addLiquidity(lp, balanceTarget, (amount).sub(maxSwap), true);
        }
    }

    function addLiquidityWithToken(
        address lp,
        address token,
        uint256 amount,
        uint256 inputForLiquidity,
        uint256 targetForLiquidity
    ) public {
        IFactory Factory = IFactory(factory);
        IRouter Router = IRouter(router);
        IExchange pool = IExchange(lp);

        require(Factory.poolExist(lp));
        require(token != address(0));

        require(IERC20(token).transferFrom(msg.sender, address(this), amount));

        address token0 = pool.token0();
        address token1 = pool.token1();

        (uint256 maxSwap, ) = getSwapAmt(lp, token, amount);
        address target = token == token0 ? token1 : token0;

        approve(token, router, maxSwap);

        uint256 balanceTarget = balanceOf(target);

        {
            address[] memory path = new address[](2);
            path[0] = token;
            path[1] = target;

            Router.swapExactTokensForTokens(
                maxSwap,
                1,
                path,
                address(this),
                block.timestamp + 600
            );
        }
        balanceTarget = (balanceOf(target)).sub(balanceTarget);

        require(targetForLiquidity <= balanceTarget);
        require(inputForLiquidity <= (amount).sub(maxSwap));

        if (token == token0) {
            addLiquidity(lp, (amount).sub(maxSwap), balanceTarget, false);
        } else {
            addLiquidity(lp, balanceTarget, (amount).sub(maxSwap), false);
        }
    }

    function addLiquidity(
        address lp,
        uint256 inputA,
        uint256 inputB,
        bool isETH
    ) private {
        IExchange pool = IExchange(lp);
        IRouter Router = IRouter(router);
        address WETH = Router.WETH();

        address token0 = pool.token0();
        address token1 = pool.token1();

        uint256 diffA = balanceOf(token0);
        uint256 diffB = balanceOf(token1);

        approve(token0, lp, inputA);
        approve(token1, lp, inputB);

        pool.addTokenLiquidityWithLimit(inputA, inputB, 1, 1, address(this));

        diffA = (diffA).sub(balanceOf(token0));
        diffB = (diffB).sub(balanceOf(token1));

        transfer(lp, msg.sender, balanceOf(lp));
        if (inputA > diffA) {
            if (isETH && token0 == WETH) {
                IWETH(WETH).withdraw(inputA.sub(diffA));
                (bool success, ) = msg.sender.call.value(inputA.sub(diffA))("");
                require(success, "Helper: ETH transfer failed");
            } else {
                transfer(token0, msg.sender, (inputA).sub(diffA));
            }
        }

        if (inputB > diffB) {
            if (isETH && token1 == WETH) {
                IWETH(WETH).withdraw(inputB.sub(diffB));
                (bool success, ) = msg.sender.call.value(inputB.sub(diffB))("");
                require(success, "Helper: ETH transfer failed");
            } else {
                transfer(token1, msg.sender, (inputB).sub(diffB));
            }
        }
    }

    function balanceOf(address token) private view returns (uint256) {
        return
            token == address(0)
                ? (address(this)).balance
                : IERC20(token).balanceOf(address(this));
    }

    function approve(address token, address spender, uint256 amount) private {
        require(IERC20(token).approve(spender, amount));
    }

    function transfer(
        address token,
        address payable to,
        uint256 amount
    ) private {
        if (amount == 0) return;

        if (token == address(0)) {
            (bool success, ) = to.call.value(amount)("");
            require(success, "Transfer failed.");
        } else {
            require(IERC20(token).transfer(to, amount));
        }
    }

    function inCaseTokensGetStuck(address token) public {
        require(msg.sender == withdraw);

        transfer(token, withdraw, balanceOf(token));
    }

    function() external payable {}
}
