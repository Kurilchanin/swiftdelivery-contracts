# SwiftDelivery — TON Smart Contracts

**Marketplace (mainnet):** [`EQDRV9u2zIh2DplT_yVus2lwDDocZNi41ndaRTiZ5mgdE5XR`](https://tonviewer.com/EQDRV9u2zIh2DplT_yVus2lwDDocZNi41ndaRTiZ5mgdE5XR)
(source verified on [TON Verifier](https://verifier.ton.org/UQDRV9u2zIh2DplT_yVus2lwDDocZNi41ndaRTiZ5mgdE8gU); the code hashes below match the on-chain code)

SwiftDelivery is a peer-to-peer delivery service on the TON blockchain
([app](https://t.me/SwiftDelivery_bot/app) ·
swiftdelivery.ton).
Senders post delivery orders with a reward in **USDT**; couriers accept and
complete them. The service fees and all network fees are paid in TON. All money
flows through these smart contracts — the platform cannot take or hold funds
outside the rules written in the code.

This repository is published so anyone can read the contract code and verify
how the service works.

## Contracts

- `contracts/Marketplace.tolk` — the single registry contract. A sender creates
  an order with one USDT transfer to it, with the order's details in the
  transfer's forward payload. The Marketplace checks that the notice came from
  its own USDT wallet, deploys a fresh Order contract and moves the USDT into
  that order's own USDT wallet. If anything is wrong (bad details, a reward
  under 1 USDT, too little TON attached, a delivery time outside 1–14 days, a
  referral address outside the basechain) it sends the USDT back.
- `contracts/Order.tolk` — one contract per order. Its own USDT wallet holds the
  reward; the order runs the state machine: Funding → Open → Accepted →
  Completed / Cancelled / Expired (or back to Open if the courier gives up).
  An order turns Open only when its own USDT wallet reports the reward from
  the Marketplace. A second create with the very same details lands at the
  same order address; the order sends that USDT straight back to the sender.
- `contracts/types.tolk` — shared storage, message and event types.

## Nobody can change the rules

The code is frozen at deploy time. The contracts accept **no admin messages**:

- The Marketplace owner (the fee recipient) is set once at deploy and no
  message can change it.
- The Order code the Marketplace deploys, the USDT master it accepts and that
  jetton's wallet code are stored at deploy time and no message can change
  them. The `orderCodeHash`, `usdtMaster` and `jettonWalletCodeHash` getters
  let anyone check them.
- An Order pays out only on the paths described below. There is no way for
  the platform to take the escrow or block a payout.

## How an order is confirmed

At create time the sender's app picks a random secret and stores only its
**hash** on-chain. At hand-off the sender shows the secret to the courier (as
a QR code). The courier sends it to the contract; the contract pays the
reward only if the hash matches. So the courier is paid the moment the parcel
changes hands — there is no "confirm" button the sender could sit on.

## How money moves

| Action | Who pays | What happens |
|--------|----------|--------------|
| Create order | Sender: the reward in USDT + exactly 0.1 TON service fee, network included | Order deployed, the USDT moved into its own USDT wallet |
| Accept order | Courier: 0.1 TON service fee, network included | Courier's contact revealed, the delivery clock starts |
| Confirm delivery (secret code) | Courier: only the network fee of running the order's code (~0.0007 TON) | Courier gets the full reward in USDT |
| Claim expired (after the deadline) | Sender: only the network fee (~0.0007 TON) | Sender gets the full reward back |
| Cancel open order | Sender: 0.3 TON service fee, network included | Sender gets the full reward back |
| Courier gives up (before deadline) | Courier: 0.2 TON service fee, network included | Order reopens for another courier |
| Rescue (closed order) | Payee: ≥ 0.02 TON gas, mostly returned | USDT left in the order's wallet goes to the payee |

One fee per action, and nothing on top: every network fee of an action comes
out of its service fee. On create, the unused coin of every hop (the USDT
wallets' "excesses" included) ends up on the order, so nothing comes back to
the sender. The USDT payouts of confirm, claim and cancel are paid by the order
from the fees it holds, and their unused gas goes to the platform; the caller
attaches no payout gas. For confirm and claim the app attaches exactly the gas
it measured by emulating the call; once the caller is checked, the order pays
for its own gas, so if the real run needs a little more, the order covers it.

The reward itself is always paid out in full — to the courier on delivery, or
back to the sender otherwise. The service fees stay on the order and go to
the platform when the order closes. The minimum reward is 1 USDT (anti-spam).
An order whose USDT never arrived (status Funding) can be cancelled with no
cancel fee; its create fee pays the payout, and no referral is paid on it.

**Referral:** an order may carry a referral address (the Telegram chat whose
link opened the app). When the order closes, that address receives half of
the collected fees (in TON); the platform gets the rest.

**No self-destruct, and Rescue:** a closed order stays on chain. If a payout
ever fails on the receiving side, the USDT goes back into the order's USDT
wallet; the order's payee (the courier of a completed order, the sender of a
cancelled or expired one) can then pull it out with a `Rescue` message. The
same works for USDT sent to an order by mistake. A closed order's balance is
0, so the storage rent it owes is taken from the Rescue's own value; that rent
counts toward the 0.02 TON minimum, so Rescue works however long ago the order
closed.

## Events

Every state change emits an external-out message (TON's equivalent of a log).
Opcodes `0xa00a0100`–`0xa00a0107`: OrderCreated, OrderAccepted,
OrderCompleted, OrderCancelled, OrderExpired, OrderReopened, OrderFunded,
CreateRefused. `reward` fields are in USDT units (1 USDT = 1,000,000).
Indexers (e.g. toncenter v3) can filter them by source address and opcode.

## Privacy

Order data on-chain is public, so it carries only what a courier needs: the
destination city, a free-text origin, a short description and the parties'
Telegram usernames. The exact street address and phone numbers are never
stored on-chain.

## Build and test

Built with [Tolk](https://docs.ton.org/v3/documentation/smart-contracts/tolk/overview)
and the `acton` toolchain:

```bash
acton build
acton test                                          # emulator, on a test USDT (tests/jetton)
acton script scripts/fork-e2e.tolk --fork-net mainnet  # a local copy of mainnet, Tether's real USDT
acton script scripts/xcheck.tolk                    # values the app must reproduce
```

Deploy (see the header of `scripts/deploy.tolk`):

```bash
USDT_MASTER=<master> OWNER=<fee wallet> acton script scripts/deploy.tolk --net mainnet
```

Code hashes of the source in this repository — the code of the mainnet
Marketplace (`EQDRV9u2…E5XR`):

```
Marketplace: C9D7176C056FDDB78415F6AEDAC7F0A2396FB3881D6E9D5A64222C5AD5A91526
Order:       E91B890474D04E5327CBCE06DB4E94B8B0A6BA1A450244BDBCCE6E5128AA2AAA
```

Compare them with the deployed contract on tonviewer and with the
`orderCodeHash` getter to verify which code is on-chain.

## License

MIT — see [LICENSE](LICENSE). `tests/jetton` is from
[ton-blockchain/tolk-bench](https://github.com/ton-blockchain/tolk-bench)
(MIT, see `tests/jetton/LICENSE`).
