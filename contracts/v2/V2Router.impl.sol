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

import "./interfaces/IFactory.sol";
import "./interfaces/IExchange.sol";
import "../misc/IWETH.sol";
import "../libraries/SafeERC20.sol";

library SwapLibrary {
    using SafeMath for uint256;

    function sortTokens(
        address factory,
        address tokenA,
        address tokenB
    ) internal view returns (address token0, address token1) {
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        address pool = pairFor(factory, tokenA, tokenB);
        require(pool != address(0));
        (token0, token1) = (tokenA == IExchange(pool).token0())
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
    }

    function pairFor(
        address factory,
        address tokenA,
        address tokenB
    ) internal view returns (address pair) {
        pair = IFactory(factory).tokenToPool(tokenA, tokenB);
    }

    function getReserves(
        address factory,
        address tokenA,
        address tokenB
    ) internal view returns (uint256 reserveA, uint256 reserveB) {
        address pool = pairFor(factory, tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1, ) = IExchange(pool).getReserves();
        (reserveA, reserveB) = tokenA == IExchange(pool).token0()
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
    }

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) internal pure returns (uint256 amountB) {
        require(amountA > 0, "INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "INSUFFICIENT_LIQUIDITY");
        amountB = amountA.mul(reserveB) / reserveA;
    }

    function getAmountsOut(
        address factory,
        uint256 amountIn,
        address[] memory path
    ) internal view returns (uint256[] memory amounts) {
        require(path.length >= 2, "INVALID_PATH");

        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint256 i; i < path.length - 1; i++) {
            amounts[i + 1] = estimatePos(
                factory,
                path[i],
                amounts[i],
                path[i + 1]
            );
        }
    }

    function getAmountsIn(
        address factory,
        uint256 amountOut,
        address[] memory path
    ) internal view returns (uint256[] memory amounts) {
        require(path.length >= 2, "INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[amounts.length - 1] = amountOut;

        for (uint256 i = path.length - 1; i > 0; i--) {
            amounts[i - 1] = estimateNeg(
                factory,
                path[i - 1],
                path[i],
                amounts[i]
            );
        }
    }

    function estimatePos(
        address factory,
        address inToken,
        uint256 inAmount,
        address outToken
    ) private view returns (uint256) {
        address exc = pairFor(factory, inToken, outToken);
        require(exc != address(0));

        uint256 outAmount = IExchange(exc).estimatePos(inToken, inAmount);
        require(outAmount != 0);

        return outAmount;
    }

    function estimateNeg(
        address factory,
        address inToken,
        address outToken,
        uint256 outAmount
    ) private view returns (uint256) {
        address exc = pairFor(factory, inToken, outToken);
        require(exc != address(0));

        uint256 inAmount = IExchange(exc).estimateNeg(outToken, outAmount);
        require(inAmount != uint256(-1));

        return inAmount;
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn.mul(999);
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");
        uint256 numerator = reserveIn.mul(amountOut).mul(1000);
        uint256 denominator = reserveOut.sub(amountOut).mul(999);
        amountIn = (numerator / denominator).add(1);
    }
}

