(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_OWNER (err u100))
(define-constant ERR_LOTTERY_NOT_ACTIVE (err u101))
(define-constant ERR_LOTTERY_ACTIVE (err u102))
(define-constant ERR_INVALID_TICKET_PRICE (err u103))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u104))
(define-constant ERR_NO_TICKETS_SOLD (err u105))
(define-constant ERR_ALREADY_DRAWN (err u106))
(define-constant ERR_NOT_DRAWN (err u107))
(define-constant ERR_TRANSFER_FAILED (err u108))
(define-constant ERR_LOTTERY_NOT_ENDED (err u109))
(define-constant ERR_TOO_MANY_TICKETS (err u110))
(define-constant ERR_INVALID_DURATION (err u111))
(define-constant ERR_PRIZE_ALREADY_CLAIMED (err u112))
(define-constant ERR_NO_PRIZE_TO_CLAIM (err u113))
(define-constant ERR_TICKET_NOT_FOUND (err u114))
(define-constant ERR_NOT_TICKET_OWNER (err u115))
(define-constant ERR_CANNOT_GIFT_SELF (err u116))
(define-constant ERR_INVALID_AMOUNT (err u117))

 
(define-data-var lottery-counter uint u0)
(define-data-var ticket-price uint u1000000)
(define-data-var max-tickets-per-player uint u10)
(define-data-var owner-fee-percentage uint u5)
(define-data-var auto-schedule-enabled bool false)
(define-data-var auto-lottery-duration uint u100)
(define-data-var auto-lottery-price uint u1000000)

(define-map lotteries
    uint
    {
        start-block: uint,
        end-block: uint,
        ticket-price: uint,
        total-tickets: uint,
        total-prize: uint,
        winner: (optional principal),
        is-drawn: bool,
        is-active: bool,
    }
)

(define-map lottery-tickets
    {
        lottery-id: uint,
        ticket-number: uint,
    }
    { owner: principal }
)

(define-map player-tickets
    {
        lottery-id: uint,
        player: principal,
    }
    { ticket-count: uint }
)

(define-map lottery-participants
    {
        lottery-id: uint,
        player: principal,
    }
    { total-spent: uint }
)

(define-map player-rewards
    {
        lottery-id: uint,
        player: principal,
    }
    {
        prize-amount: uint,
        is-claimed: bool,
        claim-block: uint,
    }
)

(define-map player-history
    principal
    {
        total-lotteries-played: uint,
        total-spent: uint,
        total-won: uint,
        total-claimed: uint,
    }
)

(define-read-only (get-current-lottery-id)
    (var-get lottery-counter)
)

(define-read-only (get-lottery-info (id uint))
    (map-get? lotteries id)
)

(define-read-only (get-ticket-owner
        (id uint)
        (ticket-number uint)
    )
    (map-get? lottery-tickets {
        lottery-id: id,
        ticket-number: ticket-number,
    })
)

(define-read-only (get-player-ticket-count
        (id uint)
        (player principal)
    )
    (default-to { ticket-count: u0 }
        (map-get? player-tickets {
            lottery-id: id,
            player: player,
        })
    )
)

(define-read-only (get-player-participation
        (id uint)
        (player principal)
    )
    (map-get? lottery-participants {
        lottery-id: id,
        player: player,
    })
)

(define-read-only (get-ticket-price)
    (var-get ticket-price)
)

(define-read-only (get-max-tickets-per-player)
    (var-get max-tickets-per-player)
)

(define-read-only (get-owner-fee-percentage)
    (var-get owner-fee-percentage)
)

(define-read-only (calculate-prize-after-fee (total-prize uint))
    (let ((fee (/ (* total-prize (var-get owner-fee-percentage)) u100)))
        (- total-prize fee)
    )
)

(define-read-only (calculate-owner-fee (total-prize uint))
    (/ (* total-prize (var-get owner-fee-percentage)) u100)
)

