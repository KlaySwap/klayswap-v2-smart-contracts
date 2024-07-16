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
import "../libraries/SafeMath.sol";
import "../misc/IERC20.sol";
import "../misc/IWETH.sol";
import "./interfaces/IExchange.sol";
import "./interfaces/IRouter.sol";

contract FactoryImpl {
    using SafeMath for uint256;

    // ======== Construction & Init ========
    address public owner;
    address public nextOwner;
    address payable public exchangeImplementation;
    address payable public WETH;
    address public rewardToken;
    address public router;
    uint256 public chainId;
    uint256 public createFee;

    // ======== Pool Info ========
    address[] public pools;
    mapping(address => bool) public poolExist;

    mapping(address => mapping(address => address)) public tokenToPool;

    // ======== Administration ========

    bool public entered;

    constructor() public {}

    function _initialize(
        address _owner,
        address payable _exchangeImplementation,
        address payable _rewardToken,
        address payable _WETH,
        uint256 _chainId
    ) public {
        require(owner == address(0));
        owner = _owner;
        rewardToken = _rewardToken;
        exchangeImplementation = _exchangeImplementation;

        WETH = _WETH;
        chainId = _chainId;
    }

    function _setExchangeImplementation(address payable _newExImp) public {
        require(msg.sender == owner);
        require(exchangeImplementation != _newExImp);
        exchangeImplementation = _newExImp;
    }

    function getExchangeImplementation() public view returns (address) {
        return exchangeImplementation;
    }

    function version() public pure returns (string memory) {
        return "V2FactoryImpl20240528";
    }

    modifier nonReentrant() {
        require(!entered, "ReentrancyGuard: reentrant call");

        entered = true;

        _;

        entered = false;
    }

    event ChangeNextOwner(address nextOwner);
    event ChangeOwner(address owner);
    event SetRouter(address router);

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

    function changePoolFee(address token0, address token1, uint256 fee) public {
        require(msg.sender == owner);

        require(fee >= 5 && fee <= 100);

        address exc = tokenToPool[token0][token1];
        require(exc != address(0));

        IExchange(exc).changeFee(fee);
    }

    function setRouter(address _router) public {
        require(msg.sender == owner);
        router = _router;

        emit SetRouter(_router);
    }
    // ======== Create Pool ========

    event CreatePool(
        address token0,
        uint256 amount0,
        address token1,
        uint256 amount1,
        uint256 fee,
        address exchange,
        uint256 exid
    );

    function createPool(
        address token0,
        uint256 amount0,
        address token1,
        uint256 amount1,
        uint256 fee,
        bool isETH
    ) private {
        require(token0 != token1);
        require(amount0 != 0 && amount1 != 0);

        require(
            tokenToPool[token0][token1] == address(0),
            "Pool already exists"
        );
        require(token0 != address(0));
        require(fee >= 5 && fee <= 100);

        Exchange exc = new Exchange(token0, token1, fee);

        poolExist[address(exc)] = true;
        IExchange(address(exc)).initPool();
        pools.push(address(exc));

        tokenToPool[token0][token1] = address(exc);
        tokenToPool[token1][token0] = address(exc);

        if (!isETH || token0 != WETH) {
            IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        }
        if (!isETH || token1 != WETH) {
            IERC20(token1).transferFrom(msg.sender, address(this), amount1);
        }

        IERC20(token0).approve(address(exc), amount0);
        IERC20(token1).approve(address(exc), amount1);

        IExchange(address(exc)).addTokenLiquidityWithLimit(
            amount0,
            amount1,
            1,
            1,
            msg.sender
        );
        IRouter(router).approvePair(address(exc), token0, token1);

        emit CreatePool(
            token0,
            amount0,
            token1,
            amount1,
            fee,
            address(exc),
            pools.length - 1
        );
    }

    function createETHPool(
        address token,
        uint256 amount,
        uint256 fee
    ) public payable nonReentrant {
        uint256 amountWETH = msg.value;
        IWETH(WETH).deposit.value(msg.value)();
        (WETH < token) ?
            createPool(WETH, amountWETH, token, amount, fee, true) :
            createPool(token, amount, WETH, amountWETH, fee, true);
    }

    function createTokenPool(
        address token0,
        uint256 amount0,
        address token1,
        uint256 amount1,
        uint256 fee
    ) public nonReentrant {
        (token0 < token1) ?
            createPool(token0, amount0, token1, amount1, fee, false) :
            createPool(token1, amount1, token0, amount0, fee, false);
    }

    // ======== API ========

    function getPoolCount() public view returns (uint256) {
        return pools.length;
    }

    function getPoolAddress(uint256 idx) public view returns (address) {
        require(idx < pools.length);
        return pools[idx];
    }

    // ======== For Uniswap Compatible ========

    function getPair(
        address tokenA,
        address tokenB
    ) public view returns (address pair) {
        return tokenToPool[tokenA][tokenB];
    }

    function allPairsLength() external view returns (uint256) {
        return getPoolCount();
    }

    function allPairs(uint256 idx) external view returns (address pair) {
        pair = getPoolAddress(idx);
    }

    function() external payable {
        revert();
    }
}