contract V2RouterImpl {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public owner;
    address public nextOwner;
    address public factory;
    address public WETH;

    bool public entered;

    constructor() public {}

    function _initialize(
        address _factory,
        address _WETH
    ) public {
        require(factory == address(0));
        owner = msg.sender;
        factory = _factory;
        WETH = _WETH;
    }

    modifier nonReentrant() {
        require(!entered, "ReentrancyGuard: reentrant call");

        entered = true;

        _;

        entered = false;
    }

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "V2SwapRouter: EXPIRED");
        _;
    }

    function version() public pure returns (string memory) {
        return "V2SwapRouter20240715";
    }

    event ChangeNextOwner(address nextOwner);
    event ChangeOwner(address owner);

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

    function approvePair(address pair, address token0, address token1) public {
        require(msg.sender == factory);
        IERC20(token0).approve(pair, uint256(-1));
        IERC20(token1).approve(pair, uint256(-1));
    }

    function() external payable {
        assert(msg.sender == WETH);
    }

    //////////////////////////// SWAP ////////////////////////////
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

    function stepPos(
        address inToken,
        uint256 inAmount,
        address outToken,
        uint256 outAmount
    ) private {
        address exc = SwapLibrary.pairFor(factory, inToken, outToken);

        uint256 result = IExchange(exc).exchangePos(inToken, inAmount);

        require(result == outAmount, "Router: result != outAmount");
    }

    function stepNeg(
        address inToken,
        uint256 inAmount,
        address outToken,
        uint256 outAmount
    ) private {
        address exc = SwapLibrary.pairFor(factory, inToken, outToken);

        uint256 result = IExchange(exc).exchangeNeg(outToken, outAmount);
        require(result == inAmount, "Router: result != inAmount");
    }

    function _swapPos(
        uint256[] memory amounts,
        address[] memory path
    ) private nonReentrant {
        uint256 n = path.length;

        for (uint256 i = 0; i < n - 1; i++) {
            stepPos(path[i], amounts[i], path[i + 1], amounts[i + 1]);
        }

        emit ExchangePos(path[0], amounts[0], path[n - 1], amounts[n - 1]);
    }

    function _swapNeg(
        uint256[] memory amounts,
        address[] memory path
    ) private nonReentrant {
        uint256 n = path.length;

        for (uint256 i = 0; i < n - 1; i++) {
            stepNeg(path[i], amounts[i], path[i + 1], amounts[i + 1]);
        }

        emit ExchangeNeg(path[0], amounts[0], path[n - 1], amounts[n - 1]);
    }

    function sendTokenToExchange(address token, uint256 amount) public {
        require(IFactory(factory).poolExist(msg.sender));

        uint256 userBefore = IERC20(token).balanceOf(msg.sender);
        uint256 thisBefore = IERC20(token).balanceOf(address(this));

        require(IERC20(token).transfer(msg.sender, amount), "transfer failed");

        uint256 userAfter = IERC20(token).balanceOf(msg.sender);
        uint256 thisAfter = IERC20(token).balanceOf(address(this));

        require(
            userAfter == userBefore.add(amount),
            "Router: userBalance diff"
        );
        require(
            thisAfter.add(amount) == thisBefore,
            "Router: thisBalance diff"
        );
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        uint256 length = path.length;
        amounts = SwapLibrary.getAmountsOut(factory, amountIn, path);
        require(
            amounts[length - 1] >= amountOutMin,
            "Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        IERC20(path[0]).safeTransferFrom(
            msg.sender,
            address(this),
            amounts[0]
        );
        _swapPos(amounts, path);
        IERC20(path[length - 1]).safeTransfer(to, amounts[length - 1]);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        uint256 length = path.length;
        amounts = SwapLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, "Router: EXCESSIVE_INPUT_AMOUNT");
        IERC20(path[0]).safeTransferFrom(
            msg.sender,
            address(this),
            amounts[0]
        );
        _swapNeg(amounts, path);
        IERC20(path[length - 1]).safeTransfer(to, amounts[length - 1]);
    }

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) returns (uint256[] memory amounts) {
        uint256 length = path.length;
        require(path[0] == WETH, "Router: INVALID_PATH");
        amounts = SwapLibrary.getAmountsOut(factory, msg.value, path);
        require(
            amounts[length - 1] >= amountOutMin,
            "Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        IWETH(WETH).deposit.value(amounts[0])();
        _swapPos(amounts, path);
        IERC20(path[length - 1]).safeTransfer(to, amounts[length - 1]);
    }

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        uint256 length = path.length;
        require(path[length - 1] == WETH, "Router: INVALID_PATH");
        amounts = SwapLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, "Router: EXCESSIVE_INPUT_AMOUNT");
        IERC20(path[0]).safeTransferFrom(
            msg.sender,
            address(this),
            amounts[0]
        );
        _swapNeg(amounts, path);
        IWETH(WETH).withdraw(amounts[length - 1]);
        (bool success, ) = to.call.value(amounts[length - 1])("");
        require(success, "Router: ETH transfer failed");
    }

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        uint256 length = path.length;
        require(path[length - 1] == WETH, "Router: INVALID_PATH");
        amounts = SwapLibrary.getAmountsOut(factory, amountIn, path);
        require(
            amounts[length - 1] >= amountOutMin,
            "Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        IERC20(path[0]).safeTransferFrom(
            msg.sender,
            address(this),
            amounts[0]
        );
        _swapPos(amounts, path);
        IWETH(WETH).withdraw(amounts[length - 1]);
        (bool success, ) = to.call.value(amounts[length - 1])("");
        require(success, "Router: ETH transfer failed");
    }

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) returns (uint256[] memory amounts) {
        uint256 length = path.length;
        uint256 amountETH = msg.value;
        require(path[0] == WETH, "Router: INVALID_PATH");
        amounts = SwapLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountETH, "Router: EXCESSIVE_INPUT_AMOUNT");
        IWETH(WETH).deposit.value(amounts[0])();
        _swapNeg(amounts, path);
        IERC20(path[length - 1]).safeTransfer(to, amounts[length - 1]);
        if (amountETH > amounts[0]) {
            (bool success, ) = msg.sender.call.value(
                amountETH.sub(amounts[0])
            )("");
            require(success, "Router: ETH transfer failed");
        }
    }

    //////////////////////////// LIQUIDITY ////////////////////////////
    function addLiquidity(
        address token0,
        address token1,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        ensure(deadline)
        nonReentrant
        returns (uint256 amount0, uint256 amount1, uint256 liquidity)
    {
        address pair = IFactory(factory).tokenToPool(token0, token1);

        SafeERC20.safeTransferFrom(
            IERC20(token0),
            msg.sender,
            address(this),
            amountADesired
        );
        SafeERC20.safeTransferFrom(
            IERC20(token1),
            msg.sender,
            address(this),
            amountBDesired
        );

        (amount0, amount1, liquidity) = IExchange(pair)
            .addTokenLiquidityWithLimit(
                amountADesired,
                amountBDesired,
                amountAMin,
                amountBMin,
                to
            );
        if (amount0 < amountADesired)
            IERC20(token0).safeTransfer(
                msg.sender,
                amountADesired.sub(amount0)
            );
        if (amount1 < amountBDesired)
            IERC20(token1).safeTransfer(
                msg.sender,
                amountBDesired.sub(amount1)
            );
    }

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        ensure(deadline)
        nonReentrant
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity)
    {
        address pair = IFactory(factory).tokenToPool(WETH, token);
        IWETH(WETH).deposit.value(msg.value)();
        IERC20(token).safeTransferFrom(
            msg.sender,
            address(this),
            amountTokenDesired
        );
        if (WETH < token) {
            (amountETH, amountToken, liquidity) = IExchange(pair)
                .addTokenLiquidityWithLimit(
                    msg.value,
                    amountTokenDesired,
                    amountETHMin,
                    amountTokenMin,
                    to
                );
        } else {
            (amountToken, amountETH, liquidity) = IExchange(pair)
            .addTokenLiquidityWithLimit(
                amountTokenDesired,
                msg.value,
                amountTokenMin,
                amountETHMin,
                to
            );
        }
        if (amountETH < msg.value) {
            IWETH(WETH).withdraw(msg.value.sub(amountETH));

            (bool success, ) = msg.sender.call.value(
                msg.value.sub(amountETH)
            )("");
            require(success, "Router: ETH transfer failed");
        }
        if (amountToken < amountTokenDesired)
            IERC20(token).safeTransfer(
                msg.sender,
                amountTokenDesired.sub(amountToken)
            );
    }

    function removeLiquidity(
        address token0,
        address token1,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        public
        ensure(deadline)
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        address pair = IFactory(factory).tokenToPool(token0, token1);
        IERC20(pair).safeTransferFrom(msg.sender, address(this), liquidity);
        (amount0, amount1) = IExchange(pair).removeLiquidityWithLimit(
            liquidity,
            amountAMin,
            amountBMin,
            to
        );
    }

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        public
        ensure(deadline)
        nonReentrant
        returns (uint256 amountToken, uint256 amountETH)
    {

        address pair = IFactory(factory).tokenToPool(WETH, token);
        IERC20(pair).safeTransferFrom(msg.sender, address(this), liquidity);
        if (WETH < token) {
            (amountETH, amountToken) = IExchange(pair).removeLiquidityWithLimit(
                liquidity,
                amountETHMin,
                amountTokenMin,
                address(this)
            );
        } else {
            (amountToken, amountETH) = IExchange(pair).removeLiquidityWithLimit(
                liquidity,
                amountTokenMin,
                amountETHMin,
                address(this)
            );
        }
        IERC20(token).safeTransfer(to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        (bool success, ) = to.call.value(amountETH)("");
        require(success, "Router: ETH transfer failed");
    }

    function removeLiquidityWithPermit(
        address token0,
        address token1,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amount0, uint256 amount1) {
        address pair = IFactory(factory).tokenToPool(token0, token1);
        uint256 value = approveMax ? uint256(-1) : liquidity;

        if (IERC20(pair).allowance(msg.sender, address(this)) < value) {
            IExchange(pair).permit(
                msg.sender,
                address(this),
                value,
                deadline,
                v,
                r,
                s
            );
        }
        (amount0, amount1) = removeLiquidity(
            token0,
            token1,
            liquidity,
            amountAMin,
            amountBMin,
            to,
            deadline
        );
    }

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH) {
        address pair = IFactory(factory).tokenToPool(WETH, token);
        uint256 value = approveMax ? uint256(-1) : liquidity;

        if (IERC20(pair).allowance(msg.sender, address(this)) < value) {
            IExchange(pair).permit(
                msg.sender,
                address(this),
                value,
                deadline,
                v,
                r,
                s
            );
        }
        (amountToken, amountETH) = removeLiquidityETH(
            token,
            liquidity,
            amountTokenMin,
            amountETHMin,
            to,
            deadline
        );
    }

    function claimReward(
        address pair,
        uint256 deadline
    ) external ensure(deadline) nonReentrant {
        require(IFactory(factory).poolExist(pair));
        IExchange(pair).claimReward(msg.sender);
    }

    function claimReward(
        address token0,
        address token1,
        uint256 deadline
    ) external ensure(deadline) nonReentrant {
        address pair = IFactory(factory).tokenToPool(token0, token1);
        IExchange(pair).claimReward(msg.sender);
    }

    function claimRewardList(
        address[] calldata pairs,
        uint256 deadline
    ) external ensure(deadline) nonReentrant {
        uint256 length = pairs.length;
        for (uint256 i = 0; i < length; i++) {
            require(IFactory(factory).poolExist(pairs[i]));
            IExchange(pairs[i]).claimReward(msg.sender);
        }
    }

    function quote(
        uint256 amount0,
        uint256 reserveA,
        uint256 reserveB
    ) public pure returns (uint256 amount1) {
        return SwapLibrary.quote(amount0, reserveA, reserveB);
    }

    function getAmountsOut(
        uint256 amountIn,
        address[] memory path
    ) public view returns (uint256[] memory amounts) {
        return SwapLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(
        uint256 amountOut,
        address[] memory path
    ) public view returns (uint256[] memory amounts) {
        return SwapLibrary.getAmountsIn(factory, amountOut, path);
    }

    /// @dev Deprecated
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        return SwapLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountIn) {
        return SwapLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }
}
