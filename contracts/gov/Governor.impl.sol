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

import "../misc/IERC20.sol";
import "./interfaces/IVotingRewardToken.sol";
import "./interfaces/IGovernance.sol";
import "./interfaces/IVerifier.sol";

contract GovernorImpl {

    ////////////////////////// CONSTANT //////////////////////////
    /// @notice The denominator of rate params
    uint256 public constant RATE_DENOM = 10000;

    /// @notice The minimum setable proposal threshold
    uint256 public constant MIN_PROPOSAL_THRESHOLD_RATE = 1;

    /// @notice The maximum setable proposal threshold
    uint256 public constant MAX_PROPOSAL_THRESHOLD_RATE = 1000;

    /// @notice The min setable voting delay
    uint256 public constant MIN_QUORUM_VOTES_RATE = 100;

    /// @notice The max setable voting delay
    uint256 public constant MAX_QUORUM_VOTES_RATE = 10000;

    /// @notice The minimum setable voting period
    uint256 public constant MIN_VOTING_PERIOD = 1 days;

    /// @notice The max setable voting period
    uint256 public constant MAX_VOTING_PERIOD = 7 days;

    /// @notice The min setable voting delay
    uint256 public constant MIN_VOTING_DELAY = 1;

    /// @notice The max setable voting delay
    uint256 public constant MAX_VOTING_DELAY = 7 days;

    /// @notice The minimum grace period
    uint256 public constant MIN_GRACE_PERIOD = 3 days;

    /// @notice The maximum grace period
    uint256 public constant MAX_GRACE_PERIOD = 365 days;

    struct Proposal {
        /// @notice Unique id for looking up a proposal
        uint256 id;
        /// @notice Creator of the proposal
        address proposer;
        /// @notice The timestamp that the proposal will be available for execution, set once the vote succeeds
        uint256 eta;
        /// @notice The target addresses for calls to be made
        address target;
        /// @notice The function signatures to be called
        string signature;
        /// @notice The calldata to be passed to each call
        bytes callData;
        /// @notice The block at which voting begins: holders must delegate their votes prior to this block
        uint256 startBlock;
        /// @notice The block at which voting ends: votes must be cast prior to this block
        uint256 endBlock;
        /// @notice Current number of votes in favor of this proposal
        uint256 forVotes;
        /// @notice Current number of votes in opposition to this proposal
        uint256 againstVotes;
        /// @notice Flag marking whether the proposal has been canceled
        bool canceled;
        /// @notice Flag marking whether the proposal has been executed
        bool executed;
        /// @notice Receipts of ballots for the entire set of voters
        mapping(address => Receipt) receipts;
    }

    /// @notice Ballot receipt record for a voter
    struct Receipt {
        /// @notice Whether or not a vote has been cast
        bool hasVoted;
        /// @notice Whether or not the voter supports the proposal or abstains
        bool support;
        /// @notice The number of votes the voter had, which were cast
        uint256 votes;
    }

    struct Result {
        uint256 executedBlock;
        bool succeeded;
    }

    /// @notice Possible states that a proposal may be in
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }
    //////////////////////////////////////////////////////////////

    ////////////////////////// Ownable //////////////////////////
    address public owner;
    address public nextOwner;
    address public policyAdmin;
    /////////////////////////////////////////////////////////////

    ////////////////////////// Config //////////////////////////
    address public governance;
    address public factory;
    address public vRewardToken;

    mapping(bytes32 => bool) public queuedTransactions;
    mapping(bytes32 => uint256) public queuedPids;
    mapping(uint256 => uint256) public pids;

    mapping(address => mapping(bytes32 => address)) public verifiers;

    uint256 public proposalFee;

    /// @notice The rate of votes required in order for a voter to become a proposer
    uint256 public proposalThresholdRate;

    /// @notice The rate of votes in support of a proposal required in order for a quorum to be reached and for a vote to succeed
    uint256 public quorumVotesRate;

    /// @notice The duration of voting on a proposal, in blocks
    uint256 public votingPeriod;

    /// @notice The delay before voting on a proposal may take place, once proposed, in blocks
    uint256 public votingDelay;

    /// @notice The grace period of proposal execution
    uint256 public gracePeriod;

    /// @notice The total number of proposals
    uint256 public proposalCount;

    /// @notice The official record of all proposals ever proposed
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => Result) public results;

    /// @notice The latest proposal for each proposer
    mapping(address => uint256) public latestProposalIds;
    ////////////////////////// Config //////////////////////////

    mapping(uint256 => uint256) public pQuorumVotesRate;

    constructor() public {}

    function _initialize(
        address _owner,
        address _policyAdmin,
        address _governance,
        uint256 _proposalFee,
        uint256 _proposalThresholdRate,
        uint256 _quorumVotesRate,
        uint256 _votingPeriod,
        uint256 _votingDelay,
        uint256 _gracePeriod
    ) public {
        require(owner == address(0));
        owner = _owner;
        policyAdmin = _policyAdmin;

        governance = _governance;
        if (governance != address(0)) {
            IGovernance gov = IGovernance(governance);

            factory = gov.factory();
            vRewardToken = gov.vRewardToken();
        }

        proposalFee = _proposalFee;

        require(
            _proposalThresholdRate >= MIN_PROPOSAL_THRESHOLD_RATE &&
                _proposalThresholdRate <= MAX_PROPOSAL_THRESHOLD_RATE
        );
        proposalThresholdRate = _proposalThresholdRate;

        require(
            _quorumVotesRate >= MIN_QUORUM_VOTES_RATE &&
                _quorumVotesRate <= MAX_QUORUM_VOTES_RATE
        );
        quorumVotesRate = _quorumVotesRate;

        require(
            _votingPeriod >= MIN_VOTING_PERIOD &&
                _votingPeriod <= MAX_VOTING_PERIOD
        );
        votingPeriod = _votingPeriod;

        require(
            _votingDelay >= MIN_VOTING_DELAY && _votingDelay <= MAX_VOTING_DELAY
        );
        votingDelay = _votingDelay;

        require(
            _gracePeriod >= MIN_GRACE_PERIOD && _gracePeriod <= MAX_GRACE_PERIOD
        );
        gracePeriod = _gracePeriod;
    }

    event ProposalCreated(
        uint256 id,
        address proposer,
        address target,
        string signature,
        bytes callData,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );
    event VoteCast(
        address voter,
        uint256 proposalId,
        bool support,
        uint256 votes,
        uint256 againstVotes,
        uint256 forVotes,
        uint256 quorumVotes,
        string reason
    );
    event ProposalCanceled(uint256 id);
    event ProposalQueued(uint256 id, uint256 eta, uint256 tid);
    event ProposalExecuted(uint256 id, bool succeeded);
    event VerifierSet(address target, string sig, address valid);
    event ProposalFeeBurnt(address proposer, uint256 proposalFee);
    event ProposalFeeSet(uint256 oldProposalFee, uint256 proposalFee);
    event ProposalThresholdRateSet(
        uint256 oldProposalThresholdRate,
        uint256 proposalThresholdRate
    );
    event QuorumVotesRateSet(
        uint256 oldQuorumVotesRate,
        uint256 quorumVotesRate
    );
    event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);
    event VotingDelaySet(uint256 oldVotingDelay, uint256 newVotingDelay);
    event GracePeriodSet(uint256 oldGracePeriod, uint256 gracePeriod);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyPolicyAdmin() {
        require(msg.sender == owner || msg.sender == policyAdmin);
        _;
    }

    modifier onlyGovernance() {
        require(msg.sender == governance);
        _;
    }

    function version() public pure returns (string memory) {
        return "GovernorImpl20240528";
    }

    /**
     * @notice Function used to propose a new proposal. Sender must have delegates above the proposal threshold
     * @param target Target address for proposal calls
     * @param signature Function signature for proposal calls
     * @param callData Calldata for proposal call
     * @param description String description of the proposal
     * @return Proposal id of new proposal
     */
    function propose(
        address target,
        string memory signature,
        bytes memory callData,
        string memory description
    ) public returns (uint256) {
        require(vRewardToken != address(0));
        bytes32 queuedSigHash;

        if (target == address(0)) {
            require(bytes(signature).length == 0);
            require(callData.length == 0);
        } else {
            require(
                verifiers[target][keccak256(abi.encodePacked(signature))] !=
                    address(0)
            );
            require(
                IVerifier(
                    verifiers[target][keccak256(abi.encodePacked(signature))]
                ).verify(target, signature, callData)
            );

            queuedSigHash = keccak256(abi.encode(target, signature, callData));
            if (queuedPids[queuedSigHash] != 0) {
                ProposalState queuedState = state(queuedPids[queuedSigHash]);
                require(
                    queuedState != ProposalState.Pending &&
                        queuedState != ProposalState.Active &&
                        queuedState != ProposalState.Succeeded &&
                        queuedState != ProposalState.Queued
                );
            }
        }

        uint256 proposalThreshold = div256(
            mul256(
                IVotingRewardToken(vRewardToken).getPriorSupply(sub256(block.number, 1)),
                proposalThresholdRate
            ),
            RATE_DENOM
        );
        require(
            IVotingRewardToken(vRewardToken).getPriorBalance(
                msg.sender,
                sub256(block.number, 1)
            ) > proposalThreshold,
            "Governor::propose: proposer votes below proposal threshold"
        );

        uint256 latestProposalId = latestProposalIds[msg.sender];
        if (latestProposalId != 0) {
            ProposalState proposersLatestProposalState = state(
                latestProposalId
            );
            require(
                proposersLatestProposalState != ProposalState.Active,
                "Governor::propose: one live proposal per proposer, found an already active proposal"
            );
            require(
                proposersLatestProposalState != ProposalState.Pending,
                "Governor::propose: one live proposal per proposer, found an already pending proposal"
            );
        }

        if (proposalFee != 0) {
            require(
                IERC20(IGovernance(governance).rewardToken()).transferFrom(
                    msg.sender,
                    address(this),
                    proposalFee
                )
            );
            IERC20(IGovernance(governance).rewardToken()).burn(proposalFee);

            emit ProposalFeeBurnt(msg.sender, proposalFee);
        }

        uint256 startBlock = add256(block.number, votingDelay);
        uint256 endBlock = add256(startBlock, votingPeriod);

        proposalCount++;
        Proposal memory newProposal = Proposal({
            id: proposalCount,
            proposer: msg.sender,
            eta: 0,
            target: target,
            signature: signature,
            callData: callData,
            startBlock: startBlock,
            endBlock: endBlock,
            forVotes: 0,
            againstVotes: 0,
            canceled: false,
            executed: false
        });

        proposals[newProposal.id] = newProposal;
        latestProposalIds[newProposal.proposer] = newProposal.id;
        queuedPids[queuedSigHash] = newProposal.id;
        pQuorumVotesRate[proposalCount] = quorumVotesRate;

        emit ProposalCreated(
            newProposal.id,
            msg.sender,
            target,
            signature,
            callData,
            startBlock,
            endBlock,
            description
        );
        return newProposal.id;
    }

    /**
     * @notice Queues a proposal of state succeeded
     * @param proposalId The id of the proposal to queue
     */
    function queue(uint256 proposalId) external {
        require(
            state(proposalId) == ProposalState.Succeeded,
            "Governor::queue: proposal can only be queued if it is succeeded"
        );
        Proposal storage proposal = proposals[proposalId];

        uint256 eta = block.timestamp;
        uint256 tid = queueOrRevertInternal(
            proposal.target,
            proposal.signature,
            proposal.callData,
            eta
        );
        proposal.eta = eta;
        pids[tid] = proposalId;

        emit ProposalQueued(proposalId, eta, tid);
    }

    function queueOrRevertInternal(
        address target,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) internal returns (uint256 tid) {
        bytes32 qhash = keccak256(abi.encode(target, signature, data, eta));
        require(
            !queuedTransactions[qhash],
            "Governor::queueOrRevertInternal: identical proposal action already queued at eta"
        );
        queuedTransactions[qhash] = true;

        tid = IGovernance(governance).transactionCount();
        IGovernance(governance).addTransaction(
            target,
            0,
            abi.encodePacked(bytes4(keccak256(bytes(signature))), data)
        );
    }

    function cancel(uint256 proposalId) external onlyPolicyAdmin {
        require(
            state(proposalId) == ProposalState.Pending,
            "Governor::cancel: cannot cancel proposal"
        );

        Proposal storage proposal = proposals[proposalId];
        proposal.canceled = true;

        emit ProposalCanceled(proposalId);
    }

    function executed(uint256 transactionId, bool executionResult) external {
        require(msg.sender == governance);

        uint256 proposalId = pids[transactionId];
        require(proposalId != 0);
        require(
            state(proposalId) == ProposalState.Queued,
            "Governor::execute: proposal can only be executed if it is queued"
        );

        Proposal storage proposal = proposals[proposalId];
        require(proposal.eta <= block.timestamp);
        require(!proposal.executed);

        proposal.executed = true;
        Result memory r = Result({
            executedBlock: block.number,
            succeeded: executionResult
        });
        results[proposalId] = r;

        emit ProposalExecuted(proposalId, executionResult);
    }

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
        )
    {
        Proposal memory p = proposals[proposalId];
        return (
            p.proposer,
            p.eta,
            p.startBlock,
            p.endBlock,
            p.forVotes,
            p.againstVotes
        );
    }

    /**
     * @notice Gets actions of a proposal
     * @param proposalId the id of the proposal
     * @return Targets, values, signatures, and calldatas of the proposal actions
     */
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
        )
    {
        Proposal memory p = proposals[proposalId];
        return (p.target, p.signature, p.callData, p.eta);
    }

    /**
     * @notice Gets the receipt for a voter on a given proposal
     * @param proposalId the id of proposal
     * @param voter The address of the voter
     * @return The voting receipt
     */
    function getReceipt(
        uint256 proposalId,
        address voter
    ) external view returns (bool hasVoted, bool support, uint256 votes) {
        Receipt memory re = proposals[proposalId].receipts[voter];
        hasVoted = re.hasVoted;
        support = re.support;
        votes = re.votes;
    }

    function getResult(
        uint256 proposalId
    ) external view returns (bool succeeded, uint256 executedBlock) {
        Result memory res = results[proposalId];
        succeeded = res.succeeded;
        executedBlock = res.executedBlock;
    }

    /**
     * @notice Gets the state of a proposal
     * @param proposalId The id of the proposal
     * @return Proposal state
     */
    function state(uint256 proposalId) public view returns (ProposalState) {
        require(
            proposalCount >= proposalId,
            "Governor::state: invalid proposal id"
        );
        Proposal memory proposal = proposals[proposalId];

        uint256 curQuorumVotesRate = (pQuorumVotesRate[proposalId] == 0)
            ? 3000
            : pQuorumVotesRate[proposalId];
        uint256 quorumVotes = block.number <= proposal.startBlock
            ? IVotingRewardToken(vRewardToken).totalSupply()
            : div256(
                mul256(
                    IVotingRewardToken(vRewardToken).getPriorSupply(proposal.startBlock),
                    curQuorumVotesRate
                ),
                RATE_DENOM
            );

        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (
            proposal.forVotes <= proposal.againstVotes ||
            add256(proposal.forVotes, proposal.againstVotes) < quorumVotes
        ) {
            return ProposalState.Defeated;
        } else if (proposal.eta == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp >= add256(proposal.eta, gracePeriod)) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    /**
     * @notice Cast a vote for a proposal
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. false=against, true=for
     */
    function castVote(uint256 proposalId, bool support) external {
        (
            uint256 votes,
            uint256 againstVotes,
            uint256 forVotes,
            uint256 quorumVotes
        ) = castVoteInternal(msg.sender, proposalId, support);
        emit VoteCast(
            msg.sender,
            proposalId,
            support,
            votes,
            againstVotes,
            forVotes,
            quorumVotes,
            ""
        );
    }

    /**
     * @notice Cast a vote for a proposal with a reason
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. false=against, true=for
     * @param reason The reason given for the vote by the voter
     */
    function castVoteWithReason(
        uint256 proposalId,
        bool support,
        string calldata reason
    ) external {
        (
            uint256 votes,
            uint256 againstVotes,
            uint256 forVotes,
            uint256 quorumVotes
        ) = castVoteInternal(msg.sender, proposalId, support);
        emit VoteCast(
            msg.sender,
            proposalId,
            support,
            votes,
            againstVotes,
            forVotes,
            quorumVotes,
            reason
        );
    }

    /**
     * @notice Internal function that caries out voting logic
     * @param voter The voter that is casting their vote
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. false=against, true=for
     * @return The number of votes cast
     */
    function castVoteInternal(
        address voter,
        uint256 proposalId,
        bool support
    ) internal returns (uint256, uint256, uint256, uint256) {
        require(
            state(proposalId) == ProposalState.Active,
            "Governor::castVoteInternal: voting is closed"
        );
        Proposal storage proposal = proposals[proposalId];

        uint256 votes = IVotingRewardToken(vRewardToken).getPriorBalance(
            voter,
            proposal.startBlock
        );
        require(votes != 0);

        if (!support) {
            proposal.againstVotes = add256(proposal.againstVotes, votes);
        } else {
            proposal.forVotes = add256(proposal.forVotes, votes);
        }

        {
            Receipt storage receipt = proposal.receipts[voter];

            require(
                !receipt.hasVoted,
                "Governor::castVoteInternal: voter already voted"
            );
            receipt.hasVoted = true;

            receipt.support = support;
            receipt.votes = votes;
        }

        return (
            votes,
            proposal.againstVotes,
            proposal.forVotes,
            div256(
                mul256(
                    IVotingRewardToken(vRewardToken).getPriorSupply(proposal.startBlock),
                    pQuorumVotesRate[proposalId]
                ),
                RATE_DENOM
            )
        );
    }

    function changeNextOwner(address _nextOwner) public onlyOwner {
        nextOwner = _nextOwner;
    }

    function changeOwner() public {
        require(msg.sender == nextOwner);

        owner = nextOwner;
        nextOwner = address(0);
    }

    function _setVerifier(
        address target,
        string calldata sig,
        address verifier
    ) external onlyPolicyAdmin {
        require(verifier != address(0));
        verifiers[target][keccak256(abi.encodePacked(sig))] = verifier;
        emit VerifierSet(target, sig, verifier);
    }

    function setPolicyAdmin(address _policyAdmin) external onlyOwner {
        require(_policyAdmin != address(0));
        policyAdmin = _policyAdmin;
    }

    /**
     * @notice Admin function for setting the proposal fee
     * @param newProposalFee new proposal fee, in blocks
     */
    function _setProposalFee(uint256 newProposalFee) external onlyOwner {
        uint256 oldProposalFee = proposalFee;
        proposalFee = newProposalFee;

        emit ProposalFeeSet(oldProposalFee, proposalFee);
    }

    /**
     * @notice Admin function for setting the proposal threshold rate
     * @param newProposalThresholdRate new proposal threshold rate, in blocks
     */
    function _setProposalThresholdRate(
        uint256 newProposalThresholdRate
    ) external onlyOwner {
        require(
            newProposalThresholdRate >= MIN_PROPOSAL_THRESHOLD_RATE &&
                newProposalThresholdRate <= MAX_PROPOSAL_THRESHOLD_RATE
        );
        uint256 oldProposalThresholdRate = proposalThresholdRate;
        proposalThresholdRate = newProposalThresholdRate;

        emit ProposalThresholdRateSet(
            oldProposalThresholdRate,
            proposalThresholdRate
        );
    }

    /**
     * @notice Admin function for setting the quorum votes rate
     * @param newQuorumVotesRate new quorum votes rate, in blocks
     */
    function _setQuorumVotesRate(uint256 newQuorumVotesRate) external {
        require(msg.sender == owner || msg.sender == governance);
        require(
            newQuorumVotesRate >= MIN_QUORUM_VOTES_RATE &&
                newQuorumVotesRate <= MAX_QUORUM_VOTES_RATE
        );
        uint256 oldQuorumVotesRate = quorumVotesRate;
        quorumVotesRate = newQuorumVotesRate;

        emit QuorumVotesRateSet(oldQuorumVotesRate, quorumVotesRate);
    }

    /**
     * @notice Admin function for setting the voting period
     * @param newVotingPeriod new voting period, in blocks
     */
    function _setVotingPeriod(uint256 newVotingPeriod) external onlyOwner {
        require(
            newVotingPeriod >= MIN_VOTING_PERIOD &&
                newVotingPeriod <= MAX_VOTING_PERIOD,
            "Governor::_setVotingPeriod: invalid voting period"
        );
        uint256 oldVotingPeriod = votingPeriod;
        votingPeriod = newVotingPeriod;

        emit VotingPeriodSet(oldVotingPeriod, votingPeriod);
    }

    /**
     * @notice Admin function for setting the voting delay
     * @param newVotingDelay new voting delay, in blocks
     */
    function _setVotingDelay(uint256 newVotingDelay) external onlyOwner {
        require(
            newVotingDelay >= MIN_VOTING_DELAY &&
                newVotingDelay <= MAX_VOTING_DELAY,
            "Governor::_setVotingDelay: invalid voting delay"
        );
        uint256 oldVotingDelay = votingDelay;
        votingDelay = newVotingDelay;

        emit VotingDelaySet(oldVotingDelay, votingDelay);
    }

    function _setGracePeriod(uint256 newGracePeriod) external onlyOwner {
        require(
            newGracePeriod >= MIN_GRACE_PERIOD &&
                newGracePeriod <= MAX_GRACE_PERIOD,
            "Governor::_setGracePeriod: invalid grace period"
        );
        uint256 oldGracePeriod = gracePeriod;
        gracePeriod = newGracePeriod;

        emit GracePeriodSet(oldGracePeriod, gracePeriod);
    }

    function add256(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "addition overflow");
        return c;
    }

    function sub256(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "subtraction underflow");
        return a - b;
    }

    function mul256(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div256(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0);
        uint256 c = a / b;

        return c;
    }

    function setvRewardToken(address _vRewardToken) external onlyOwner {
        vRewardToken = _vRewardToken;
    }

}
