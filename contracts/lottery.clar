;; Decentralized Lottery MVP
;; A simple lottery contract where players buy tickets and a random winner is selected.

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant APP-ERR-NOT-ENOUGH-FUNDS (err u100))
(define-constant APP-ERR-ROUND-OPEN (err u101))
(define-constant APP-ERR-ROUND-CLOSED (err u102))
(define-constant APP-ERR-ROUND-NOT-OVER (err u103))
(define-constant APP-ERR-NO-TICKETS-SOLD (err u104))
(define-constant APP-ERR-UNAUTHORIZED (err u105))
(define-constant APP-ERR-NOT-WINNER (err u106))
(define-constant APP-ERR-PRIZE-ALREADY-CLAIMED (err u107))
(define-constant APP-ERR-INVALID-TICKET (err u108))

;; Data Variables
(define-data-var ticket-cost uint u100)
(define-data-var round-length uint u10)
(define-data-var game-round uint u1)
(define-data-var pot-size uint u0)
(define-data-var round-start-block uint stacks-block-height)
(define-data-var current-ticket-id uint u0)

;; Maps
(define-map tickets
    {
        round: uint,
        id: uint,
    }
    principal
)

(define-map rounds
    uint
    {
        winner: (optional principal),
        total-tickets: uint,
        pot: uint,
        is-open: bool,
        is-claimed: bool,
    }
)

;; Read-Only Functions

(define-read-only (get-ticket-cost)
    (ok (var-get ticket-cost))
)

(define-read-only (get-round-length)
    (ok (var-get round-length))
)

(define-read-only (get-current-round)
    (ok (var-get game-round))
)

(define-read-only (get-current-pot)
    (ok (var-get pot-size))
)

(define-read-only (get-ticket-owner
        (round uint)
        (id uint)
    )
    (map-get? tickets {
        round: round,
        id: id,
    })
)

(define-read-only (get-round-info (round uint))
    (map-get? rounds round)
)

(define-read-only (get-total-tickets-in-round (round uint))
    (match (map-get? rounds round)
        round-data (ok (get total-tickets round-data))
        (err u0)
    )
)

(define-read-only (get-time-remaining)
    (let ((end-block (+ (var-get round-start-block) (var-get round-length))))
        (if (< stacks-block-height end-block)
            (ok (- end-block stacks-block-height))
            (ok u0)
        )
    )
)

;; private functions

(define-private (get-random-uint (max-val uint))
    ;; Simple block-height based randomness for MVP
    (let ((random-val (+ stacks-block-height u12345)))
        (mod random-val max-val)
    )
)

;; Public Functions

(define-public (buy-ticket)
    (let (
            (current-round (var-get game-round))
            (cost (var-get ticket-cost))
            (buyer tx-sender)
            (new-ticket-id (+ (var-get current-ticket-id) u1))
        )
        ;; Assert that the transfer is successful
        (try! (stx-transfer? cost buyer (as-contract tx-sender)))

        ;; Map set for the new ticket
        (map-set tickets {
            round: current-round,
            id: new-ticket-id,
        }
            buyer
        )

        ;; Update global state
        (var-set pot-size (+ (var-get pot-size) cost))
        (var-set current-ticket-id new-ticket-id)

        (print {
            event: "ticket-bought",
            round: current-round,
            buyer: buyer,
            ticket-id: new-ticket-id,
        })
        (ok new-ticket-id)
    )
)

(define-public (close-round)
    (let (
            (current-round (var-get game-round))
            (start-block (var-get round-start-block))
            (duration (var-get round-length))
            (total-tickets (var-get current-ticket-id))
            (current-pot (var-get pot-size))
        )
        ;; Assert round duration has passed
        (asserts! (>= stacks-block-height (+ start-block duration))
            APP-ERR-ROUND-NOT-OVER
        )

        ;; Assert tickets were sold
        (asserts! (> total-tickets u0) APP-ERR-NO-TICKETS-SOLD)

        (let (
                (winning-ticket-index (+ (get-random-uint total-tickets) u1))
                (winner (unwrap!
                    (map-get? tickets {
                        round: current-round,
                        id: winning-ticket-index,
                    })
                    APP-ERR-INVALID-TICKET
                ))
            )
            ;; Archive round info
            (map-set rounds current-round {
                winner: (some winner),
                total-tickets: total-tickets,
                pot: current-pot,
                is-open: false,
                is-claimed: false,
            })

            (print {
                event: "round-ended",
                round: current-round,
                winner: winner,
                pot: current-pot,
            })

            ;; Reset for next round
            (var-set game-round (+ current-round u1))
            (var-set pot-size u0)
            (var-set current-ticket-id u0)
            (var-set round-start-block stacks-block-height)

            (ok winner)
        )
    )
)

(define-public (claim-prize (round uint))
    (let (
            (round-data (unwrap! (map-get? rounds round) APP-ERR-ROUND-OPEN))
            (winner (unwrap! (get winner round-data) APP-ERR-NOT-WINNER))
            (pot (get pot round-data))
            (is-claimed (get is-claimed round-data))
        )
        ;; Assert caller is winner
        (asserts! (is-eq tx-sender winner) APP-ERR-UNAUTHORIZED)

        ;; Assert not already claimed
        (asserts! (not is-claimed) APP-ERR-PRIZE-ALREADY-CLAIMED)

        ;; Transfer pot to winner
        (try! (as-contract (stx-transfer? pot tx-sender winner)))

        ;; Update round state to claimed
        (map-set rounds round (merge round-data { is-claimed: true }))

        (print {
            event: "prize-claimed",
            round: round,
            winner: winner,
            amount: pot,
        })
        (ok true)
    )
)

(define-public (extend-round (blocks uint))
    (let ((current-end (+ (var-get round-start-block) (var-get round-length))))
        (asserts! (is-eq tx-sender CONTRACT-OWNER) APP-ERR-UNAUTHORIZED)
        (var-set round-length (+ (var-get round-length) blocks))
        (ok (var-get round-length))
    )
)

(define-public (force-reset-round)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) APP-ERR-UNAUTHORIZED)
        (var-set round-start-block stacks-block-height)
        (ok true)
    )
)
