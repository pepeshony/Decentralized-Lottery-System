# Complete Code Reference - Player Reward History & Claim System

## Error Constants (Added)

```clarity
(define-constant ERR_PRIZE_ALREADY_CLAIMED (err u112))
(define-constant ERR_NO_PRIZE_TO_CLAIM (err u113))
```

## Data Structures (Added)

```clarity
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
```

## Read-Only Functions (Added)

```clarity
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
```

## Public Functions (Added)

```clarity
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
```

## Private Functions (Added)

```clarity
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
```

## Modified Function: draw-winner (Addition)

Added after line 311 in draw-winner:
```clarity
(map-set player-rewards {
    lottery-id: id,
    player: winner,
} {
    prize-amount: winner-prize,
    is-claimed: false,
    claim-block: u0,
})
```

## Modified Functions: buy-ticket & buy-tickets-batch (Addition)

Added before final (ok ...) in both functions:
```clarity
(update-player-history-on-purchase tx-sender ticket-cost)
```

or for batch:
```clarity
(update-player-history-on-purchase tx-sender total-cost)
```

---

## Variable Definitions

All variables are clearly defined before use:

| Variable | Type | Definition |
|----------|------|-----------|
| `reward` | map value | Unwrapped from player-rewards |
| `prize-amount` | uint | Extracted from reward |
| `is-claimed` | bool | Extracted from reward |
| `current-history` | map value | Fetched or defaulted |
| `winner` | principal | Extracted from winner-info |
| `winner-prize` | uint | Calculated from total-prize |
| `stacks-block-height` | uint | Built-in variable |
| `tx-sender` | principal | Built-in variable |

---

## Compilation Status

✅ **Result**: 1 contract checked successfully
✅ **Errors**: 0
✅ **Critical Issues**: 0
⚠️ **Warnings**: 5 (pre-existing, unrelated to new feature)

