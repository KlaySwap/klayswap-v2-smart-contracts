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

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IDistribution {
    function estimateEndBlock() external view returns (uint256);
    function totalAmount() external view returns (uint256);
    function blockAmount() external view returns (uint256);
    function distributableBlock() external view returns (uint256);
    function distribution() external view returns (uint256);
    function targetEntries(uint256) external view returns (address);
    function targetCount() external view returns (uint256);
    function distributionRate(address) external view returns (uint256);
}

interface ITreasury {
    function fee() external view returns (uint256);
    function validOperator(address) external view returns (bool);
    function distributions(address, address) external view returns (address);
    function createETHDistribution(
        uint256,
        uint256,
        address[] calldata,
        uint256[] calldata
    ) external payable;
    function createTokenDistribution(
        address,
        uint256,
        uint256,
        uint256,
        address[] calldata,
        uint256[] calldata
    ) external;
    function depositETH() external payable;
    function depositToken(address, uint256) external;
    function refixBlockAmount(address, uint256) external;
    function refixDistributionRate(
        address,
        address[] calldata,
        uint256[] calldata
    ) external;
}

interface IFactory {
    function poolExist(address) external view returns (bool);
}

contract AirdropOperator {
    address public constant treasury =
        0x6550302E095E10c50c695C7cdAAe380e181DD74E;
    address public constant factory =
        0xB2AD0f20D54177916721c6B6466bce1eB1a56eef;
    address public constant rewardToken = 0xC6a2Ad8cC6e4A7E08FC37cC5954be07d499E7654;

    address public owner;
    address public nextOwner;
    address public token;
    address public lp;

    constructor(address _token, address _lp) public {
        owner = msg.sender;

        token = _token;
        require(IERC20(token).decimals() != 0);

        lp = _lp;
        require(IFactory(factory).poolExist(lp));
    }

    function version() external pure returns (string memory) {
        return "AirdropOperator20220415";
    }

    function() external payable {
        revert();
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    event ChangeNextOwner(address nextOwner);
    event ChangeOwner(address owner);

    function changeNextOwner(address _nextOwner) public onlyOwner {
        nextOwner = _nextOwner;

        emit ChangeNextOwner(_nextOwner);
    }

    function changeOwner() public {
        require(msg.sender == nextOwner);

        owner = nextOwner;
        nextOwner = address(0);

        emit ChangeOwner(owner);
    }

    function withdraw(address tokenAddr) public onlyOwner {
        uint256 balance = 0;
        if (tokenAddr == address(0)) {
            balance = (address(this)).balance;
            if (balance > 0) {
                (bool res, ) = owner.call.value(balance)("");
                require(res);
            }
        } else {
            balance = IERC20(tokenAddr).balanceOf(address(this));
            if (balance > 0) {
                require(IERC20(tokenAddr).transfer(owner, balance));
            }
        }
    }

    // ====================== Stat ====================================

    function getAirdropStat()
        public
        view
        returns (
            address distributionContract, // airdrop distribution contract address
            uint256 totalAmount, // Total amount of tokens to be distributed
            uint256 blockAmount, // Amount of tokens to be distributed per block
            uint256 distributableBlock, // Block number to airdrop start
            uint256 endBlock, // Block number to airdrop end
            uint256 distributed, // Amount of tokens distributed
            uint256 remain, // amount remaining in the contract
            uint256 targetCount, // airdrop target LP count
            address[] memory targets, // airdrop target LP list
            uint256[] memory rates // airdrop target lp rate list
        )
    {
        distributionContract = ITreasury(treasury).distributions(
            address(this),
            token
        );

        IDistribution dis = IDistribution(distributionContract);
        totalAmount = dis.totalAmount();
        blockAmount = dis.blockAmount();
        distributableBlock = dis.distributableBlock();
        endBlock = dis.estimateEndBlock();
        distributed = dis.distribution();

        remain = IERC20(token).balanceOf(distributionContract);

        targetCount = dis.targetCount();
        targets = new address[](targetCount);
        rates = new uint256[](targetCount);

        for (uint256 i = 0; i < targetCount; i++) {
            targets[i] = dis.targetEntries(i);
            rates[i] = dis.distributionRate(targets[i]);
        }
    }

    // ===================== Airdrop method ===========================
    ///@param totalAmount : Total amount of tokens to be distributed
    ///@param blockAmount : Amount of tokens to be distributed per block
    ///@param startBlock  : Block number to airdrop start
    function createDistribution(
        uint256 totalAmount,
        uint256 blockAmount,
        uint256 startBlock
    ) public onlyOwner {
        ITreasury Treasury = ITreasury(treasury);

        require(Treasury.validOperator(address(this)));
        require(Treasury.distributions(address(this), token) == address(0));
        require(startBlock >= block.number);

        address[] memory targets = new address[](1);
        targets[0] = lp;

        uint256[] memory rates = new uint256[](1);
        rates[0] = 100;

        if (Treasury.fee() > 0) {
            require(IERC20(rewardToken).balanceOf(address(this)) >= Treasury.fee());
            require(IERC20(rewardToken).approve(treasury, Treasury.fee()));
        }

        require(IERC20(token).balanceOf(address(this)) >= totalAmount);
        require(IERC20(token).approve(treasury, totalAmount));
        Treasury.createTokenDistribution(
            token,
            totalAmount,
            blockAmount,
            startBlock,
            targets,
            rates
        );
    }

    // Airdrop token deposit
    ///@param amount : Amount of airdrop token to deposit
    function deposit(uint256 amount) public onlyOwner {
        ITreasury Treasury = ITreasury(treasury);

        require(Treasury.validOperator(address(this)));
        require(Treasury.distributions(address(this), token) != address(0));
        require(amount != 0);

        require(IERC20(token).balanceOf(address(this)) >= amount);
        require(IERC20(token).approve(treasury, amount));
        Treasury.depositToken(token, amount);
    }

    // Airdrop amount per block modification function
    // The function is applied immediately from the called block
    ///@param blockAmount : airdrop block amount to change
    function refixBlockAmount(uint256 blockAmount) public onlyOwner {
        ITreasury Treasury = ITreasury(treasury);

        require(Treasury.validOperator(address(this)));
        require(Treasury.distributions(address(this), token) != address(0));
        require(blockAmount != 0);

        Treasury.refixBlockAmount(token, blockAmount);
    }
}
