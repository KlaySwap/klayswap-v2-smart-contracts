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

contract Exchange {
    // ======== ERC20 =========
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(
        address indexed holder,
        address indexed spender,
        uint256 amount
    );

    string public name = "Kaia KLAYswap LP";
    string public constant symbol = "Kaia-KLAYswap-V2-LP";
    uint8 public decimals = 18;

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public factory;
    address public rewardToken;
    address public router;
    address public WETH;
    address public token0;
    address public token1;

    uint112 public reserve0;
    uint112 public reserve1;
    uint32 public blockTimestampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast;

    uint256 public fee;
    uint256 public mining;
    uint256 public lastMined;
    uint256 public miningIndex;

    mapping(address => uint256) public userLastIndex;
    mapping(address => uint256) public userRewardSum;

    bool public entered;

    /////////////////////// Uniswap V2 Compatible ///////////////////////
    bytes32 public DOMAIN_SEPARATOR;
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    mapping(address => uint256) public nonces;
    /////////////////////////////////////////////////////////////////////

    // ======== Construction & Init ========
    constructor(address _token0, address _token1, uint256 _fee) public {
        factory = msg.sender;

        if (_token0 != address(0)) {
            rewardToken = IFactory(msg.sender).rewardToken();
            router = IFactory(msg.sender).router();
            WETH = IFactory(msg.sender).WETH();
        }

        require(_token0 != _token1);

        token0 = _token0;
        token1 = _token1;

        require(_fee <= 100);
        fee = _fee;
    }

    function() external payable {
        address impl = IFactory(factory).getExchangeImplementation();
        require(impl != address(0));
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize)
            let result := delegatecall(gas, impl, ptr, calldatasize, 0, 0)
            let size := returndatasize
            returndatacopy(ptr, 0, size)

            switch result
            case 0 {
                revert(ptr, size)
            }
            default {
                return(ptr, size)
            }
        }
    }
}
