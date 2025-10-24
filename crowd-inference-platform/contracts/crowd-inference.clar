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