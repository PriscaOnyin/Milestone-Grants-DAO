Here’s a **clear and concise README** for your Milestone Grants DAO contract that explains its purpose, flow, and functions while keeping it developer-friendly.

---

# 📜 Milestone Grants DAO

A **community-reviewed grants system** with **milestone-based disbursement tracking**.
This smart contract manages the **state of grants and milestones on-chain** without handling actual fund transfers.
It enables decentralized governance of grants through **committee review, approvals, and milestone submissions**.

---

## 🚀 Overview

The Milestone Grants DAO allows:

* **Grant proposals** by anyone.
* **Committee review** and approval of grants.
* **Milestone creation** for tracking progress.
* **Submission & review** of work proofs.
* **State tracking** of each grant and milestone lifecycle.

⚠ **Note:** This contract only tracks status on-chain — all fund transfers are handled off-chain.

---

## 🏗 Contract Features

* **Committee Management** — Admin can add committee members who review grants and milestones.
* **Grant Lifecycle**:

  1. Proposed → Approved → Active → Completed / Cancelled
* **Milestone Lifecycle**:

  1. Pending → Submitted → Approved / Rejected
* **Proof Tracking** — Each milestone stores a hash of the submitted proof (e.g., IPFS hash).

---

## 📂 Data Structures

### **Grants**

| Field            | Type                 | Description                                                          |
| ---------------- | -------------------- | -------------------------------------------------------------------- |
| proposer         | `principal`          | Address that proposed the grant                                      |
| title            | `string-ascii(120)`  | Short title                                                          |
| summary          | `string-ascii(300)`  | Grant description                                                    |
| requested-amount | `uint`               | Requested amount (off-chain funds)                                   |
| deadline         | `uint`               | Block height deadline                                                |
| status           | `uint`               | `1=proposed`, `2=approved`, `3=active`, `4=completed`, `5=cancelled` |
| reviewer         | `optional principal` | Assigned reviewer                                                    |
| funds-deposited  | `uint`               | Off-chain tracking                                                   |
| paid-out         | `uint`               | Off-chain tracking                                                   |
| repo-url         | `string-ascii(120)`  | Project repository link                                              |

---

### **Milestones**

| Field      | Type                | Description                                            |
| ---------- | ------------------- | ------------------------------------------------------ |
| title      | `string-ascii(100)` | Milestone title                                        |
| proof-hash | `string-ascii(64)`  | Hash of proof file (e.g., IPFS CID)                    |
| due-block  | `uint`              | Due date in block height                               |
| amount     | `uint`              | Associated amount (off-chain)                          |
| status     | `uint`              | `1=pending`, `2=submitted`, `3=approved`, `4=rejected` |
| submitter  | `principal`         | Who submitted proof                                    |

---

## 📜 Functions

### **Committee**

* `add-committee(member)` — Admin-only. Adds an active committee member.

### **Grants**

* `propose-grant(title, summary, requested-amount, deadline, repo-url)` — Propose a new grant.
* `approve-grant(grant-id, reviewer)` — Committee-only. Approve and assign a reviewer.
* `activate-grant(grant-id)` — Committee-only. Mark an approved grant as active.

### **Milestones**

* `add-milestone(grant-id, title, due-block, amount)` — Proposer or committee can add milestones.
* `submit-milestone(grant-id, milestone-id, proof-hash)` — Submit proof for a milestone.
* `review-milestone(grant-id, milestone-id, approve)` — Committee-only. Approve or reject a submitted milestone.

### **Read-only**

* `get-grant(grant-id)` — View grant details.
* `get-milestone(grant-id, milestone-id)` — View milestone details.

---

## 🔐 Access Control

* **Admin**: The deployer of the contract, can add committee members.
* **Committee**: Can approve grants, activate them, and review milestones.
* **Proposers**: Anyone can propose grants and submit milestones for their own grants.

---

## 🛠 Example Flow

1. **Grant Proposal** → `propose-grant`
2. **Committee Approval** → `approve-grant`
3. **Grant Activation** → `activate-grant`
4. **Milestone Creation** → `add-milestone`
5. **Work Submission** → `submit-milestone`
6. **Committee Review** → `review-milestone`

---

## 📌 Notes

* All fund-related values are **informational only** — actual fund handling is off-chain.
* Status codes are numeric for compact on-chain storage.
* Proof hashes should reference immutable storage (e.g., IPFS).

