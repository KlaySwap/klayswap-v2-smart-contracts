// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {IERC20Detailed} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol';
import {IRewardsDistributor} from '@aave/periphery-v3/contracts/rewards/interfaces/IRewardsDistributor.sol';
import {IEmissionManager} from '@aave/periphery-v3/contracts/rewards/interfaces/IEmissionManager.sol';
import {RewardsDataTypes} from '@aave/periphery-v3/contracts/rewards/libraries/RewardsDataTypes.sol';
import {Ownable2Step} from './libraries/Ownable2Step.sol';
import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {DataTypes} from '@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol';
import {IEACAggregatorProxy} from '@aave/periphery-v3/contracts/misc/interfaces/IEACAggregatorProxy.sol';
import {ITransferStrategyBase} from '@aave/periphery-v3/contracts/rewards/interfaces/ITransferStrategyBase.sol';
import {SafeCast} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/SafeCast.sol';

/**
 * @title LendingRewardTokenManager
 * @notice receive rewardToken and send to deposited user
 * @author Ozys
 **/
contract LendingRewardTokenManager is Ownable2Step {
  using SafeCast for uint256;

  IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;
  // Manager of incentives
  address public immutable EMISSION_MANAGER;
  address public rewardToken;
  IEACAggregatorProxy public rewardOracle;
  ITransferStrategyBase public transferStrategy;

  uint256 public totalRewardPerSecond;
  mapping(address => uint256) public weight;
  uint256 public totalWeight;

  constructor(
    IPoolAddressesProvider _addressesProvider,
    address _emissionManager,
    address _rewardToken,
    ITransferStrategyBase _transferStrategy,
    IEACAggregatorProxy _rewardOracle,
    uint256 _totalRewardPerSecond
  ) {
    ADDRESSES_PROVIDER = _addressesProvider;
    EMISSION_MANAGER = _emissionManager;
    rewardToken = _rewardToken;
    transferStrategy = _transferStrategy;
    rewardOracle = IEACAggregatorProxy(_rewardOracle);
    totalRewardPerSecond = _totalRewardPerSecond;

  }

  // after EMISSION_MANAGER.setEmissionAdmin(rewardToken, LendingRewardTokenManager)
  function initialize() external onlyOwner {
    IEmissionManager(EMISSION_MANAGER).setTransferStrategy(rewardToken, transferStrategy);
    IEmissionManager(EMISSION_MANAGER).setRewardOracle(rewardToken, rewardOracle);
  }

  function setTotalRewardPerSecond(uint256 _totalRewardPerSecond) external onlyOwner {
    totalRewardPerSecond = _totalRewardPerSecond;
    update();
  }

  function setTransferStrategy(address _transferStrategy) external onlyOwner {
    transferStrategy = ITransferStrategyBase(_transferStrategy);
    IEmissionManager(EMISSION_MANAGER).setTransferStrategy(rewardToken, transferStrategy);
  }

  function setRewardOracle(address _rewardOracle) external onlyOwner {
    rewardOracle = IEACAggregatorProxy(_rewardOracle);
    IEmissionManager(EMISSION_MANAGER).setRewardOracle(rewardToken, rewardOracle);
  }

  function getEmissionManager() external view returns (address) {
    return EMISSION_MANAGER;
  }

  // asset : reserve 원본 토큰 (aToken X)
  function manage(address _asset, uint256 _weight, bool _withUpdate) external onlyOwner {
    // add
    if (weight[_asset] == 0) {
      require(_weight != 0);

      weight[_asset] = _weight;
      totalWeight += _weight;
    } else {
      require(_withUpdate);
      totalWeight -= weight[_asset];
      weight[_asset] = _weight;
      totalWeight += _weight;
    }

    if (_withUpdate) update();
  }

  function update() public onlyOwner {
    require(totalWeight > 0, "Zero totalWeight");
    IPool pool = IPool(ADDRESSES_PROVIDER.getPool());
    address[] memory reserves = pool.getReservesList();
    RewardsDataTypes.RewardsConfigInput[] memory config = new RewardsDataTypes.RewardsConfigInput[](reserves.length);

    for (uint256 i = 0; i < reserves.length; i++) {
      DataTypes.ReserveData memory reserveData = pool.getReserveData(reserves[i]);
      address _asset = reserveData.aTokenAddress;

      RewardsDataTypes.RewardsConfigInput memory v = RewardsDataTypes.RewardsConfigInput({
        emissionPerSecond: totalWeight > 0 ? uint88(totalRewardPerSecond * weight[reserves[i]] / totalWeight) : 0,
        totalSupply: IERC20Detailed(_asset).totalSupply(),
        distributionEnd: type(uint32).max,
        asset: _asset,
        reward: rewardToken,
        transferStrategy: ITransferStrategyBase(transferStrategy),
        rewardOracle: IEACAggregatorProxy(rewardOracle)
      });
      config[i] = v;
    }

    IEmissionManager(EMISSION_MANAGER).configureAssets(config);
  }

  function getRewardStatus() external view returns (address[] memory reserves, uint256[] memory weights) {
    IPool pool = IPool(ADDRESSES_PROVIDER.getPool());
    reserves = pool.getReservesList();
    weights = new uint256[](reserves.length);
    for (uint256 i = 0; i < reserves.length; i++) {
      weights[i] = weight[reserves[i]];
    }
  }

  function execute(address _to, uint256 _value, bytes calldata _data) external onlyOwner {
    (bool result,) = _to.call{value : _value}(_data);
    if (!result) {
        revert();
    }
  }
}
