;; CrowdInference Platform
;; Collaborative distributed AI inference with compute rewards

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u600))
(define-constant err-not-found (err u601))
(define-constant err-not-authorized (err u602))
(define-constant err-invalid-quality (err u603))
(define-constant err-already-submitted (err u604))

;; Data Variables
(define-data-var job-id-nonce uint u0)
(define-data-var submission-id-nonce uint u0)

;; Data Maps
(define-map inference-jobs
    uint
    {
        requester: principal,
        model-hash: (buff 32),
        input-hash: (buff 32),
        reward-pool: uint,
        min-workers: uint,
        submissions-count: uint,
        status: (string-ascii 20)
    }
)

(define-map worker-submissions
    uint
    {
        job-id: uint,
        worker: principal,
        output-hash: (buff 32),
        quality-score: uint,
        verified: bool,
        paid: bool,
        timestamp: uint
    }
)

(define-map worker-participation
    {job-id: uint, worker: principal}
    bool
)

(define-map worker-stats
    principal
    {
        total-jobs: uint,
        total-earned: uint,
        avg-quality: uint
    }
)

;; Read-only functions
(define-read-only (get-inference-job (job-id uint))
    (map-get? inference-jobs job-id)
)

(define-read-only (get-submission (submission-id uint))
    (map-get? worker-submissions submission-id)
)

(define-read-only (has-participated (job-id uint) (worker principal))
    (default-to false (map-get? worker-participation {job-id: job-id, worker: worker}))
)

(define-read-only (get-worker-stats (worker principal))
    (default-to {total-jobs: u0, total-earned: u0, avg-quality: u0} 
        (map-get? worker-stats worker))
)

(define-read-only (get-next-job-id)
    (var-get job-id-nonce)
)

;; Public functions
;; #[allow(unchecked_data)]
(define-public (create-inference-job 
    (model-hash (buff 32))
    (input-hash (buff 32))
    (reward-pool uint)
    (min-workers uint))
    (let
        ((new-id (var-get job-id-nonce)))
        (try! (stx-transfer? reward-pool tx-sender (as-contract tx-sender)))
        (map-set inference-jobs new-id
            {
                requester: tx-sender,
                model-hash: model-hash,
                input-hash: input-hash,
                reward-pool: reward-pool,
                min-workers: min-workers,
                submissions-count: u0,
                status: "open"
            }
        )
        (var-set job-id-nonce (+ new-id u1))
        (ok new-id)
    )
)

;; #[allow(unchecked_data)]
(define-public (submit-inference (job-id uint) (output-hash (buff 32)))
    (let
        ((job (unwrap! (map-get? inference-jobs job-id) err-not-found))
         (new-submission-id (var-get submission-id-nonce)))
        (asserts! (is-eq (get status job) "open") err-not-authorized)
        (asserts! (not (has-participated job-id tx-sender)) err-already-submitted)
        (map-set worker-submissions new-submission-id
            {
                job-id: job-id,
                worker: tx-sender,
                output-hash: output-hash,
                quality-score: u0,
                verified: false,
                paid: false,
                timestamp: stacks-block-height
            }
        )
        (map-set worker-participation {job-id: job-id, worker: tx-sender} true)
        (map-set inference-jobs job-id
            (merge job {submissions-count: (+ (get submissions-count job) u1)}))
        (var-set submission-id-nonce (+ new-submission-id u1))
        (ok new-submission-id)
    )
)

;; #[allow(unchecked_data)]
(define-public (verify-submission (submission-id uint) (quality-score uint))
    (let
        ((submission (unwrap! (map-get? worker-submissions submission-id) err-not-found))
         (job (unwrap! (map-get? inference-jobs (get job-id submission)) err-not-found)))
        (asserts! (is-eq tx-sender (get requester job)) err-not-authorized)
        (asserts! (<= quality-score u100) err-invalid-quality)
        (map-set worker-submissions submission-id
            (merge submission {quality-score: quality-score, verified: true}))
        (ok true)
    )
)

(define-public (distribute-rewards (submission-id uint))
    (let
        ((submission (unwrap! (map-get? worker-submissions submission-id) err-not-found))
         (job (unwrap! (map-get? inference-jobs (get job-id submission)) err-not-found))
         (reward-amount (/ (* (get reward-pool job) (get quality-score submission)) 
                          (* u100 (get submissions-count job))))
         (worker-stat (get-worker-stats (get worker submission))))
        (asserts! (is-eq tx-sender (get requester job)) err-not-authorized)
        (asserts! (get verified submission) err-not-authorized)
        (asserts! (not (get paid submission)) err-already-submitted)
        (try! (as-contract (stx-transfer? reward-amount tx-sender (get worker submission))))
        (map-set worker-submissions submission-id (merge submission {paid: true}))
        (map-set worker-stats (get worker submission)
            {
                total-jobs: (+ (get total-jobs worker-stat) u1),
                total-earned: (+ (get total-earned worker-stat) reward-amount),
                avg-quality: (/ (+ (* (get avg-quality worker-stat) (get total-jobs worker-stat)) 
                                   (get quality-score submission))
                               (+ (get total-jobs worker-stat) u1))
            }
        )
        (ok true)
    )
)

(define-public (close-job (job-id uint))
    (let
        ((job (unwrap! (map-get? inference-jobs job-id) err-not-found)))
        (asserts! (is-eq tx-sender (get requester job)) err-not-authorized)
        (map-set inference-jobs job-id (merge job {status: "closed"}))
        (ok true)
    )
)

;; Cancel job (before any submissions)
(define-public (cancel-job (job-id uint))
    (let
        ((job (unwrap! (map-get? inference-jobs job-id) err-not-found)))
        (asserts! (is-eq tx-sender (get requester job)) err-not-authorized)
        (asserts! (is-eq (get submissions-count job) u0) err-not-authorized)
        (try! (as-contract (stx-transfer? (get reward-pool job) tx-sender (get requester job))))
        (map-set inference-jobs job-id (merge job {status: "cancelled"}))
        (ok true)
    )
)