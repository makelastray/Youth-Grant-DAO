(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u101))
(define-constant ERR_VOTING_PERIOD_ENDED (err u102))
(define-constant ERR_VOTING_PERIOD_ACTIVE (err u103))
(define-constant ERR_ALREADY_VOTED (err u104))
(define-constant ERR_INSUFFICIENT_FUNDS (err u105))
(define-constant ERR_PROPOSAL_EXECUTED (err u106))
(define-constant ERR_PROPOSAL_NOT_PASSED (err u107))
(define-constant ERR_INVALID_AGE (err u108))
(define-constant ERR_INVALID_AMOUNT (err u109))
(define-constant ERR_DELEGATE_NOT_FOUND (err u110))
(define-constant ERR_SELF_DELEGATION (err u111))
(define-constant ERR_DELEGATE_INACTIVE (err u112))
(define-constant ERR_MAX_DELEGATION_REACHED (err u113))

(define-constant VOTING_PERIOD u144)
(define-constant MIN_AGE u13)
(define-constant MAX_AGE u25)
(define-constant MIN_PROPOSAL_AMOUNT u1000000)
(define-constant MAX_PROPOSAL_AMOUNT u50000000)
(define-constant MAX_DELEGATIONS_PER_DELEGATE u10)

(define-data-var contract-owner principal tx-sender)
(define-data-var proposal-counter uint u0)
(define-data-var total-treasury uint u0)

(define-map proposals uint {
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    amount: uint,
    votes-for: uint,
    votes-against: uint,
    created-at: uint,
    executed: bool,
    proposer-age: uint
})

(define-map votes {proposal-id: uint, voter: principal} bool)
(define-map member-ages principal uint)
(define-map member-reputation principal uint)
(define-map delegations principal principal)
(define-map delegation-counts principal uint)
(define-map delegate-performance principal {total-votes: uint, successful-votes: uint})
(define-map delegated-votes {proposal-id: uint, delegate: principal} {vote-for: bool, delegator-count: uint})

(define-public (set-member-age (age uint))
    (begin
        (asserts! (and (>= age MIN_AGE) (<= age MAX_AGE)) ERR_INVALID_AGE)
        (ok (map-set member-ages tx-sender age))
    )
)

(define-public (deposit-treasury (amount uint))
    (begin
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (var-set total-treasury (+ (var-get total-treasury) amount))
        (ok true)
    )
)

(define-public (submit-proposal (title (string-ascii 100)) (description (string-ascii 500)) (amount uint))
    (let (
        (proposal-id (+ (var-get proposal-counter) u1))
        (member-age (default-to u0 (map-get? member-ages tx-sender)))
        (current-block stacks-block-height)
    )
        (asserts! (and (>= member-age MIN_AGE) (<= member-age MAX_AGE)) ERR_INVALID_AGE)
        (asserts! (and (>= amount MIN_PROPOSAL_AMOUNT) (<= amount MAX_PROPOSAL_AMOUNT)) ERR_INVALID_AMOUNT)
        (asserts! (<= amount (var-get total-treasury)) ERR_INSUFFICIENT_FUNDS)
        
        (map-set proposals proposal-id {
            proposer: tx-sender,
            title: title,
            description: description,
            amount: amount,
            votes-for: u0,
            votes-against: u0,
            created-at: current-block,
            executed: false,
            proposer-age: member-age
        })
        
        (var-set proposal-counter proposal-id)
        (ok proposal-id)
    )
)

