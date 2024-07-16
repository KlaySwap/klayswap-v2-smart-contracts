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
import "./interfaces/IFactory.sol";
import "../gov/interfaces/IGovernance.sol";

contract RewardToken {
    using SafeMath for uint256;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(
        address indexed holder,
        address indexed spender,
        uint256 amount
    );

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public owner;
    address public nextOwner;

    uint256 public miningAmount;
    uint256 public halfLife;
    uint256 public minableBlock;
    uint256 public teamRatio;
    uint256 public blockAmount;
    uint256 public rewarded;
    uint256 public minableTime;

    address public teamWallet;
    uint256 public teamAward;

    bool public entered;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _miningAmount,
        uint256 _blockAmount,
        uint256 _halfLife,
        uint256 _minableTime,
        uint256 _teamRatio,
        uint256 _initialSupply
    ) public {
        owner = msg.sender;

        name = _name;
        symbol = _symbol;
        miningAmount = _miningAmount;
        blockAmount = _blockAmount;
        halfLife = _halfLife;
        minableTime = _minableTime;
        minableBlock = uint256(-1);
        teamRatio = _teamRatio;

        totalSupply = totalSupply.add(_initialSupply);
        balanceOf[msg.sender] = _initialSupply;

        emit Transfer(address(0), msg.sender, _initialSupply);
    }

    modifier nonReentrant() {
        require(!entered, "ReentrancyGuard: reentrant call");

        entered = true;

        _;

        entered = false;
    }

    // ======== ERC20 =========
    function transfer(address _to, uint256 _value) public returns (bool) {
        balanceOf[msg.sender] = balanceOf[msg.sender].sub(_value);
        balanceOf[_to] = balanceOf[_to].add(_value);

        emit Transfer(msg.sender, _to, _value);

        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public returns (bool) {
        balanceOf[_from] = balanceOf[_from].sub(_value);
        balanceOf[_to] = balanceOf[_to].add(_value);
        allowance[_from][msg.sender] = allowance[_from][msg.sender].sub(_value);

        emit Transfer(_from, _to, _value);

        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        require(_spender != address(0));

        allowance[msg.sender][_spender] = _value;

        emit Approval(msg.sender, _spender, _value);

        return true;
    }

    function burn(uint256 amount) public {
        address user = msg.sender;
        require(balanceOf[user] >= amount);

        balanceOf[user] = balanceOf[user].sub(amount);
        totalSupply = totalSupply.sub(amount);

        emit Transfer(user, address(0), amount);
    }

    // ======== Administration ========

    event ChangeNextOwner(address nextOwner);
    event ChangeOwner(address owner);
    event ChangeTeamWallet(address _teamWallet);
    event ClaimTeamAward(uint256 award, uint256 totalAward);
    event SetMinableBlock(uint256 startTime, uint256 newMinableBlock);

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

    function changeTeamWallet(address _teamWallet) public {
        require(msg.sender == owner);
        teamWallet = _teamWallet;

        emit ChangeTeamWallet(_teamWallet);
    }

    function claimTeamAward() public {
        require(teamWallet != address(0));

        uint256 nowBlock = block.number;

        if (nowBlock >= minableBlock) {
            uint256 totalAward = mined().mul(teamRatio).div(
                uint256(100).sub(teamRatio)
            );

            if (totalAward > teamAward) {
                uint256 award = totalAward - teamAward;

                balanceOf[teamWallet] = balanceOf[teamWallet].add(award);
                totalSupply = totalSupply.add(award);

                emit ClaimTeamAward(award, totalAward);
                emit Transfer(address(0), teamWallet, award);

                teamAward = totalAward;
            }
        }
    }

    function setMinableBlock() public {
        require(block.timestamp >= minableTime, "Did not reached minableTime");
        require(minableBlock == uint256(-1), "MinableBlock already set.");

        minableBlock = block.number;

        emit SetMinableBlock(block.timestamp, minableBlock);
    }

    function newMined() public view returns (uint256 res) {
        return mined();
    }

    function mined() public view returns (uint256 res) {
        uint256 nowBlock = block.number;
        uint256 startBlock = minableBlock;
        if (nowBlock < startBlock) return 0;

        uint256 blockAmt = blockAmount.mul(uint256(100).sub(teamRatio)).div(
            100
        );

        uint256 level = ((nowBlock.sub(startBlock)).add(1)).div(halfLife);

        for (uint256 i = 0; i < level; i++) {
            if (startBlock.add(halfLife) > nowBlock) break;

            res = res.add(blockAmt.mul(halfLife));
            startBlock = startBlock.add(halfLife);
            blockAmt = blockAmt.div(2);
        }

        res = res.add(blockAmt.mul((nowBlock.sub(startBlock)).add(1)));
        if (miningAmount != 0) res = res > miningAmount ? miningAmount : res;
    }

    function sendReward(address user, uint256 amount) public {
        require(
            msg.sender == owner ||
                IFactory(IGovernance(owner).factory()).poolExist(msg.sender)||
                IFactory(IGovernance(owner).v3Factory()).poolExist(msg.sender)
        );
        require(amount.add(rewarded) <= mined());

        rewarded = rewarded.add(amount);
        balanceOf[user] = balanceOf[user].add(amount);
        totalSupply = totalSupply.add(amount);

        emit Transfer(address(0), user, amount);
    }

    event RefixMining(
        uint256 blockNumber,
        uint256 newBlockAmount,
        uint256 newHalfLife
    );

    function refixMining(uint256 newBlockAmount, uint256 newHalfLife) public {
        require(msg.sender == owner);
        require(blockAmount != newBlockAmount);
        require(halfLife != newHalfLife);
        require(newHalfLife.mul(newBlockAmount) == halfLife.mul(blockAmount));

        uint256 nowBlock = block.number;
        uint256 newMinableBlock = nowBlock.sub(
            nowBlock.sub(minableBlock).mul(newHalfLife).div(halfLife)
        );

        minableBlock = newMinableBlock;
        blockAmount = newBlockAmount;
        halfLife = newHalfLife;

        emit RefixMining(block.number, newBlockAmount, newHalfLife);
    }

    function getCirculation()
        public
        view
        returns (uint256 blockNumber, uint256 nowCirculation)
    {
        blockNumber = block.number;
        nowCirculation = mined().mul(100).div(uint256(100).sub(teamRatio));
    }

    function() external payable {
        revert();
    }
}
