;; P2P Lending Platform Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-balance (err u101))
(define-constant err-invalid-loan (err u102))
(define-constant err-loan-exists (err u103))
(define-constant err-repayment-too-low (err u104))

;; Data vars
(define-map loans 
    { loan-id: uint }
    {
        borrower: principal,
        lender: (optional principal),
        amount: uint,
        interest-rate: uint,
        term-length: uint,
        status: (string-ascii 20)
    }
)

(define-data-var loan-counter uint u0)

;; Private functions
(define-private (is-contract-owner)
    (is-eq tx-sender contract-owner)
)

;; Public functions
(define-public (create-loan (amount uint) (interest-rate uint) (term-length uint))
    (let 
        (
            (loan-id (var-get loan-counter))
        )
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-insert loans
            { loan-id: loan-id }
            {
                borrower: tx-sender,
                lender: none,
                amount: amount,
                interest-rate: interest-rate,
                term-length: term-length,
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
        (asserts! (is-eq (get status loan) "PENDING") err-invalid-loan)
        (try! (stx-transfer? amount tx-sender (get borrower loan)))
        (map-set loans
            { loan-id: loan-id }
            (merge loan {
                lender: (some tx-sender),
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

;; Read only functions
(define-read-only (get-loan (loan-id uint))
    (map-get? loans { loan-id: loan-id })
)

(define-read-only (get-loan-count)
    (ok (var-get loan-counter))
)
