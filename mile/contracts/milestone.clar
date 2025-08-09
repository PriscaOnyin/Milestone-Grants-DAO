;; Milestone Grants DAO
;; Community-reviewed grants with milestone-based disbursement tracking (no funds transfer; on-chain state only)

;; Errors
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_INPUT (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Admin (set to contract deployer at deploy time)
(define-constant ADMIN tx-sender)

;; Data Vars
(define-data-var next-grant-id uint u1)
(define-data-var next-milestone-id uint u1)

;; Committee members
(define-map committee
  { member: principal }
  { is-active: bool, added-at: uint }
)

;; Grants
(define-map grants
  { grant-id: uint }
  {
    proposer: principal,
    title: (string-ascii 120),
    summary: (string-ascii 300),
    requested-amount: uint,
    deadline: uint,
    status: uint, ;; 1=proposed, 2=approved, 3=active, 4=completed, 5=cancelled
    reviewer: (optional principal),
    funds-deposited: uint,
    paid-out: uint,
    repo-url: (string-ascii 120)
  }
)

;; Milestones
(define-map milestones
  { grant-id: uint, milestone-id: uint }
  {
    title: (string-ascii 100),
    proof-hash: (string-ascii 64),
    due-block: uint,
    amount: uint,
    status: uint, ;; 1=pending, 2=submitted, 3=approved, 4=rejected
    submitter: principal
  }
)

;; Validation
(define-private (is-valid-principal (p principal))
  (not (is-eq p 'SP000000000000000000002Q6VF78))
)

(define-private (is-valid-len (s (string-ascii 300)) (max uint))
  (and (> (len s) u0) (<= (len s) max))
)

(define-private (is-valid-hash64 (h (string-ascii 64)))
  (and (> (len h) u0) (<= (len h) u64))
)

(define-private (is-valid-grant-id (id uint))
  (and (> id u0) (< id (var-get next-grant-id)))
)

(define-private (is-valid-milestone-id (id uint))
  (and (> id u0) (< id (var-get next-milestone-id)))
)

(define-private (is-committee (who principal))
  (match (map-get? committee { member: who })
    d (get is-active d)
    false)
)

;; Admin: add committee member
(define-public (add-committee (member principal))
  (begin
    (asserts! (is-eq tx-sender ADMIN) ERR_UNAUTHORIZED)
    (asserts! (is-valid-principal member) ERR_INVALID_INPUT)
    (ok (map-set committee { member: member } { is-active: true, added-at: stacks-block-height }))
  )
)

;; Propose grant
(define-public (propose-grant
  (title (string-ascii 120))
  (summary (string-ascii 300))
  (requested-amount uint)
  (deadline uint)
  (repo-url (string-ascii 120)))
  (let ((gid (var-get next-grant-id)))
    (asserts! (is-valid-len title u120) ERR_INVALID_INPUT)
    (asserts! (is-valid-len summary u300) ERR_INVALID_INPUT)
    (asserts! (> requested-amount u0) ERR_INVALID_INPUT)
    (asserts! (> deadline stacks-block-height) ERR_INVALID_INPUT)
    (asserts! (is-valid-len repo-url u120) ERR_INVALID_INPUT)

    (map-set grants
      { grant-id: gid }
      {
        proposer: tx-sender,
        title: title,
        summary: summary,
        requested-amount: requested-amount,
        deadline: deadline,
        status: u1,
        reviewer: none,
        funds-deposited: u0,
        paid-out: u0,
        repo-url: repo-url
      }
    )
    (var-set next-grant-id (+ gid u1))
    (ok gid)
  )
)

;; Approve grant and assign reviewer
(define-public (approve-grant (grant-id uint) (reviewer principal))
  (let ((gid (begin (asserts! (is-valid-grant-id grant-id) ERR_NOT_FOUND) grant-id))
        (rev (begin (asserts! (is-valid-principal reviewer) ERR_INVALID_INPUT) reviewer))
        (g (unwrap! (map-get? grants { grant-id: grant-id }) ERR_NOT_FOUND)))
    (asserts! (is-committee tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status g) u1) ERR_INVALID_STATUS)
    (ok (map-set grants { grant-id: gid } (merge g { status: u2, reviewer: (some rev) })))
  )
)

;; Activate grant (e.g., after funds deposited off-chain)
(define-public (activate-grant (grant-id uint))
  (let ((gid (begin (asserts! (is-valid-grant-id grant-id) ERR_NOT_FOUND) grant-id))
        (g (unwrap! (map-get? grants { grant-id: grant-id }) ERR_NOT_FOUND)))
    (asserts! (is-committee tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status g) u2) ERR_INVALID_STATUS)
    (ok (map-set grants { grant-id: gid } (merge g { status: u3 })))
  )
)

;; Add milestone
(define-public (add-milestone
  (grant-id uint)
  (title (string-ascii 100))
  (due-block uint)
  (amount uint))
  (let ((gid (begin (asserts! (is-valid-grant-id grant-id) ERR_NOT_FOUND) grant-id))
        (mid (var-get next-milestone-id)))
    (asserts! (is-valid-len title u100) ERR_INVALID_INPUT)
    (asserts! (> due-block stacks-block-height) ERR_INVALID_INPUT)
    (asserts! (> amount u0) ERR_INVALID_INPUT)
    (let ((g (unwrap! (map-get? grants { grant-id: gid }) ERR_NOT_FOUND)))
      (asserts! (or (is-eq tx-sender (get proposer g)) (is-committee tx-sender)) ERR_UNAUTHORIZED)
      (map-set milestones { grant-id: gid, milestone-id: mid }
        {
          title: title,
          proof-hash: "", ;; empty until submitted
          due-block: due-block,
          amount: amount,
          status: u1,
          submitter: 'SP000000000000000000002Q6VF78
        }
      )
      (var-set next-milestone-id (+ mid u1))
      (ok mid)
    )
  )
)

;; Submit milestone work
(define-public (submit-milestone (grant-id uint) (milestone-id uint) (proof-hash (string-ascii 64)))
  (let ((gid (begin (asserts! (is-valid-grant-id grant-id) ERR_NOT_FOUND) grant-id))
        (mid (begin (asserts! (is-valid-milestone-id milestone-id) ERR_NOT_FOUND) milestone-id)))
    (asserts! (is-valid-hash64 proof-hash) ERR_INVALID_INPUT)
    (let ((m (unwrap! (map-get? milestones { grant-id: gid, milestone-id: mid }) ERR_NOT_FOUND)))
      (asserts! (is-eq (get status m) u1) ERR_INVALID_STATUS)
      (ok (map-set milestones { grant-id: gid, milestone-id: mid }
            (merge m { proof-hash: proof-hash, status: u2, submitter: tx-sender })))
    )
  )
)

;; Review milestone
(define-public (review-milestone (grant-id uint) (milestone-id uint) (approve bool))
  (let ((gid (begin (asserts! (is-valid-grant-id grant-id) ERR_NOT_FOUND) grant-id))
        (mid (begin (asserts! (is-valid-milestone-id milestone-id) ERR_NOT_FOUND) milestone-id))
        (g (unwrap! (map-get? grants { grant-id: grant-id }) ERR_NOT_FOUND))
        (m (unwrap! (map-get? milestones { grant-id: grant-id, milestone-id: milestone-id }) ERR_NOT_FOUND)))
    (asserts! (is-committee tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status m) u2) ERR_INVALID_STATUS)
    (ok (map-set milestones { grant-id: gid, milestone-id: mid }
          (merge m { status: (if approve u3 u4) })))
  )
)

;; Read-onlys
(define-read-only (get-grant (grant-id uint))
  (map-get? grants { grant-id: grant-id })
)

(define-read-only (get-milestone (grant-id uint) (milestone-id uint))
  (map-get? milestones { grant-id: grant-id, milestone-id: milestone-id })
)
