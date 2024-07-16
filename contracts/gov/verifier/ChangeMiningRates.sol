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

import "../interfaces/IGovernor.sol";
import "../interfaces/IGovernance.sol";

contract ChangeMiningRates {
    address public governor;
    address public governance;
    bytes32 public CHANGE_MINING_RATES =
        keccak256(
            abi.encodePacked("changeMiningRates(uint256,uint256,uint256,uint256)")
        );

    constructor(address _governor) public {
        governor = _governor;
        governance = IGovernor(_governor).governance();
    }

    function version() public pure returns (string memory) {
        return "ChangeMiningRatesVerifer20220322";
    }

    function verify(
        address target,
        string memory signature,
        bytes memory callData
    ) public view returns (bool) {
        require(target == governance);
        require(keccak256(abi.encodePacked(signature)) == CHANGE_MINING_RATES);

        (
            uint256 singlePoolRate,
            uint256 pairPoolRate,
            uint256 vRewardTokenRate,
            uint256 treasuryRate
        ) = parsingData(callData);

        require(singlePoolRate <= 10000);
        require(pairPoolRate <= 10000);
        require(vRewardTokenRate <= 10000);
        require(treasuryRate <= 10000);

        require(
            add256(add256(add256(singlePoolRate, pairPoolRate), vRewardTokenRate), treasuryRate) == 10000
        );

        require(
            singlePoolRate != IGovernance(governance).singlePoolMiningRate() ||
            vRewardTokenRate != IGovernance(governance).vRewardTokenMiningRate() ||
            treasuryRate != IGovernance(governance).treasuryMiningRate()
        );

        return true;
    }

    function parsingData(
        bytes memory callData
    )
        internal
        pure
        returns (
            uint256 singlePoolRate,
            uint256 pairPoolRate,
            uint256 vRewardTokenRate,
            uint256 treasuryRate
        )
    {
        require(callData.length == 128);

        assembly {
            singlePoolRate := mload(add(callData, 32))
            pairPoolRate := mload(add(callData, 64))
            vRewardTokenRate := mload(add(callData, 96))
            treasuryRate := mload(add(callData, 128))
        }
    }

    function add256(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "addition overflow");
        return c;
    }
}
