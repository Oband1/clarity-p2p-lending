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
(define-constant err-invalid-status-transition (err u110))
(define-constant err-grace-period-expired (err u111))

;; Contract status
(define-data-var contract-enabled bool true)

;; Configuration
(define-data-var max-loan-amount uint u100000000) ;; 100 STX
(define-data-var min-loan-amount uint u1000000)   ;; 1 STX
(define-data-var grace-period uint u144)          ;; ~1 day in blocks

;; Events
(define-data-var event-counter uint u0)

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
        status: (string-ascii 20),
        amount-repaid: uint,
        last-payment-height: (optional uint)
    }
)

(define-map borrower-scores
    { borrower: principal }
    { 
        score: uint,
        total-loans: uint,
        repaid-loans: uint
    }
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

(define-private (is-valid-status-transition (current-status (string-ascii 20)) (new-status (string-ascii 20)))
    (match current-status
        "PENDING" (or (is-eq new-status "FUNDED") (is-eq new-status "CANCELLED"))
        "FUNDED" (or (is-eq new-status "REPAYING") (is-eq new-status "DEFAULTED"))
        "REPAYING" (or (is-eq new-status "REPAID") (is-eq new-status "DEFAULTED"))
        false
    )
)

(define-private (emit-event (event-type (string-ascii 20)) (loan-id uint))
    (begin
        (var-set event-counter (+ (var-get event-counter) u1))
        (print { event-id: (var-get event-counter), type: event-type, loan-id: loan-id })
        (ok true)
    )
)

;; Public functions
(define-public (create-loan (amount uint) (interest-rate uint) (term-length uint) (collateral uint))
    (let 
        (
            (loan-id (var-get loan-counter))
        )
        (asserts! (var-get contract-enabled) (err u108))
        (asserts! (validate-loan-params amount term-length) (err u109))
        (try! (stx-transfer? collateral tx-sender (as-contract tx-sender)))
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-insert loans
            { loan-id: loan-id }
            {
                borrower: tx-sender,
                lender: none,
                amount: amount,
                collateral: collateral,
                interest-rate: interest-rate,
                term-length: term-length,
                start-height: none,
                status: "PENDING",
                amount-repaid: u0,
                last-payment-height: none
            }
        )
        (var-set loan-counter (+ loan-id u1))
        (try! (emit-event "LOAN_CREATED" loan-id))
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
        (try! (emit-event "LOAN_FUNDED" loan-id))
        (ok true)
    )
)

(define-public (repay-loan (loan-id uint) (amount uint))
    (let
        (
            (loan (unwrap! (map-get? loans { loan-id: loan-id }) err-invalid-loan))
            (total-owed (+ (get amount loan) 
                (* (get amount loan) (get interest-rate loan) (get term-length loan))))
            (current-repaid (get amount-repaid loan))
            (remaining (- total-owed current-repaid))
        )
        (asserts! (var-get contract-enabled) (err u108))
        (asserts! (is-eq (get borrower loan) tx-sender) err-invalid-loan)
        (asserts! (or (is-eq (get status loan) "FUNDED") 
                    (is-eq (get status loan) "REPAYING")) err-invalid-loan)
        (asserts! (<= amount remaining) err-amount-too-high)
        (try! (stx-transfer? amount tx-sender (unwrap! (get lender loan) err-invalid-loan)))
        
        (let ((new-amount-repaid (+ current-repaid amount))
              (new-status (if (>= new-amount-repaid total-owed) "REPAID" "REPAYING")))
            (map-set loans
                { loan-id: loan-id }
                (merge loan {
                    status: new-status,
                    amount-repaid: new-amount-repaid,
                    last-payment-height: (some block-height)
                })
            )
            (try! (emit-event "LOAN_REPAYMENT" loan-id))
            (ok true)
        )
    )
)

(define-public (claim-collateral (loan-id uint))
    (let
        (
            (loan (unwrap! (map-get? loans { loan-id: loan-id }) err-invalid-loan))
            (lender (unwrap! (get lender loan) err-invalid-loan))
        )
        (asserts! (is-eq tx-sender lender) err-owner-only)
        (asserts! (is-eq (get status loan) "DEFAULTED") err-invalid-loan)
        (try! (as-contract (stx-transfer? (get collateral loan) tx-sender lender)))
        (try! (emit-event "COLLATERAL_CLAIMED" loan-id))
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
