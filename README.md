# 🌟 Youngdao - Youth Grant DAO

A decentralized autonomous organization that empowers young innovators by funding youth-led initiatives through community voting.

## 🎯 Overview

Youngdao is a smart contract-based DAO specifically designed for youth (ages 13-25) to propose, vote on, and fund community initiatives. The platform promotes youth leadership, innovation, and community engagement through transparent governance.

## ✨ Features

- 👥 **Age-Verified Membership** - Only youth aged 13-25 can participate
- 💡 **Proposal System** - Submit funding requests for youth-led projects
- 🗳️ **Democratic Voting** - Community decides which proposals get funded
- 💰 **Treasury Management** - Secure funding distribution
- 🏆 **Reputation System** - Build credibility through participation
- ⏰ **Time-Bounded Voting** - 144 block voting periods for fair decisions

## 🚀 Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing

### Installation
```bash
git clone https://github.com/yourusername/Youngdao
cd Youngdao
clarinet console
```

## 📖 Usage Guide

### 1. Set Your Age 👶➡️👨‍🎓
```clarity
(contract-call? .Youngdao set-member-age u20)
```

### 2. Fund the Treasury 💰
```clarity
(contract-call? .Youngdao deposit-treasury u10000000)
```

### 3. Submit a Proposal 📝
```clarity
(contract-call? .Youngdao submit-proposal 
    "Youth Coding Bootcamp" 
    "Free coding bootcamp for underserved youth in our community" 
    u5000000)
```

### 4. Vote on Proposals 🗳️
```clarity
;; Vote FOR a proposal
(contract-call? .Youngdao vote-on-proposal u1 true)

;; Vote AGAINST a proposal  
(contract-call? .Youngdao vote-on-proposal u1 false)
```

### 5. Execute Passed Proposals 🎉
```clarity
(contract-call? .Youngdao execute-proposal u1)
```

## 🔍 Read-Only Functions

### Check Proposal Details
```clarity
(contract-call? .Youngdao get-proposal u1)
```

### View Proposal Status
```clarity
(contract-call? .Youngdao get-proposal-status u1)
```

### Check Treasury Balance
```clarity
(contract-call? .Youngdao get-treasury-balance)
```

### View Member Reputation
```clarity
(contract-call? .Youngdao get-member-reputation 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

## 📊 Contract Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| Min Age | 13 | Minimum age for participation |
| Max Age | 25 | Maximum age for participation |
| Voting Period | 144 blocks | ~24 hours on Stacks |
| Min Grant | 1 STX | Minimum funding request |
| Max Grant | 50 STX | Maximum funding request |

## 🔐 Security Features

- ✅ Age verification required for all actions
- ✅ One vote per proposal per member
- ✅ Time-locked voting periods
- ✅ Treasury balance validation
- ✅ Emergency withdrawal for contract owner
- ✅ Proposal execution validation

## 🏗️ Contract Architecture

### Data Structures
- **Proposals**: Store project details, voting results, and execution status
- **Votes**: Track individual voting records
- **Member Ages**: Verify youth eligibility
- **Member Reputation**: Track participation and successful proposals

### Key Functions
- `submit-proposal`: Create new funding requests
- `vote-on-proposal`: Cast votes on active proposals
- `execute-proposal`: Distribute funds to passed proposals
- `deposit-treasury`: Add funds to the DAO treasury

## 🎮 Testing

Run the test suite:
```bash
clarinet test
```

## 🤝 Contributing

We welcome contributions from young developers! 

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is open source and available under the MIT License.

## 🌐 Community

Join our community of young innovators:
- 💬 Discord: [Coming Soon]
- 🐦 Twitter: [@youngdao]
- 📧 Email: hello@youngdao.org