(define-read-only (is-lottery-active (id uint))
    (match (map-get? lotteries id)
        lottery (and
            (get is-active lottery)
            (>= stacks-block-height (get start-block lottery))
            (<= stacks-block-height (get end-block lottery))
        )
        false
    )
)

(define-read-only (is-lottery-ended (id uint))
    (match (map-get? lotteries id)
        lottery (and
            (get is-active lottery)
            (> stacks-block-height (get end-block lottery))
        )
        false
    )
)

(define-public (set-ticket-price (new-price uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
        (asserts! (> new-price u0) ERR_INVALID_TICKET_PRICE)
        (var-set ticket-price new-price)
        (ok true)
    )
)

(define-public (set-max-tickets-per-player (new-max uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
        (var-set max-tickets-per-player new-max)
        (ok true)
    )
)

(define-public (set-owner-fee-percentage (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
        (asserts! (<= new-fee u20) ERR_INVALID_TICKET_PRICE)
        (var-set owner-fee-percentage new-fee)
        (ok true)
    )
)

(define-public (create-lottery (duration-blocks uint))
    (let (
            (current-id (+ (var-get lottery-counter) u1))
            (start-block stacks-block-height)
            (end-block (+ stacks-block-height duration-blocks))
        )
        (begin
            (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
            (asserts! (> duration-blocks u10) ERR_INVALID_DURATION)
            (asserts! (<= duration-blocks u1000) ERR_INVALID_DURATION)
            (map-set lotteries current-id {
                start-block: start-block,
                end-block: end-block,
                ticket-price: (var-get ticket-price),
                total-tickets: u0,
                total-prize: u0,
                winner: none,
                is-drawn: false,
                is-active: true,
            })
            (var-set lottery-counter current-id)
            (ok current-id)
        )
    )
)

(define-public (buy-ticket (id uint))
    (let (
            (lottery (unwrap! (map-get? lotteries id) ERR_LOTTERY_NOT_ACTIVE))
            (current-ticket-count (get ticket-count (get-player-ticket-count id tx-sender)))
            (ticket-cost (get ticket-price lottery))
            (new-ticket-number (+ (get total-tickets lottery) u1))
        )
        (begin
            (asserts! (is-lottery-active id) ERR_LOTTERY_NOT_ACTIVE)
            (asserts! (< current-ticket-count (var-get max-tickets-per-player))
                ERR_TOO_MANY_TICKETS
            )
            (asserts! (>= (stx-get-balance tx-sender) ticket-cost)
                ERR_INSUFFICIENT_PAYMENT
            )

            (try! (stx-transfer? ticket-cost tx-sender (as-contract tx-sender)))

            (map-set lottery-tickets {
                lottery-id: id,
                ticket-number: new-ticket-number,
            } { owner: tx-sender }
            )

            (map-set player-tickets {
                lottery-id: id,
                player: tx-sender,
            } { ticket-count: (+ current-ticket-count u1) }
            )

            (match (map-get? lottery-participants {
                lottery-id: id,
                player: tx-sender,
            })
                existing-participation (map-set lottery-participants {
                    lottery-id: id,
                    player: tx-sender,
                } { total-spent: (+ (get total-spent existing-participation) ticket-cost) }
                )
                (map-set lottery-participants {
                    lottery-id: id,
                    player: tx-sender,
                } { total-spent: ticket-cost }
                )
            )

            (map-set lotteries id
                (merge lottery {
                    total-tickets: new-ticket-number,
                    total-prize: (+ (get total-prize lottery) ticket-cost),
                })
            )

            (update-player-history-on-purchase tx-sender ticket-cost)

            (ok new-ticket-number)
        )
    )
)

 


(define-public (draw-winner (id uint))
    (let (
            (lottery (unwrap! (map-get? lotteries id) ERR_LOTTERY_NOT_ACTIVE))
            (total-tickets (get total-tickets lottery))
            (total-prize (get total-prize lottery))
            (random-seed (+ (* stacks-block-height u7) (* id u13) (* total-tickets u17)))
            (winning-ticket (+ (mod random-seed total-tickets) u1))
            (winner-info (unwrap!
                (map-get? lottery-tickets {
                    lottery-id: id,
                    ticket-number: winning-ticket,
                })
                ERR_NO_TICKETS_SOLD
            ))
            (winner (get owner winner-info))
            (owner-fee (calculate-owner-fee total-prize))
            (winner-prize (calculate-prize-after-fee total-prize))
        )
        (begin
            (asserts! (is-lottery-ended id) ERR_LOTTERY_NOT_ENDED)
            (asserts! (not (get is-drawn lottery)) ERR_ALREADY_DRAWN)
            (asserts! (> total-tickets u0) ERR_NO_TICKETS_SOLD)

            (try! (as-contract (stx-transfer? winner-prize tx-sender winner)))
            (try! (as-contract (stx-transfer? owner-fee tx-sender CONTRACT_OWNER)))

            (map-set lotteries id
                (merge lottery {
                    winner: (some winner),
                    is-drawn: true,
                })
            )

            (map-set player-rewards {
                lottery-id: id,
                player: winner,
            } {
                prize-amount: winner-prize,
                is-claimed: false,
                claim-block: u0,
            })

            (if (var-get auto-schedule-enabled)
                (unwrap-panic (create-next-auto-lottery))
                u0
            )

            (ok {
                winner: winner,
                prize: winner-prize,
                winning-ticket: winning-ticket,
            })
        )
    )
)

(define-private (create-next-auto-lottery)
    (let (
            (current-id (+ (var-get lottery-counter) u1))
            (start-block stacks-block-height)
            (end-block (+ stacks-block-height (var-get auto-lottery-duration)))
        )
        (begin
            (map-set lotteries current-id {
                start-block: start-block,
                end-block: end-block,
                ticket-price: (var-get auto-lottery-price),
                total-tickets: u0,
                total-prize: u0,
                winner: none,
                is-drawn: false,
                is-active: true,
            })
            (var-set lottery-counter current-id)
            (ok current-id)
        )
    )
)

(define-public (configure-auto-scheduling
        (enabled bool)
        (duration uint)
        (price uint)
    )
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
        (asserts! (> duration u10) ERR_INVALID_DURATION)
        (asserts! (<= duration u1000) ERR_INVALID_DURATION)
        (asserts! (> price u0) ERR_INVALID_TICKET_PRICE)
        (var-set auto-schedule-enabled enabled)
        (var-set auto-lottery-duration duration)
        (var-set auto-lottery-price price)
        (ok {
            enabled: enabled,
            duration: duration,
            price: price,
        })
    )
)

(define-public (toggle-auto-scheduling)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
        (var-set auto-schedule-enabled (not (var-get auto-schedule-enabled)))
        (ok (var-get auto-schedule-enabled))
    )
)

(define-read-only (get-auto-schedule-config)
    (ok {
        enabled: (var-get auto-schedule-enabled),
        duration: (var-get auto-lottery-duration),
        price: (var-get auto-lottery-price),
    })
)

(define-public (close-lottery (id uint))
    (let ((lottery (unwrap! (map-get? lotteries id) ERR_LOTTERY_NOT_ACTIVE)))
        (begin
            (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
            (asserts! (get is-active lottery) ERR_LOTTERY_NOT_ACTIVE)

            (map-set lotteries id (merge lottery { is-active: false }))

            (ok true)
        )
    )
)

(define-public (emergency-withdraw (id uint))
    (let (
            (lottery (unwrap! (map-get? lotteries id) ERR_LOTTERY_NOT_ACTIVE))
            (total-prize (get total-prize lottery))
        )
        (begin
            (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
            (asserts! (not (get is-drawn lottery)) ERR_ALREADY_DRAWN)

            (try! (as-contract (stx-transfer? total-prize tx-sender CONTRACT_OWNER)))

            (map-set lotteries id
                (merge lottery {
                    is-active: false,
                    is-drawn: true,
                })
            )

            (ok total-prize)
        )
    )
)

(define-read-only (get-random-number-for-lottery (id uint))
    (let (
            (lottery (unwrap! (map-get? lotteries id) ERR_LOTTERY_NOT_ACTIVE))
            (end-block (get end-block lottery))
            (total-tickets (get total-tickets lottery))
            (random-seed (+ (* end-block u7) (* id u13) (* total-tickets u17)))
        )
        (if (> total-tickets u0)
            (ok (+ (mod random-seed total-tickets) u1))
            ERR_NO_TICKETS_SOLD
        )
    )
)

(define-read-only (get-lottery-stats (id uint))
    (match (map-get? lotteries id)
        lottery (ok {
            id: id,
            start-block: (get start-block lottery),
            end-block: (get end-block lottery),
            ticket-price: (get ticket-price lottery),
            total-tickets: (get total-tickets lottery),
            total-prize: (get total-prize lottery),
            winner: (get winner lottery),
            is-drawn: (get is-drawn lottery),
            is-active: (get is-active lottery),
            blocks-remaining: (if (> (get end-block lottery) stacks-block-height)
                (- (get end-block lottery) stacks-block-height)
                u0
            ),
            prize-after-fee: (calculate-prize-after-fee (get total-prize lottery)),
        })
        ERR_LOTTERY_NOT_ACTIVE
    )
)

(define-read-only (get-lottery-revenue (id uint))
    (match (map-get? lotteries id)
        lottery (ok {
            total-revenue: (get total-prize lottery),
            owner-fee: (calculate-owner-fee (get total-prize lottery)),
            winner-prize: (calculate-prize-after-fee (get total-prize lottery)),
        })
        ERR_LOTTERY_NOT_ACTIVE
    )
)

(define-public (get-contract-balance)
    (ok (stx-get-balance (as-contract tx-sender)))
)

(define-read-only (predict-winner (id uint))
    (match (map-get? lotteries id)
        lottery (if (and (is-lottery-ended id) (not (get is-drawn lottery)))
            (let (
                    (total-tickets (get total-tickets lottery))
                    (end-block (get end-block lottery))
                    (random-seed (+ (* end-block u7) (* id u13) (* total-tickets u17)))
                    (winning-ticket (+ (mod random-seed total-tickets) u1))
                )
                (if (> total-tickets u0)
                    (ok {
                        winning-ticket: winning-ticket,
                        can-draw: true,
                    })
                    ERR_NO_TICKETS_SOLD
                )
            )
            (ok {
                winning-ticket: u0,
                can-draw: false,
            })
        )
        ERR_LOTTERY_NOT_ACTIVE
    )
)

(define-read-only (can-buy-more-tickets
        (id uint)
        (player principal)
    )
    (let (
            (current-count (get ticket-count (get-player-ticket-count id player)))
            (max-allowed (var-get max-tickets-per-player))
        )
        (ok {
            can-buy: (< current-count max-allowed),
            remaining-tickets: (- max-allowed current-count),
            current-tickets: current-count,
        })
    )
)

(define-read-only (estimate-lottery-end-time (id uint))
    (match (map-get? lotteries id)
        lottery (ok {
            end-block: (get end-block lottery),
            current-block: stacks-block-height,
            blocks-remaining: (if (> (get end-block lottery) stacks-block-height)
                (- (get end-block lottery) stacks-block-height)
                u0
            ),
            is-ended: (> stacks-block-height (get end-block lottery)),
        })
        ERR_LOTTERY_NOT_ACTIVE
    )
)

(define-read-only (get-lottery-summary)
    (let ((current-id (var-get lottery-counter)))
        (ok {
            total-lotteries: current-id,
            current-ticket-price: (var-get ticket-price),
            max-tickets-per-player: (var-get max-tickets-per-player),
            owner-fee-percentage: (var-get owner-fee-percentage),
            contract-balance: (stx-get-balance (as-contract tx-sender)),
            auto-schedule-enabled: (var-get auto-schedule-enabled),
            auto-lottery-duration: (var-get auto-lottery-duration),
            auto-lottery-price: (var-get auto-lottery-price),
        })
    )
)

(define-read-only (get-next-scheduled-lottery)
    (if (var-get auto-schedule-enabled)
        (let ((current-id (var-get lottery-counter)))
            (match (map-get? lotteries current-id)
                current-lottery (if (and (is-lottery-ended current-id) (get is-drawn current-lottery))
                    (ok {
                        will-auto-create: true,
                        next-id: (+ current-id u1),
                        duration: (var-get auto-lottery-duration),
                        price: (var-get auto-lottery-price),
                        starts-when: "after-current-lottery-ends",
                    })
                    (ok {
                        will-auto-create: true,
                        next-id: (+ current-id u1),
                        duration: (var-get auto-lottery-duration),
                        price: (var-get auto-lottery-price),
                        starts-when: "after-current-lottery-winner-drawn",
                    })
                )
                (ok {
                    will-auto-create: true,
                    next-id: u1,
                    duration: (var-get auto-lottery-duration),
                    price: (var-get auto-lottery-price),
                    starts-when: "immediately",
                })
            )
        )
        (ok {
            will-auto-create: false,
            next-id: u0,
            duration: u0,
            price: u0,
            starts-when: "manual-creation-required",
        })
    )
)

(define-read-only (check-ticket-ownership
        (id uint)
        (ticket-number uint)
        (player principal)
    )
    (match (map-get? lottery-tickets {
        lottery-id: id,
        ticket-number: ticket-number,
    })
        ticket-info (is-eq (get owner ticket-info) player)
        false
    )
)

(define-read-only (get-player-total-spent
        (id uint)
        (player principal)
    )
    (match (map-get? lottery-participants {
        lottery-id: id,
        player: player,
    })
        participation (get total-spent participation)
        u0
    )
)

(define-read-only (calculate-win-probability
        (id uint)
        (player principal)
    )
    (match (map-get? lotteries id)
        lottery (let (
                (player-count (get ticket-count (get-player-ticket-count id player)))
                (total-tickets (get total-tickets lottery))
            )
            (if (> total-tickets u0)
                (ok {
                    player-tickets: player-count,
                    total-tickets: total-tickets,
                    probability-numerator: player-count,
                })
                ERR_NO_TICKETS_SOLD
            )
        )
        ERR_LOTTERY_NOT_ACTIVE
    )
)

(define-read-only (validate-lottery-params
        (duration uint)
        (price uint)
    )
    (ok {
        duration-valid: (and (> duration u10) (<= duration u1000)),
        price-valid: (> price u0),
        all-valid: (and
            (> duration u10)
            (<= duration u1000)
            (> price u0)
        ),
    })
)

(define-public (create-custom-lottery
        (duration-blocks uint)
        (custom-ticket-price uint)
    )
    (let (
            (current-id (+ (var-get lottery-counter) u1))
            (start-block stacks-block-height)
            (end-block (+ stacks-block-height duration-blocks))
        )
        (begin
            (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
            (asserts! (> duration-blocks u10) ERR_INVALID_DURATION)
            (asserts! (<= duration-blocks u1000) ERR_INVALID_DURATION)
            (asserts! (> custom-ticket-price u0) ERR_INVALID_TICKET_PRICE)

            (map-set lotteries current-id {
                start-block: start-block,
                end-block: end-block,
                ticket-price: custom-ticket-price,
                total-tickets: u0,
                total-prize: u0,
                winner: none,
                is-drawn: false,
                is-active: true,
            })
            (var-set lottery-counter current-id)
            (ok current-id)
        )
    )
)

(define-read-only (get-lottery-status (id uint))
    (match (map-get? lotteries id)
        lottery (ok {
            is-active: (is-lottery-active id),
            is-ended: (is-lottery-ended id),
            is-drawn: (get is-drawn lottery),
            can-draw: (and
                (is-lottery-ended id)
                (not (get is-drawn lottery))
                (> (get total-tickets lottery) u0)
            ),
        })
        ERR_LOTTERY_NOT_ACTIVE
    )
)

(define-read-only (get-total-prize-info (id uint))
    (match (map-get? lotteries id)
        lottery (let ((total-prize (get total-prize lottery)))
            (ok {
                total-collected: total-prize,
                owner-fee: (calculate-owner-fee total-prize),
                winner-prize: (calculate-prize-after-fee total-prize),
                fee-percentage: (var-get owner-fee-percentage),
            })
        )
        ERR_LOTTERY_NOT_ACTIVE
    )
)

(define-read-only (get-ticket-range-info
        (id uint)
        (start-ticket uint)
        (end-ticket uint)
    )
    (ok {
        lottery-id: id,
        start-ticket: start-ticket,
        end-ticket: end-ticket,
        range-size: (if (>= end-ticket start-ticket)
            (+ (- end-ticket start-ticket) u1)
            u0
        ),
    })
)

(define-public (refund-emergency
        (id uint)
        (player principal)
    )
    (let (
            (lottery (unwrap! (map-get? lotteries id) ERR_LOTTERY_NOT_ACTIVE))
            (participation (unwrap!
                (map-get? lottery-participants {
                    lottery-id: id,
                    player: player,
                })
                ERR_NOT_DRAWN
            ))
            (refund-amount (get total-spent participation))
        )
        (begin
            (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
            (asserts! (not (get is-drawn lottery)) ERR_ALREADY_DRAWN)
            (asserts! (not (get is-active lottery)) ERR_LOTTERY_ACTIVE)

            (try! (as-contract (stx-transfer? refund-amount tx-sender player)))

            (map-delete lottery-participants {
                lottery-id: id,
                player: player,
            })
            (map-delete player-tickets {
                lottery-id: id,
                player: player,
            })

            (ok refund-amount)
        )
    )
)

(define-read-only (is-owner (caller principal))
    (is-eq caller CONTRACT_OWNER)
)

(define-read-only (get-contract-info)
    (ok {
        owner: CONTRACT_OWNER,
        total-lotteries: (var-get lottery-counter),
        default-ticket-price: (var-get ticket-price),
        max-tickets-per-player: (var-get max-tickets-per-player),
        owner-fee-percentage: (var-get owner-fee-percentage),
    })
)

(define-read-only (calculate-ticket-cost
        (id uint)
        (quantity uint)
    )
    (match (map-get? lotteries id)
        lottery (ok (* (get ticket-price lottery) quantity))
        ERR_LOTTERY_NOT_ACTIVE
    )
)

(define-read-only (get-player-reward
        (id uint)
        (player principal)
    )
    (map-get? player-rewards {
        lottery-id: id,
        player: player,
    })
)

(define-read-only (get-player-history (player principal))
    (match (map-get? player-history player)
        history (ok history)
        (ok {
            total-lotteries-played: u0,
            total-spent: u0,
            total-won: u0,
            total-claimed: u0,
        })
    )
)

(define-read-only (is-prize-claimed
        (id uint)
        (player principal)
    )
    (match (map-get? player-rewards {
        lottery-id: id,
        player: player,
    })
        reward (get is-claimed reward)
        false
    )
)

(define-read-only (get-winner-info (id uint))
    (match (map-get? lotteries id)
        lottery (if (get is-drawn lottery)
            (ok {
                winner: (get winner lottery),
                winning-ticket: u0,
                prize-amount: (calculate-prize-after-fee (get total-prize lottery)),
                total-tickets: (get total-tickets lottery),
            })
            ERR_NOT_DRAWN
        )
        ERR_LOTTERY_NOT_ACTIVE
    )
)

(define-public (buy-tickets-batch
        (id uint)
        (tickets-to-buy uint)
    )
    (let (
            (lottery (unwrap! (map-get? lotteries id) ERR_LOTTERY_NOT_ACTIVE))
            (current-count (get ticket-count (get-player-ticket-count id tx-sender)))
            (total-cost (* (get ticket-price lottery) tickets-to-buy))
        )
        (begin
            (asserts! (is-lottery-active id) ERR_LOTTERY_NOT_ACTIVE)
            (asserts!
                (<= (+ current-count tickets-to-buy)
                    (var-get max-tickets-per-player)
                )
                ERR_TOO_MANY_TICKETS
            )
            (asserts! (> tickets-to-buy u0) ERR_INVALID_TICKET_PRICE)
            (asserts! (<= tickets-to-buy u10) ERR_INVALID_TICKET_PRICE)
            (asserts! (>= (stx-get-balance tx-sender) total-cost)
                ERR_INSUFFICIENT_PAYMENT
            )

            (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))

            (map-set player-tickets {
                lottery-id: id,
                player: tx-sender,
            } { ticket-count: (+ current-count tickets-to-buy) }
            )

            (match (map-get? lottery-participants {
                lottery-id: id,
                player: tx-sender,
            })
                existing-participation (map-set lottery-participants {
                    lottery-id: id,
                    player: tx-sender,
                } { total-spent: (+ (get total-spent existing-participation) total-cost) }
                )
                (map-set lottery-participants {
                    lottery-id: id,
                    player: tx-sender,
                } { total-spent: total-cost }
                )
            )

            (map-set lotteries id
                (merge lottery {
                    total-tickets: (+ (get total-tickets lottery) tickets-to-buy),
                    total-prize: (+ (get total-prize lottery) total-cost),
                })
            )

            (update-player-history-on-purchase tx-sender total-cost)

            (ok tickets-to-buy)
        )
    )
)

(define-public (gift-ticket (id uint) (recipient principal))
    (let (
            (lottery (unwrap! (map-get? lotteries id) ERR_LOTTERY_NOT_ACTIVE))
            (current-ticket-count (get ticket-count (get-player-ticket-count id recipient)))
            (ticket-cost (get ticket-price lottery))
            (new-ticket-number (+ (get total-tickets lottery) u1))
        )
        (begin
            (asserts! (is-lottery-active id) ERR_LOTTERY_NOT_ACTIVE)
            (asserts! (not (is-eq tx-sender recipient)) ERR_CANNOT_GIFT_SELF)
            (asserts! (< current-ticket-count (var-get max-tickets-per-player))
                ERR_TOO_MANY_TICKETS
            )
            (asserts! (>= (stx-get-balance tx-sender) ticket-cost)
                ERR_INSUFFICIENT_PAYMENT
            )

            (try! (stx-transfer? ticket-cost tx-sender (as-contract tx-sender)))

            (map-set lottery-tickets {
                lottery-id: id,
                ticket-number: new-ticket-number,
            } { owner: recipient }
            )

            (map-set player-tickets {
                lottery-id: id,
                player: recipient,
            } { ticket-count: (+ current-ticket-count u1) }
            )

            (match (map-get? lottery-participants {
                lottery-id: id,
                player: recipient,
            })
                existing-participation (map-set lottery-participants {
                    lottery-id: id,
                    player: recipient,
                } { total-spent: (+ (get total-spent existing-participation) ticket-cost) }
                )
                (map-set lottery-participants {
                    lottery-id: id,
                    player: recipient,
                } { total-spent: ticket-cost }
                )
            )

            (map-set lotteries id
                (merge lottery {
                    total-tickets: new-ticket-number,
                    total-prize: (+ (get total-prize lottery) ticket-cost),
                })
            )

            (update-player-history-on-purchase tx-sender ticket-cost)

            (ok new-ticket-number)
        )
    )
)

(define-public (sponsor-lottery (id uint) (amount uint))
    (let (
            (lottery (unwrap! (map-get? lotteries id) ERR_LOTTERY_NOT_ACTIVE))
        )
        (begin
            (asserts! (is-lottery-active id) ERR_LOTTERY_NOT_ACTIVE)
            (asserts! (> amount u0) ERR_INVALID_AMOUNT)
            (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
            (map-set lotteries id
                (merge lottery {
                    total-prize: (+ (get total-prize lottery) amount)
                })
            )
            (update-player-history-on-purchase tx-sender amount)
            (ok true)
        )
    )
)

(define-public (claim-prize (id uint))
    (let (
            (reward (unwrap! (map-get? player-rewards {
                lottery-id: id,
                player: tx-sender,
            }) ERR_NO_PRIZE_TO_CLAIM))
            (prize-amount (get prize-amount reward))
            (is-claimed (get is-claimed reward))
            (current-history (match (map-get? player-history tx-sender)
                history history
                {
                    total-lotteries-played: u0,
                    total-spent: u0,
                    total-won: u0,
                    total-claimed: u0,
                }
            ))
        )
        (begin
            (asserts! (not is-claimed) ERR_PRIZE_ALREADY_CLAIMED)
            (asserts! (> prize-amount u0) ERR_NO_PRIZE_TO_CLAIM)

            (try! (as-contract (stx-transfer? prize-amount tx-sender tx-sender)))

            (map-set player-rewards {
                lottery-id: id,
                player: tx-sender,
            } {
                prize-amount: prize-amount,
                is-claimed: true,
                claim-block: stacks-block-height,
            })

            (map-set player-history tx-sender {
                total-lotteries-played: (get total-lotteries-played current-history),
                total-spent: (get total-spent current-history),
                total-won: (+ (get total-won current-history) prize-amount),
                total-claimed: (+ (get total-claimed current-history) prize-amount),
            })

            (ok {
                claimed-amount: prize-amount,
                claim-block: stacks-block-height,
            })
        )
    )
)

(define-public (claim-prize-to
        (id uint)
        (to principal)
    )
    (let (
            (reward (unwrap! (map-get? player-rewards {
                lottery-id: id,
                player: tx-sender,
            }) ERR_NO_PRIZE_TO_CLAIM))
            (prize-amount (get prize-amount reward))
            (is-claimed (get is-claimed reward))
            (current-history (match (map-get? player-history tx-sender)
                history history
                {
                    total-lotteries-played: u0,
                    total-spent: u0,
                    total-won: u0,
                    total-claimed: u0,
                }
            ))
        )
        (begin
            (asserts! (not is-claimed) ERR_PRIZE_ALREADY_CLAIMED)
            (asserts! (> prize-amount u0) ERR_NO_PRIZE_TO_CLAIM)
            (try! (as-contract (stx-transfer? prize-amount tx-sender to)))
            (map-set player-rewards {
                lottery-id: id,
                player: tx-sender,
            } {
                prize-amount: prize-amount,
                is-claimed: true,
                claim-block: stacks-block-height,
            })
            (map-set player-history tx-sender {
                total-lotteries-played: (get total-lotteries-played current-history),
                total-spent: (get total-spent current-history),
                total-won: (+ (get total-won current-history) prize-amount),
                total-claimed: (+ (get total-claimed current-history) prize-amount),
            })
            (ok {
                claimed-amount: prize-amount,
                claim-block: stacks-block-height,
            })
        )
    )
)
(define-private (update-player-history-on-purchase
        (player principal)
        (amount uint)
    )
    (let (
            (current-history (match (map-get? player-history player)
                history history
                {
                    total-lotteries-played: u0,
                    total-spent: u0,
                    total-won: u0,
                    total-claimed: u0,
                }
            ))
        )
        (map-set player-history player {
            total-lotteries-played: (get total-lotteries-played current-history),
            total-spent: (+ (get total-spent current-history) amount),
            total-won: (get total-won current-history),
            total-claimed: (get total-claimed current-history),
        })
    )
)
