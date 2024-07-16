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

interface IGovernor {
    function proposals(
        uint256
    )
        external
        view
        returns (
            uint256 id,
            address proposer,
            uint256 eta,
            address target,
            string memory signature,
            bytes memory callData,
            uint256 startBlock,
            uint256 endBlock,
            uint256 forVotes,
            uint256 againstVotes,
            bool canceled,
            bool executed
        );
    function votingPeriod() external view returns (uint256);
    function changepQuorumVotesRate(uint256 _id, uint256 _rate) external;
    function delistingPeriod() external view returns (uint256);
    function vRewardToken() external view returns (address);
    function _setVotingPeriod(uint256 newVotingPeriod) external;
    function castVote(uint256 proposalId, bool support) external;
    function queuedPids(bytes32) external view returns (uint256);
    function latestProposalIds(address) external view returns (uint256);
    function results(
        uint256
    ) external view returns (uint256 executedBlock, bool succeeded);
    function _setVotingDelay(uint256 newVotingDelay) external;
    function MIN_VOTING_PERIOD() external view returns (uint256);
    function _setProposalThresholdRate(
        uint256 newProposalThresholdRate
    ) external;
    function executed(uint256 transactionId, bool executionResult) external;
    function changeNextOwner(address _nextOwner) external;
    function MIN_QUORUM_VOTES_RATE() external view returns (uint256);
    function getActions(
        uint256 proposalId
    )
        external
        view
        returns (
            address target,
            string memory signature,
            bytes memory callData,
            uint256 eta
        );
    function votingDelay() external view returns (uint256);
    function state(uint256 proposalId) external view returns (uint8);
    function cancel(uint256 proposalId) external;
    function _setProposalFee(uint256 newProposalFee) external;
    function MAX_GRACE_PERIOD() external view returns (uint256);
    function MIN_PROPOSAL_THRESHOLD_RATE() external view returns (uint256);
    function delistingBlock(address) external view returns (uint256);
    function version() external pure returns (string memory);
    function policyAdmin() external view returns (address);
    function governance() external view returns (address);
    function proposeDelayDelistingTime(address token) external;
    function implementation() external view returns (address);
    function propose(
        address target,
        string calldata signature,
        bytes calldata callData,
        string calldata description
    ) external returns (uint256);
    function castVoteWithReason(
        uint256 proposalId,
        bool support,
        string calldata reason
    ) external;
    function MAX_PROPOSAL_THRESHOLD_RATE() external view returns (uint256);
    function changeOwner() external;
    function pids(uint256) external view returns (uint256);
    function nextOwner() external view returns (address);
    function setPolicyAdmin(address _policyAdmin) external;
    function _setImplementation(address _newImp, string calldata) external;
    function _setVerifier(
        address target,
        string calldata sig,
        address verifier
    ) external;
    function quorumVotesRate() external view returns (uint256);
    function canDelisting(address token) external view returns (bool);
    function MIN_GRACE_PERIOD() external view returns (uint256);
    function owner() external view returns (address);
    function MIN_DELISTING_PERIOD() external view returns (uint256);
    function getResult(
        uint256 proposalId
    ) external view returns (bool succeeded, uint256 executedBlock);
    function proposalThresholdRate() external view returns (uint256);
    function queueDelisting(address token, bool insert) external;
    function gracePeriod() external view returns (uint256);
    function _setDelistingPeriod(uint256 newDelistingPeriod) external;
    function MAX_VOTING_PERIOD() external view returns (uint256);
    function MAX_VOTING_DELAY() external view returns (uint256);
    function getProposalInfo(
        uint256 proposalId
    )
        external
        view
        returns (
            address proposer,
            uint256 eta,
            uint256 startBlock,
            uint256 endBlock,
            uint256 forVotes,
            uint256 againstVotes
        );
    function _setQuorumVotesRate(uint256 newQuorumVotesRate) external;
    function proposalFee() external view returns (uint256);
    function factory() external view returns (address);
    function pQuorumVotesRate(uint256) external view returns (uint256);
    function proposalCount() external view returns (uint256);
    function MAX_QUORUM_VOTES_RATE() external view returns (uint256);
    function queue(uint256 proposalId) external;
    function getReceipt(
        uint256 proposalId,
        address voter
    ) external view returns (bool hasVoted, bool support, uint256 votes);
    function delistingPids(address) external view returns (uint256);
    function verifiers(address, bytes32) external view returns (address);
    function MIN_VOTING_DELAY() external view returns (uint256);
    function RATE_DENOM() external view returns (uint256);
    function queuedTransactions(bytes32) external view returns (bool);
    function delayDelistingTime(address token) external;
    function _setGracePeriod(uint256 newGracePeriod) external;
}
