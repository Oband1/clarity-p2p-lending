;; P2P Lending Platform Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-balance (err u101))
(define-constant err-invalid-loan (err u102))
(define-constant err-loan-exists (err u103))
(define-constant err-repayment-too-low (err u104))
(define-constant err-amount-too-high (err u105))
(define-constant err-invalid-term (err u106))
(define-constant err-insufficient-collateral (err u107))

;; Contract status
(define-data-var contract-enabled bool true)

;; Configuration
(define-data-var max-loan-amount uint u100000000) ;; 100 STX
(define-data-var min-loan-amount uint u1000000)   ;; 1 STX

;; Data vars
(define-map loans 
    { loan-id: uint }
    {
        borrower: principal,
        lender: (optional principal),
        amount: uint,
        collateral: uint,
        interest-rate: uint,
        term-length: uint,
        start-height: (optional uint),
        status: (string-ascii 20)
    }
)

(define-map borrower-scores
    { borrower: principal }
    { score: uint }
)

(define-data-var loan-counter uint u0)

;; Private functions
(define-private (is-contract-owner)
    (is-eq tx-sender contract-owner)
)

(define-private (validate-loan-params (amount uint) (term-length uint))
    (and 
        (>= amount (var-get min-loan-amount))
        (<= amount (var-get max-loan-amount))
        (>= term-length u1)
        (<= term-length u52) ;; Max 52 weeks
    )
)

;; Public functions
(define-public (set-contract-state (enabled bool))
    (begin
        (asserts! (is-contract-owner) err-owner-only)
        (ok (var-set contract-enabled enabled))
    )
)

(define-public (create-loan (amount uint) (interest-rate uint) (term-length uint))
    (let 
        (
            (loan-id (var-get loan-counter))
        )
        (asserts! (var-get contract-enabled) (err u108))
        (asserts! (validate-loan-params amount term-length) (err u109))
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-insert loans
            { loan-id: loan-id }
            {
                borrower: tx-sender,
                lender: none,
                amount: amount,
                collateral: u0,
                interest-rate: interest-rate,
                term-length: term-length,
                start-height: none,
                status: "PENDING"
            }
        )
        (var-set loan-counter (+ loan-id u1))
        (ok loan-id)
    )
)

(define-public (fund-loan (loan-id uint))
    (let
        (
            (loan (unwrap! (map-get? loans { loan-id: loan-id }) err-invalid-loan))
            (amount (get amount loan))
        )
        (asserts! (var-get contract-enabled) (err u108))
        (asserts! (is-eq (get status loan) "PENDING") err-invalid-loan)
        (try! (stx-transfer? amount tx-sender (get borrower loan)))
        (map-set loans
            { loan-id: loan-id }
            (merge loan {
                lender: (some tx-sender),
                start-height: (some block-height),
                status: "FUNDED"
            })
        )
        (ok true)
    )
)

(define-public (repay-loan (loan-id uint) (amount uint))
    (let
        (
            (loan (unwrap! (map-get? loans { loan-id: loan-id }) err-invalid-loan))
            (repayment-amount (+ (get amount loan) 
                (* (get amount loan) (get interest-rate loan) (get term-length loan))))
        )
        (asserts! (var-get contract-enabled) (err u108))
        (asserts! (is-eq (get borrower loan) tx-sender) err-invalid-loan)
        (asserts! (is-eq (get status loan) "FUNDED") err-invalid-loan)
        (asserts! (>= amount repayment-amount) err-repayment-too-low)
        (try! (stx-transfer? repayment-amount tx-sender (unwrap! (get lender loan) err-invalid-loan)))
        (map-set loans
            { loan-id: loan-id }
            (merge loan {
                status: "REPAID"
            })
        )
        (ok true)
    )
)

(define-public (cancel-loan (loan-id uint))
    (let
        (
            (loan (unwrap! (map-get? loans { loan-id: loan-id }) err-invalid-loan))
        )
        (asserts! (and 
            (is-eq (get borrower loan) tx-sender)
            (is-eq (get status loan) "PENDING")
        ) err-invalid-loan)
        (try! (as-contract (stx-transfer? (get amount loan) tx-sender (get borrower loan))))
        (map-set loans
            { loan-id: loan-id }
            (merge loan {
                status: "CANCELLED"
            })
        )
        (ok true)
    )
)

;; Read only functions
(define-read-only (get-loan (loan-id uint))
    (map-get? loans { loan-id: loan-id })
)

(define-read-only (get-loan-count)
    (ok (var-get loan-counter))
)