(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
    (let (
        (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
        (current-block stacks-block-height)
        (voting-deadline (+ (get created-at proposal) VOTING_PERIOD))
        (voter-age (default-to u0 (map-get? member-ages tx-sender)))
    )
        (asserts! (and (>= voter-age MIN_AGE) (<= voter-age MAX_AGE)) ERR_INVALID_AGE)
        (asserts! (<= current-block voting-deadline) ERR_VOTING_PERIOD_ENDED)
        (asserts! (is-none (map-get? votes {proposal-id: proposal-id, voter: tx-sender})) ERR_ALREADY_VOTED)
        
        (map-set votes {proposal-id: proposal-id, voter: tx-sender} true)
        
        (if vote-for
            (map-set proposals proposal-id 
                (merge proposal {votes-for: (+ (get votes-for proposal) u1)}))
            (map-set proposals proposal-id 
                (merge proposal {votes-against: (+ (get votes-against proposal) u1)}))
        )
        
        (let ((current-rep (default-to u0 (map-get? member-reputation tx-sender))))
            (map-set member-reputation tx-sender (+ current-rep u1))
        )
        
        (ok true)
    )
)

(define-public (execute-proposal (proposal-id uint))
    (let (
        (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
        (current-block stacks-block-height)
        (voting-deadline (+ (get created-at proposal) VOTING_PERIOD))
    )
        (asserts! (> current-block voting-deadline) ERR_VOTING_PERIOD_ACTIVE)
        (asserts! (not (get executed proposal)) ERR_PROPOSAL_EXECUTED)
        (asserts! (> (get votes-for proposal) (get votes-against proposal)) ERR_PROPOSAL_NOT_PASSED)
        (asserts! (<= (get amount proposal) (var-get total-treasury)) ERR_INSUFFICIENT_FUNDS)
        
        (try! (as-contract (stx-transfer? (get amount proposal) tx-sender (get proposer proposal))))
        
        (map-set proposals proposal-id (merge proposal {executed: true}))
        (var-set total-treasury (- (var-get total-treasury) (get amount proposal)))
        
        (let ((current-rep (default-to u0 (map-get? member-reputation (get proposer proposal)))))
            (map-set member-reputation (get proposer proposal) (+ current-rep u5))
        )
        
        (ok true)
    )
)

(define-public (emergency-withdraw (amount uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
        (try! (as-contract (stx-transfer? amount tx-sender (var-get contract-owner))))
        (var-set total-treasury (- (var-get total-treasury) amount))
        (ok true)
    )
)

(define-public (update-contract-owner (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
        (var-set contract-owner new-owner)
        (ok true)
    )
)

(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals proposal-id)
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
    (map-get? votes {proposal-id: proposal-id, voter: voter})
)

(define-read-only (get-member-age (member principal))
    (map-get? member-ages member)
)

(define-read-only (get-member-reputation (member principal))
    (default-to u0 (map-get? member-reputation member))
)

(define-read-only (get-treasury-balance)
    (var-get total-treasury)
)

(define-read-only (get-proposal-count)
    (var-get proposal-counter)
)

(define-read-only (get-contract-owner)
    (var-get contract-owner)
)

(define-read-only (is-voting-period-active (proposal-id uint))
    (match (map-get? proposals proposal-id)
        proposal (let (
            (current-block stacks-block-height)
            (voting-deadline (+ (get created-at proposal) VOTING_PERIOD))
        )
            (<= current-block voting-deadline)
        )
        false
    )
)

(define-read-only (get-proposal-status (proposal-id uint))
    (match (map-get? proposals proposal-id)
        proposal (let (
            (current-block stacks-block-height)
            (voting-deadline (+ (get created-at proposal) VOTING_PERIOD))
            (is-active (<= current-block voting-deadline))
            (votes-for (get votes-for proposal))
            (votes-against (get votes-against proposal))
        )
            {
                voting-active: is-active,
                votes-for: votes-for,
                votes-against: votes-against,
                passed: (> votes-for votes-against),
                executed: (get executed proposal)
            }
        )
        {
            voting-active: false,
            votes-for: u0,
            votes-against: u0,
            passed: false,
            executed: false
        }
    )
)

(define-read-only (can-execute-proposal (proposal-id uint))
    (match (map-get? proposals proposal-id)
        proposal (let (
            (current-block stacks-block-height)
            (voting-deadline (+ (get created-at proposal) VOTING_PERIOD))
            (voting-ended (> current-block voting-deadline))
            (passed (> (get votes-for proposal) (get votes-against proposal)))
            (not-executed (not (get executed proposal)))
            (has-funds (<= (get amount proposal) (var-get total-treasury)))
        )
            (and voting-ended passed not-executed has-funds)
        )
        false
    )
)



(define-private (check-member-eligibility (member principal) (count uint))
    (let ((age (default-to u0 (map-get? member-ages member))))
        (if (and (>= age MIN_AGE) (<= age MAX_AGE))
            (+ count u1)
            count
        )
    )
)

(define-public (delegate-vote (delegate principal))
    (let (
        (delegator tx-sender)
        (delegate-age (default-to u0 (map-get? member-ages delegate)))
        (delegator-age (default-to u0 (map-get? member-ages delegator)))
        (current-delegate-count (default-to u0 (map-get? delegation-counts delegate)))
    )
        (asserts! (not (is-eq delegator delegate)) ERR_SELF_DELEGATION)
        (asserts! (and (>= delegate-age MIN_AGE) (<= delegate-age MAX_AGE)) ERR_DELEGATE_INACTIVE)
        (asserts! (and (>= delegator-age MIN_AGE) (<= delegator-age MAX_AGE)) ERR_INVALID_AGE)
        (asserts! (< current-delegate-count MAX_DELEGATIONS_PER_DELEGATE) ERR_MAX_DELEGATION_REACHED)
        
        (match (map-get? delegations delegator)
            current-delegate (begin
                (map-set delegation-counts current-delegate 
                    (- (default-to u0 (map-get? delegation-counts current-delegate)) u1))
                (map-set delegation-counts delegate (+ current-delegate-count u1))
                (map-set delegations delegator delegate)
            )
            (begin
                (map-set delegation-counts delegate (+ current-delegate-count u1))
                (map-set delegations delegator delegate)
            )
        )
        
        (ok true)
    )
)

(define-public (revoke-delegation)
    (let (
        (delegator tx-sender)
        (current-delegate (unwrap! (map-get? delegations delegator) ERR_DELEGATE_NOT_FOUND))
    )
        (map-set delegation-counts current-delegate 
            (- (default-to u0 (map-get? delegation-counts current-delegate)) u1))
        (map-delete delegations delegator)
        (ok true)
    )
)

(define-public (vote-as-delegate (proposal-id uint) (vote-for bool))
    (let (
        (delegate tx-sender)
        (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
        (current-block stacks-block-height)
        (voting-deadline (+ (get created-at proposal) VOTING_PERIOD))
        (delegate-age (default-to u0 (map-get? member-ages delegate)))
        (delegation-count (default-to u0 (map-get? delegation-counts delegate)))
        (voting-power (+ u1 delegation-count))
    )
        (asserts! (and (>= delegate-age MIN_AGE) (<= delegate-age MAX_AGE)) ERR_INVALID_AGE)
        (asserts! (<= current-block voting-deadline) ERR_VOTING_PERIOD_ENDED)
        (asserts! (is-none (map-get? votes {proposal-id: proposal-id, voter: delegate})) ERR_ALREADY_VOTED)
        (asserts! (is-none (map-get? delegated-votes {proposal-id: proposal-id, delegate: delegate})) ERR_ALREADY_VOTED)
        
        (map-set votes {proposal-id: proposal-id, voter: delegate} true)
        (map-set delegated-votes {proposal-id: proposal-id, delegate: delegate} 
            {vote-for: vote-for, delegator-count: delegation-count})
        
        (if vote-for
            (map-set proposals proposal-id 
                (merge proposal {votes-for: (+ (get votes-for proposal) voting-power)}))
            (map-set proposals proposal-id 
                (merge proposal {votes-against: (+ (get votes-against proposal) voting-power)}))
        )
        
        (let ((current-rep (default-to u0 (map-get? member-reputation delegate))))
            (map-set member-reputation delegate (+ current-rep voting-power))
        )
        
        (let ((perf (default-to {total-votes: u0, successful-votes: u0} 
                    (map-get? delegate-performance delegate))))
            (map-set delegate-performance delegate 
                {total-votes: (+ (get total-votes perf) u1), 
                 successful-votes: (get successful-votes perf)})
        )
        
        (ok true)
    )
)

(define-public (update-delegate-performance (proposal-id uint))
    (let (
        (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
        (current-block stacks-block-height)
        (voting-deadline (+ (get created-at proposal) VOTING_PERIOD))
        (proposal-passed (> (get votes-for proposal) (get votes-against proposal)))
    )
        (asserts! (> current-block voting-deadline) ERR_VOTING_PERIOD_ACTIVE)
        (asserts! (get executed proposal) ERR_PROPOSAL_NOT_PASSED)
        
        (match (map-get? delegated-votes {proposal-id: proposal-id, delegate: tx-sender})
            delegated-vote (let (
                (vote-aligned-with-outcome (is-eq (get vote-for delegated-vote) proposal-passed))
                (perf (default-to {total-votes: u0, successful-votes: u0} 
                        (map-get? delegate-performance tx-sender)))
            )
                (if vote-aligned-with-outcome
                    (map-set delegate-performance tx-sender 
                        {total-votes: (get total-votes perf), 
                         successful-votes: (+ (get successful-votes perf) u1)})
                    false
                )
                (ok true)
            )
            ERR_DELEGATE_NOT_FOUND
        )
    )
)

(define-read-only (get-delegation (member principal))
    (map-get? delegations member)
)

(define-read-only (get-delegation-count (delegate principal))
    (default-to u0 (map-get? delegation-counts delegate))
)

(define-read-only (get-delegate-performance (delegate principal))
    (default-to {total-votes: u0, successful-votes: u0} (map-get? delegate-performance delegate))
)

(define-read-only (get-delegate-success-rate (delegate principal))
    (let ((perf (get-delegate-performance delegate)))
        (if (> (get total-votes perf) u0)
            (/ (* (get successful-votes perf) u100) (get total-votes perf))
            u0
        )
    )
)

(define-read-only (get-voting-power (member principal))
    (let (
        (delegation-count (get-delegation-count member))
        (member-age (default-to u0 (map-get? member-ages member)))
    )
        (if (and (>= member-age MIN_AGE) (<= member-age MAX_AGE))
            (+ u1 delegation-count)
            u0
        )
    )
)

(define-read-only (get-delegated-vote (proposal-id uint) (delegate principal))
    (map-get? delegated-votes {proposal-id: proposal-id, delegate: delegate})
)

(define-read-only (is-eligible-delegate (delegate principal))
    (let (
        (delegate-age (default-to u0 (map-get? member-ages delegate)))
        (current-delegations (get-delegation-count delegate))
    )
        (and 
            (>= delegate-age MIN_AGE) 
            (<= delegate-age MAX_AGE)
            (< current-delegations MAX_DELEGATIONS_PER_DELEGATE)
        )
    )
)



