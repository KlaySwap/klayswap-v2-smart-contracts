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

interface ITreasuryImpl {
    function getDistributionImplementation() external view returns (address);
}

contract Distribution {
    // =================== treasury entries mapping for Distribution =======================
    mapping(uint256 => address) public targetEntries;
    uint256 public targetCount;

    // ===================      Index for Distribution      =======================
    address public token;
    uint256 public totalAmount;
    uint256 public blockAmount;
    uint256 public distributableBlock;
    uint256 public distributedAmount;

    mapping(address => uint256) public distributionRate;
    mapping(address => uint256) public lastDistributed;
    mapping(address => uint256) public distributionIndex;
    mapping(address => mapping(address => uint256)) public userLastIndex;
    mapping(address => mapping(address => uint256)) public userRewardSum;

    // ===================           Config                 =======================
    bool public entered = false;
    bool public isInitialized = false;
    address public treasury;
    address public operator;

    constructor(address _operator) public {
        treasury = msg.sender;
        operator = _operator;
    }

    function() external payable {
        address impl = ITreasuryImpl(treasury).getDistributionImplementation();
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
