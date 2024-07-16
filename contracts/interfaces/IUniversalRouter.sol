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

interface IUniversalRouter {
    struct SwapParams {
        address to;
        address[] path;
        address[] pool;
        uint256 deadline;
    }

    function Owner() external view returns (address);
    function WETH() external view returns (address);
    function _setImplementation(address _newImp) external;
    function _setImplementationAndCall(address _newImp, bytes calldata data) external;
    function changeOwner(address newOwner) external;
    function entered() external view returns (bool);
    function estimator() external view returns (address);
    function getAmountsIn(
        uint256 amountOut,
        address[] calldata path,
        address[] calldata pool
    ) external view returns (uint256[] memory amounts);
    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path,
        address[] calldata pool
    ) external view returns (uint256[] memory amounts);
    function implementation() external view returns (address);
    function swapETHForExactTokens(
        uint256 amountOut,
        SwapParams calldata p
    ) external returns (uint256[] memory amounts);
    function swapExactETHForTokens(
        uint256 amountOutMin,
        SwapParams calldata p
    ) external returns (uint256[] memory amounts);
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        SwapParams calldata p
    ) external returns (uint256[] memory amounts);
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        SwapParams calldata p
    ) external returns (uint256[] memory amounts);
    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        SwapParams calldata p
    ) external returns (uint256[] memory amounts);
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        SwapParams calldata p
    ) external returns (uint256[] memory amounts);
    function v2Factory() external view returns (address);
    function v3Factory() external view returns (address);
    function v3Router() external view returns (address);
    function version() external pure returns (string memory);
}
