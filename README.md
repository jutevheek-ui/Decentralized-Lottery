# 🎰 Decentralized Lottery MVP

Welcome to the **Decentralized Lottery**! This project is a simple, transparent, and fair lottery built on the Stacks blockchain using Clarity.

## 🌟 Features

- **🎟️ Buy Tickets**: Anyone can buy a ticket with STX.
- **🎲 Random Winner**: Winners are selected randomly using block hash.
- **💰 Claim Prize**: The winner claims the entire pot!
- **🔒 Secure**: Logic is enforced by smart contracts.

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed.
- Node.js & NPM (for testing).

### 🛠️ Usage

1. **Initialize the project**
   ```bash
   clarinet new .
   ```

2. **Check the contract**
   ```bash
   clarinet check
   ```

3. **Run Console**
   ```bash
   clarinet console
   ```

4. **Interact in Console**
   ```clarity
   ;; Buy a ticket
   (contract-call? .lottery buy-ticket)
   
   ;; Advance blocks (simulate time passing)
   ::advance_chain_tip 15

   ;; Close the round
   (contract-call? .lottery close-round)
   
   ;; Check winner
   (contract-call? .lottery get-round-info u1)
   
   ;; Claim prize (as winner)
   (contract-call? .lottery claim-prize u1)
   ```

## 📜 Contract Details

- **Cost**: 100 STX per ticket.
- **Round Duration**: 10 blocks.
- **Winner Selection**: Pseudo-random properties of the block hash.

---
*Built with ❤️ on Stacks*
