# 🎰 Decentralized Lottery System

A fair and transparent lottery system built on the Stacks blockchain using Clarity smart contracts. Win big while learning about decentralized randomness! 🚀

## 🎯 Features

- 🎫 **Ticket Purchasing**: Buy multiple lottery tickets with STX
- ⏰ **Time-based Rounds**: Lotteries run for configurable block durations
- 🎲 **Fair Randomness**: Uses block hash-based randomness for winner selection
- 💰 **Automatic Payouts**: Winners receive prizes automatically
- 👑 **Owner Management**: Contract owner can create lotteries and set parameters
- 📊 **Transparent Stats**: View lottery history and participation data
- 🛡️ **Security Features**: Built-in limits and emergency controls

## 🏗️ Contract Architecture

The lottery system consists of:
- **Lottery Management**: Create and manage lottery rounds
- **Ticket Sales**: Players can buy tickets during active periods
- **Winner Selection**: Fair randomness using block hash entropy
- **Prize Distribution**: Automatic winner payouts with owner fees

## 🚀 Quick Start

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- [Stacks CLI](https://docs.stacks.co/docs/cli/installation) (optional)

### Installation

```bash
git clone <your-repo-url>
cd Decentralized-Lottery-System
clarinet integrate
```

### 🎮 Usage

#### 1. Create a New Lottery (Owner Only)
```clarity
(contract-call? .decentralized-lottery-system create-lottery u100)
```
Creates a lottery lasting 100 blocks.

#### 2. Buy Tickets
```clarity
(contract-call? .decentralized-lottery-system buy-ticket u1)
```
Buys a ticket for lottery #1.

#### 3. Batch Buy Multiple Tickets
```clarity
(contract-call? .decentralized-lottery-system batch-buy-tickets u1 u5)
```
Buys 5 tickets for lottery #1.

#### 4. Check Lottery Status
```clarity
(contract-call? .decentralized-lottery-system get-lottery-stats u1)
```

#### 5. Draw Winner (After Lottery Ends)
```clarity
(contract-call? .decentralized-lottery-system draw-winner u1)
```

#### 6. View Your Tickets
```clarity
(contract-call? .decentralized-lottery-system get-all-player-tickets u1 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

## ⚙️ Configuration

### Owner Functions

#### Set Ticket Price
```clarity
(contract-call? .decentralized-lottery-system set-ticket-price u2000000)
```
Sets ticket price to 2 STX.

#### Set Max Tickets Per Player
```clarity
(contract-call? .decentralized-lottery-system set-max-tickets-per-player u20)
```

#### Set Owner Fee Percentage
```clarity
(contract-call? .decentralized-lottery-system set-owner-fee-percentage u10)
```
Sets owner fee to 10% (max 20%).

## 📋 Contract Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `ERR_NOT_OWNER` | 100 | Only contract owner can perform this action |
| `ERR_LOTTERY_NOT_ACTIVE` | 101 | Lottery is not currently active |
| `ERR_LOTTERY_ACTIVE` | 102 | Lottery is currently active |
| `ERR_INSUFFICIENT_PAYMENT` | 104 | Not enough STX to buy ticket |
| `ERR_NO_TICKETS_SOLD` | 105 | Cannot draw winner with no tickets |

## 🔍 Read-Only Functions

- `get-current-lottery-id`: Get the latest lottery ID
- `get-lottery-info`: Get lottery details by ID
- `get-player-ticket-count`: Check how many tickets a player owns
- `get-lottery-stats`: Comprehensive lottery statistics
- `predict-winner`: Preview winning ticket (for ended lotteries)
- `calculate-prize-after-fee`: Calculate winner's prize amount

## 🧪 Testing

```bash
clarinet test
```

Run the test suite to verify contract functionality.

## 🔐 Security Considerations

- ✅ Owner-only functions are protected
- ✅ Lottery timing validation prevents manipulation
- ✅ Payment validation ensures fair ticket sales
- ✅ Emergency withdrawal function for critical situations
- ✅ Maximum ticket limits prevent single-player dominance
- ✅ Fair randomness using block hash (not perfect but sufficient for MVP)

## 💡 How Randomness Works

The lottery uses a deterministic but unpredictable randomness source:
1. Takes the end block height of the lottery
2. Combines with block hash length for additional entropy
3. Uses modulo operation to select winning ticket number

While not cryptographically perfect, this provides sufficient fairness for a decentralized lottery MVP.

## 🛠️ Development

### Project Structure
```
contracts/
  decentralized-lottery-system.clar    # Main contract
tests/
  decentralized-lottery-system_test.ts # Test suite
settings/
  Devnet.toml                         # Network settings
```

### Contributing
1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Submit a pull request

## 📄 License

MIT License - feel free to use this contract as a foundation for your own lottery systems!

---

Built with ❤️ on Stacks blockchain using Clarity smart contracts
