# Player Reward History & Claim System - Architecture

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    LOTTERY SYSTEM                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │           PLAYER REWARD HISTORY SYSTEM                   │   │
│  │                                                           │   │
│  │  ┌─────────────────────────────────────────────────┐    │   │
│  │  │  Data Layer                                     │    │   │
│  │  │  ├─ player-rewards map                          │    │   │
│  │  │  │  └─ {lottery-id, player} → {prize, claimed} │    │   │
│  │  │  └─ player-history map                          │    │   │
│  │  │     └─ player → {spent, won, claimed}           │    │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  │                                                           │   │
│  │  ┌─────────────────────────────────────────────────┐    │   │
│  │  │  Function Layer                                 │    │   │
│  │  │  ├─ Public: claim-prize()                       │    │   │
│  │  │  ├─ Read-Only: get-player-reward()              │    │   │
│  │  │  ├─ Read-Only: get-player-history()             │    │   │
│  │  │  ├─ Read-Only: is-prize-claimed()               │    │   │
│  │  │  └─ Private: update-player-history-on-purchase()│   │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  │                                                           │   │
│  │  ┌─────────────────────────────────────────────────┐    │   │
│  │  │  Integration Points                             │    │   │
│  │  │  ├─ draw-winner() → records prize               │    │   │
│  │  │  ├─ buy-ticket() → updates history              │    │   │
│  │  │  └─ buy-tickets-batch() → updates history       │    │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  │                                                           │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow Diagram

```
TICKET PURCHASE FLOW:
═════════════════════

Player
  │
  ├─→ buy-ticket() or buy-tickets-batch()
  │
  ├─→ Validate lottery & balance
  │
  ├─→ Transfer STX to contract
  │
  ├─→ Update lottery-tickets map
  │
  ├─→ Update player-tickets map
  │
  ├─→ Update lottery-participants map
  │
  ├─→ Update lotteries map
  │
  └─→ update-player-history-on-purchase()
      │
      └─→ player-history map updated
          ├─ total-spent += amount
          └─ (other fields preserved)


PRIZE CLAIM FLOW:
═════════════════

Winner
  │
  ├─→ claim-prize(lottery-id)
  │
  ├─→ Lookup player-rewards map
  │
  ├─→ Validate prize exists
  │
  ├─→ Validate not already claimed
  │
  ├─→ Transfer prize to winner
  │
  ├─→ Update player-rewards map
  │   └─ is-claimed = true
  │   └─ claim-block = current block
  │
  └─→ Update player-history map
      ├─ total-won += prize-amount
      └─ total-claimed += prize-amount


WINNER DRAW FLOW:
═════════════════

draw-winner()
  │
  ├─→ Validate lottery ended
  │
  ├─→ Calculate winning ticket
  │
  ├─→ Lookup winner from lottery-tickets
  │
  ├─→ Calculate prize (after fee)
  │
  ├─→ Transfer prize to winner
  │
  ├─→ Transfer fee to owner
  │
  ├─→ Update lotteries map
  │   └─ winner = winner address
  │   └─ is-drawn = true
  │
  └─→ Create player-rewards entry
      ├─ prize-amount = calculated prize
      ├─ is-claimed = false
      └─ claim-block = 0
```

## State Transitions

```
PRIZE STATE MACHINE:
════════════════════

┌─────────────────────────────────────────────────────────┐
│                                                         │
│  [LOTTERY RUNNING]                                      │
│  ├─ Players buy tickets                                │
│  ├─ player-history updated                             │
│  └─ No prizes yet                                       │
│                                                         │
│         │                                               │
│         ↓                                               │
│                                                         │
│  [LOTTERY ENDED]                                        │
│  ├─ No more ticket sales                               │
│  ├─ Ready for draw                                      │
│  └─ No prizes yet                                       │
│                                                         │
│         │                                               │
│         ↓                                               │
│                                                         │
│  [WINNER DRAWN]                                         │
│  ├─ Winner determined                                   │
│  ├─ Prize recorded in player-rewards                   │
│  ├─ is-claimed = false                                 │
│  └─ claim-block = 0                                    │
│                                                         │
│         │                                               │
│         ↓                                               │
│                                                         │
│  [PRIZE CLAIMED]                                        │
│  ├─ Winner calls claim-prize()                          │
│  ├─ Prize transferred to winner                         │
│  ├─ is-claimed = true                                  │
│  ├─ claim-block = current block                         │
│  └─ player-history updated                             │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Error Handling

```
ERROR CODES:
════════════

ERR_PRIZE_ALREADY_CLAIMED (u112)
  └─ Triggered when: Player tries to claim same prize twice
  └─ Handled in: claim-prize()

ERR_NO_PRIZE_TO_CLAIM (u113)
  └─ Triggered when: No prize exists for player in lottery
  └─ Handled in: claim-prize()
```

## Integration Points

```
EXISTING FUNCTIONS MODIFIED:
═════════════════════════════

1. draw-winner()
   ├─ Added: player-rewards map entry creation
   ├─ When: After winner is determined
   └─ Effect: Records prize for future claiming

2. buy-ticket()
   ├─ Added: update-player-history-on-purchase() call
   ├─ When: After ticket is purchased
   └─ Effect: Updates player spending history

3. buy-tickets-batch()
   ├─ Added: update-player-history-on-purchase() call
   ├─ When: After batch tickets are purchased
   └─ Effect: Updates player spending history
```

## Performance Characteristics

```
OPERATION COMPLEXITY:
═════════════════════

claim-prize()
  ├─ Map lookup: O(1)
  ├─ Validation: O(1)
  ├─ STX transfer: O(1)
  ├─ Map updates: O(1)
  └─ Total: O(1)

get-player-history()
  ├─ Map lookup: O(1)
  └─ Total: O(1)

get-player-reward()
  ├─ Map lookup: O(1)
  └─ Total: O(1)

update-player-history-on-purchase()
  ├─ Map lookup: O(1)
  ├─ Arithmetic: O(1)
  ├─ Map update: O(1)
  └─ Total: O(1)
```

## Storage Requirements

```
STORAGE ANALYSIS:
═════════════════

player-rewards map:
  ├─ Key size: 32 bytes (lottery-id) + 20 bytes (principal) = 52 bytes
  ├─ Value size: 16 bytes (uint) + 1 byte (bool) + 16 bytes (uint) = 33 bytes
  ├─ Per entry: ~85 bytes
  └─ Scales with: Number of winners

player-history map:
  ├─ Key size: 20 bytes (principal)
  ├─ Value size: 16 + 16 + 16 + 16 = 64 bytes
  ├─ Per entry: ~84 bytes
  └─ Scales with: Number of unique players
```

## Security Considerations

```
VALIDATION CHECKS:
══════════════════

claim-prize():
  ├─ ✓ Prize must exist (ERR_NO_PRIZE_TO_CLAIM)
  ├─ ✓ Prize must not be claimed (ERR_PRIZE_ALREADY_CLAIMED)
  ├─ ✓ Prize amount must be > 0
  ├─ ✓ Caller must be tx-sender (implicit)
  └─ ✓ STX transfer must succeed

update-player-history-on-purchase():
  ├─ ✓ Player address validated
  ├─ ✓ Amount is uint (non-negative)
  └─ ✓ Arithmetic overflow protected by Clarity
```

