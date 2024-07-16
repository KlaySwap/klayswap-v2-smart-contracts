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

import "./Distribution.sol";
import "../libraries/SafeMath.sol";
import "../misc/IERC20.sol";
import "./interfaces/IDistribution.sol";

contract TreasuryImpl {
    using SafeMath for uint256;

    // =================== treasury entries mapping for Distribution =======================
    mapping(address => bool) public validOperator;
    mapping(address => address) public distributionOperator;
    mapping(address => mapping(address => address)) public distributions;
    mapping(address => mapping(uint256 => address)) public distributionEntries;
    mapping(address => uint256) public distributionCount;

    // ===================           Config                 =======================
    address public owner;
    address public nextOwner;
    address public policyAdmin;
    address payable public distributionImplementation;

    address public rewardToken;
    uint256 public fee;

    bool public entered = false;

    event ChangeNextOwner(address nextOwner);
    event ChangeOwner(address owner);
    event ChangeCreationFee(uint256 fee);
    event SetOperator(address operator, bool valid);

    event CreateDistribution(
        address distribution,
        address operator,
        address token,
        uint256 totalAmount,
        uint256 blockAmount,
        uint256 blockNumber,
        address[] targets,
        uint256[] rates
    );
    event RemoveDistribution(address distribution, address operator, address token);

    event Deposit(address operator, address token, uint256 amount);
    event RefixBlockAmount(
        address operator,
        address token,
        uint256 blockAmount
    );
    event RefixDistributionRate(
        address operator,
        address token,
        address[] targets,
        uint256[] rates
    );

    constructor() public {}

    function _initialize(
        address _owner,
        address payable _distributionImplementation,
        address _rewardToken,
        uint256 _fee
    ) public {
        require(rewardToken == address(0));
        owner = _owner;
        distributionImplementation = _distributionImplementation;
        rewardToken = _rewardToken;
        fee = _fee;
    }

    function _setDistributionImplementation(address payable _newDistributionImp) public onlyOwner {
        require(distributionImplementation != _newDistributionImp);

        distributionImplementation = _newDistributionImp;
    }
    function getDistributionImplementation() public view returns (address) {
        return distributionImplementation;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyOperator() {
        require(validOperator[msg.sender]);
        _;
    }

    modifier nonReentrant() {
        require(!entered, "ReentrancyGuard: reentrant call");

        entered = true;

        _;

        entered = false;
    }

    modifier onlyPolicyAdmin() {
        require(msg.sender == owner || msg.sender == policyAdmin);
        _;
    }

    function version() public pure returns (string memory) {
        return "V2TreasuryImpl20240528";
    }

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

    function changeCreationFee(uint256 _fee) public onlyOwner {
        fee = _fee;

        emit ChangeCreationFee(_fee);
    }

    function setPolicyAdmin(address _policyAdmin) public onlyOwner {
        policyAdmin = _policyAdmin;
    }

    function setOperator(
        address _operator,
        bool _valid
    ) public onlyPolicyAdmin {
        validOperator[_operator] = _valid;

        emit SetOperator(_operator, _valid);
    }

    function setValidOperatorList(
        address[] memory operators
    ) public onlyPolicyAdmin {
        for (uint256 i = 0; i < operators.length; i++) {
            validOperator[operators[i]] = true;

            emit SetOperator(operators[i], true);
        }
    }

    function createTokenDistribution(
        address token,
        uint256 amount,
        uint256 blockAmount,
        uint256 blockNumber,
        address[] memory targets,
        uint256[] memory rates
    ) public onlyOperator nonReentrant {
        require(IERC20(token).transferFrom(msg.sender, address(this), amount));

        create(
            msg.sender,
            token,
            amount,
            blockAmount,
            blockNumber,
            targets,
            rates
        );
    }

    function create(
        address operator,
        address token,
        uint256 amount,
        uint256 blockAmount,
        uint256 blockNumber,
        address[] memory targets,
        uint256[] memory rates
    ) private {
        require(distributions[operator][token] == address(0));

        require(targets.length <= 10);
        require(targets.length == rates.length);

        require(blockNumber >= block.number);
        require(amount != 0 && blockAmount != 0);

        if (fee != 0) {
            require(IERC20(rewardToken).transferFrom(operator, address(this), fee));
            IERC20(rewardToken).burn(fee);
        }

        address distribution = address(new Distribution(operator));

        IDistribution(distribution).init(
            token,
            blockAmount,
            blockNumber,
            targets,
            rates
        );
        distributions[operator][token] = distribution;
        distributionOperator[distribution] = operator;

        require(IERC20(token).approve(distribution, amount));
        IDistribution(distribution).depositToken(amount);

        for (uint256 i = 0; i < targets.length; i++) {
            address target = targets[i];

            uint256 index = distributionCount[target];

            distributionEntries[target][index] = distribution;
            distributionCount[target] = index + 1;
        }

        emit CreateDistribution(
            distribution,
            operator,
            token,
            amount,
            blockAmount,
            blockNumber,
            targets,
            rates
        );
    }

    function depositToken(
        address token,
        uint256 amount
    ) public onlyOperator nonReentrant {
        require(IERC20(token).transferFrom(msg.sender, address(this), amount));

        deposit(msg.sender, token, amount);
    }

    function deposit(address operator, address token, uint256 amount) private {
        address distribution = distributions[operator][token];
        require(distribution != address(0));

        require(IERC20(token).approve(distribution, amount));
        IDistribution(distribution).depositToken(amount);

        emit Deposit(operator, token, amount);
    }

    function refixBlockAmount(
        address token,
        uint256 blockAmount
    ) public onlyOperator nonReentrant {
        address distribution = distributions[msg.sender][token];
        require(distribution != address(0));
        require(blockAmount != 0);

        IDistribution(distribution).refixBlockAmount(blockAmount);

        emit RefixBlockAmount(msg.sender, token, blockAmount);
    }

    function refixDistributionRate(
        address token,
        address[] memory targets,
        uint256[] memory rates
    ) public onlyOperator nonReentrant {
        address distribution = distributions[msg.sender][token];
        require(distribution != address(0));

        require(targets.length <= 20);
        require(targets.length == rates.length);

        IDistribution(distribution).refixDistributionRate(targets, rates);

        uint256 i;
        uint256 j;

        for (i = 0; i < targets.length; i++) {
            address target = targets[i];

            bool exist = false;
            uint256 index = distributionCount[target];
            for (j = 0; j < index; j++) {
                if (distributionEntries[target][j] == distribution) {
                    exist = true;
                    break;
                }
            }

            if (!exist) {
                distributionEntries[target][index] = distribution;
                distributionCount[target] = index + 1;
            }
        }

        emit RefixDistributionRate(msg.sender, token, targets, rates);
    }

    function removeDistribution(
        address operator,
        address token
    ) public nonReentrant onlyOwner {
        address distribution = distributions[operator][token];
        require(distribution != address(0));

        uint256 endBlock = IDistribution(distribution).estimateEndBlock();
        if (endBlock.add(7 days) <= block.number) {
            IDistribution(distribution).removeDistribution();

            distributionOperator[distribution] = address(0);
            distributions[operator][token] = address(0);
            emit RemoveDistribution(distribution, operator, token);
        }
    }

    function claim(address target) public nonReentrant {
        _claim(msg.sender, target);
    }

    function claim(address user, address target) public nonReentrant {
        require(target == msg.sender);

        _claim(user, target);
    }

    function _claim(address user, address target) private {
        updateEntries(target);

        if (distributionCount[target] == 0) return;

        for (uint256 i = 0; i < distributionCount[target]; i++) {
            IDistribution(distributionEntries[target][i]).distribute(
                user,
                target
            );
        }
    }

    function updateEntries(address target) private {
        uint256 index = distributionCount[target];
        if (index == 0) return;

        address[] memory entries = new address[](index);
        uint256 count = 0;
        uint256 i;
        for (i = 0; i < index; i++) {
            address dis = distributionEntries[target][i];
            if (distributionOperator[dis] != address(0)) {
                entries[count] = dis;
                count = count + 1;
            }
        }

        for (i = 0; i < index; i++) {
            if (i < count) {
                distributionEntries[target][i] = entries[i];
            } else {
                distributionEntries[target][i] = address(0);
            }
        }

        distributionCount[target] = count;
    }

    function updateDistributionIndex(address target) public nonReentrant {
        if (distributionCount[target] == 0) return;

        for (uint256 i = 0; i < distributionCount[target]; i++) {
            IDistribution(distributionEntries[target][i])
                .updateDistributionIndex(target);
        }
    }

    function() external payable {
        revert();
    }
}
