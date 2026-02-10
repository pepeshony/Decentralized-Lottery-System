# Player Reward History & Claim System

## Feature Overview

A comprehensive player reward tracking and prize claim system that enables players to:
- Track all participation history across multiple lotteries
- Claim unclaimed prizes from past lotteries
- View comprehensive statistics on player performance
- Access transparent historical data on winnings and spending

## Value Proposition

- **Improved UX**: Players can discover and claim forgotten prizes
- **Transparency**: Complete audit trail of player participation and winnings
- **Safety**: Prevents loss of prizes due to forgotten lottery IDs
- **Analytics**: Enables better engagement metrics and player insights
- **Accountability**: Immutable record of all transactions and claims

## Implementation Details

### New Data Structures

#### player-rewards Map
Tracks prize information for each lottery winner:
```clarity
{
    lottery-id: uint,
    player: principal,
}
→ {
    prize-amount: uint,
    is-claimed: bool,
    claim-block: uint,
}
```

#### player-history Map
Maintains cumulative statistics per player:
```clarity
principal
→ {
    total-lotteries-played: uint,
    total-spent: uint,
    total-won: uint,
    total-claimed: uint,
}
```

### New Error Constants

- `ERR_PRIZE_ALREADY_CLAIMED (u112)`: Prize has been claimed
- `ERR_NO_PRIZE_TO_CLAIM (u113)`: No prize available for claiming

### New Public Functions

#### claim-prize (id: uint)
Allows winners to claim their prizes from past lotteries.

**Parameters:**
- `id`: Lottery ID

**Returns:**
- `claimed-amount`: Amount transferred to player
- `claim-block`: Block height when claimed

**Validations:**
- Prize must exist for caller
- Prize must not be already claimed
- Prize amount must be greater than zero

### New Read-Only Functions

#### get-player-reward (id: uint, player: principal)
Retrieves reward information for a specific lottery and player.

#### get-player-history (player: principal)
Returns complete participation history for a player including:
- Total lotteries played
- Total amount spent
- Total amount won
- Total amount claimed

#### is-prize-claimed (id: uint, player: principal)
Checks if a prize has been claimed for a specific lottery.

### New Private Functions

#### update-player-history-on-purchase (player: principal, amount: uint)
Updates player history when tickets are purchased. Called automatically by:
- `buy-ticket`
- `buy-tickets-batch`

## Integration Points

### Modified Functions

1. **draw-winner**: Now records prize in `player-rewards` map when winner is drawn
2. **buy-ticket**: Calls `update-player-history-on-purchase` to track spending
3. **buy-tickets-batch**: Calls `update-player-history-on-purchase` to track spending

## Usage Examples

### Claiming a Prize
```clarity
(claim-prize u1)
```

### Checking Player History
```clarity
(get-player-history 'SP2JXKMH002PrL87Cz1gx3wXWvzJX7Z1nrDgF4SVe)
```

### Verifying Prize Status
```clarity
(is-prize-claimed u1 'SP2JXKMH002PrL87Cz1gx3wXWvzJX7Z1nrDgF4SVe)
```

## Compilation Status

✅ Contract compiles successfully with `clarinet check`
✅ No critical errors
✅ 5 pre-existing warnings (unrelated to new feature)

## Testing Recommendations

1. Test prize claiming for valid winners
2. Test duplicate claim prevention
3. Test history tracking accuracy
4. Test edge cases with zero prizes
5. Test batch operations with history updates

