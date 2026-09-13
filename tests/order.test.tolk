import "@acton/emulation/network"
import "@acton/emulation/testing"
import "@acton/testing/expect"
import "@acton/types/message"

import "@contracts/types"
import "@tests/usdt"
import "@wrappers/Order.gen"

const REWARD = 10000000 // 10 USDT
const ACCEPT_FEE = ton("0.1") // courier's service fee (>= MIN_ACCEPT_FEE 0.1)
const BELOW_FEE = ton("0.02") // below MIN_ACCEPT_FEE; accept must reject it
const CANCEL_FEE = ton("0.3") // sender's cancel fee; must match Order.tolk
const RELEASE_FEE = ton("0.2") // courier's release fee; must match Order.tolk
const DEADLINE = DELIVERY_TIME // the delivery time of the test orders (orderParams in usdt.tolk)
// A fixed "now" for time-dependent tests. Must be in the FUTURE relative to the
// emulator's default wall-clock time, otherwise setNow() would move time
// backwards past the deploy and the storage phase fails (-669).
const BASE_TIME: uint32 = 2000000000

// ---- happy path: Open -> Accepted -> Completed (courier confirms with the code) ----

get fun `test confirm with the code pays the courier the reward in USDT`() {
    val (w, order, _, courier) = setupOrderTest();
    order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });

    val courierMid = testing.getAccountBalance(courier.address);
    val ownerMid = testing.getAccountBalance(w.owner.address);

    // The courier learned the secret from the sender at hand-off and reveals it.
    val r = order.sendConfirmWithCode(courier.address, SECRET, { value: NET_FEE });
    expect(r).toHaveSuccessfulTx<ConfirmWithCode>({ from: courier.address, to: order.address });
    expect(order.status()).toEqual(OrderStatus.Completed);

    // The whole reward moved from the order's wallet to the courier's.
    expect(w.usdtOf(courier.address)).toEqual(REWARD);
    expect(w.usdtOf(order.address)).toEqual(0);

    // The courier attached only the network fee and gets no coin back: the order
    // paid the payout gas, and its unused part went to the owner.
    expect(testing.getAccountBalance(courier.address)).toEqual(courierMid);

    // The owner got the whole pool: the create fee (~0.095), the accept fee and
    // the courier's network fee, minus only what the network really charged.
    expect(testing.getAccountBalance(w.owner.address) - ownerMid).toBeGreater(ton("0.19"));
}

// ---- the courier attaches only the network fee: too little changes nothing ----

get fun `test confirm with too little coin to run the code changes nothing`() {
    val (w, order, _, courier) = setupOrderTest();
    order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });

    // Far below what running the code costs: the transaction runs out of gas and
    // is rolled back. The order stays Accepted and its USDT stays put.
    val r = order.sendConfirmWithCode(courier.address, SECRET, { value: ton("0.0001") });
    // -14: out of gas.
    expect(r).toHaveFailedTx({ from: courier.address, to: order.address, exitCode: -14 });
    expect(order.status()).toEqual(OrderStatus.Accepted);
    expect(w.usdtOf(order.address)).toEqual(REWARD);
}

// ---- the courier attaches what the app emulated; any shortfall is the order's ----

get fun `test confirm with less than it costs goes through, the order pays the rest`() {
    val (w, order, _, courier) = setupOrderTest();
    order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });
    val courierMid = testing.getAccountBalance(courier.address);

    // Enough for the checks, less than the whole run: once the caller is
    // checked, the order pays the rest of its gas from the fee pool.
    val r = order.sendConfirmWithCode(courier.address, SECRET, { value: ton("0.0004") });
    expect(r).toHaveSuccessfulTx<ConfirmWithCode>({ from: courier.address, to: order.address });
    expect(order.status()).toEqual(OrderStatus.Completed);
    expect(w.usdtOf(courier.address)).toEqual(REWARD);
    expect(testing.getAccountBalance(courier.address)).toEqual(courierMid);
}

get fun `test a stranger cannot make the order pay for gas`() {
    val (w, order, _, courier) = setupOrderTest();
    order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });
    val orderMid = testing.getAccountBalance(order.address);

    // A stranger (and a courier with a wrong code) is stopped before the order
    // starts paying: the failed run is paid by their own coin only.
    val stranger = testing.treasury("stranger");
    val r = order.sendConfirmWithCode(stranger.address, SECRET, { value: ton("0.0004") });
    expect(r).toHaveFailedTx({
        from: stranger.address,
        to: order.address,
        exitCode: OrderErrors.NotCourier,
    });
    val r2 = order.sendConfirmWithCode(courier.address, WRONG_SECRET, { value: ton("0.0004") });
    expect(r2).toHaveFailedTx({
        from: courier.address,
        to: order.address,
        exitCode: OrderErrors.BadCode,
    });
    expect(testing.getAccountBalance(order.address)).toBeGreater(orderMid - 1);
    expect(w.usdtOf(order.address)).toEqual(REWARD);
}

// ---- no self-destruct: a closed order stays, empty, in its terminal status ----

get fun `test a closed order stays deployed with an empty balance`() {
    val (_, order, _, courier) = setupOrderTest();
    order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });
    order.sendConfirmWithCode(courier.address, SECRET, { value: NET_FEE });

    // The USDT wallet is a separate contract; the order must outlive a payout so
    // that USDT which ever bounces back to that wallet can still be moved.
    expect(testing.isDeployed(order.address)).toBeTrue();
    expect(order.status()).toEqual(OrderStatus.Completed);
    expect(testing.getAccountBalance(order.address)).toBeLess(ton("0.001"));
}

// ---- a wrong code is rejected: the order stays Accepted and the money is safe ----

get fun `test confirm with a wrong code is rejected`() {
    val (w, order, _, courier) = setupOrderTest();
    order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });

    val r = order.sendConfirmWithCode(courier.address, WRONG_SECRET, { value: NET_FEE });
    expect(r).toHaveFailedTx({
        from: courier.address,
        to: order.address,
        exitCode: OrderErrors.BadCode,
    });

    // The order is untouched: still Accepted, the USDT still in its wallet.
    expect(order.status()).toEqual(OrderStatus.Accepted);
    expect(w.usdtOf(order.address)).toEqual(REWARD);
}

// ---- only the courier may confirm: a stranger (even one who knows the code) is rejected ----

get fun `test confirm from a non-courier is rejected even with the right code`() {
    val (w, order, sender, courier) = setupOrderTest();
    order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });

    // The sender knows the secret (they made it) and submits the CORRECT code, but
    // they are not the courier who accepted, so the call must fail: the secret is
    // not enough — only the courier's wallet can trigger payment. This closes the
    // gap where anyone holding a leaked code could force settlement before delivery.
    val r = order.sendConfirmWithCode(sender.address, SECRET, { value: NET_FEE });
    expect(r).toHaveFailedTx({
        from: sender.address,
        to: order.address,
        exitCode: OrderErrors.NotCourier,
    });
    expect(order.status()).toEqual(OrderStatus.Accepted);
    expect(w.usdtOf(order.address)).toEqual(REWARD);
}

// ---- accept charges a fee buffer (not a stake) and starts the clock ----

get fun `test accept records acceptedAt and keeps the fee`() {
    val (_, order, _, courier) = setupOrderTest();
    testing.setNow(BASE_TIME);

    val orderBefore = testing.getAccountBalance(order.address);
    order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });
    expect(order.status()).toEqual(OrderStatus.Accepted);

    val data = order.orderData();
    expect(data.acceptedAt).toEqual(BASE_TIME);
    // The fee buffer stayed on the contract (it is not refunded on accept).
    expect(testing.getAccountBalance(order.address)).toBeGreater(orderBefore);
}

get fun `test accept rejects a fee below the floor`() {
    val (_, order, _, courier) = setupOrderTest();

    // 0.02 TON is below MIN_ACCEPT_FEE (0.1) — accept must fail, order stays Open.
    val r = order.sendAcceptOrder(courier.address, createEmptyCell(), { value: BELOW_FEE });
    expect(r).toHaveFailedTx({
        from: courier.address,
        to: order.address,
        exitCode: OrderErrors.FeeTooLow,
    });
    expect(order.status()).toEqual(OrderStatus.Open);
}

// ---- contact: courier's Telegram contact is stored on accept ----

get fun `test accept stores courier contact`() {
    val (_, order, _, courier) = setupOrderTest();

    val contact = beginCell().storeUint(0xC0FFEE, 32).endCell();
    order.sendAcceptOrder(courier.address, contact, { value: ACCEPT_FEE });

    val data = order.orderData();
    expect(data.extra.load().courierContact.hash()).toEqual(contact.hash());
}

// ---- regression: a real-sized order must NOT overflow the storage cells ----
// With the old flat layout the storage cell crossed 1023 bits the moment a
// courier accepted (courier grows from a 2-bit null to a 267-bit address) and
// AcceptOrder failed with exit_code 8. The biggest shape today: a $1000 reward,
// a referral, the USDT link filled in — accept and the full confirm path must
// still fit.
get fun `test the largest order accepts and confirms without overflow`() {
    val w = setupWorld();
    val sender = testing.treasury("sender");
    val courier = testing.treasury("courier");
    val chat = testing.treasury("referral chat");
    val big = usdt(1000);
    val order = w.openOrder(sender, big, chat.address);

    val r = order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });
    expect(r).toHaveSuccessfulTx<AcceptOrder>({ from: courier.address, to: order.address });

    val chatMid = testing.getAccountBalance(chat.address);
    val r2 = order.sendConfirmWithCode(courier.address, SECRET, { value: NET_FEE });
    expect(r2).toHaveSuccessfulTx<ConfirmWithCode>({ from: courier.address, to: order.address });
    expect(w.usdtOf(courier.address)).toEqual(big);
    expect(testing.getAccountBalance(chat.address) - chatMid).toBeGreater(ton("0.05"));
}

// ---- claim after the deadline: reward -> sender, buffer -> platform, courier nothing ----

get fun `test claim after deadline refunds sender and pays platform`() {
    val (w, order, sender, courier) = setupOrderTest();
    testing.setNow(BASE_TIME);
    order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });

    val courierMid = testing.getAccountBalance(courier.address);
    val senderMid = testing.getAccountBalance(sender.address);
    val ownerMid = testing.getAccountBalance(w.owner.address);

    // Jump past the deadline. Only the sender may claim.
    testing.setNow(BASE_TIME + DEADLINE + 1);
    val r = order.sendClaimExpired(sender.address, { value: NET_FEE });
    expect(r).toHaveSuccessfulTx<ClaimExpired>({ from: sender.address, to: order.address });
    expect(order.status()).toEqual(OrderStatus.Expired);

    // The reward went back to the sender; the courier got nothing at all.
    expect(w.usdtOf(sender.address)).toEqual(REWARD);
    expect(w.usdtOf(courier.address)).toEqual(0);
    expect(testing.getAccountBalance(courier.address) - courierMid).toEqual(0 as coins);

    // The sender attached only the network fee and gets no coin back: the order
    // paid the payout gas.
    expect(testing.getAccountBalance(sender.address)).toEqual(senderMid);

    // Platform got the whole pool, NOT a dust amount. A bit under the confirm
    // test's 0.19: the test jumps to BASE_TIME (years ahead), and the order pays
    // the storage rent for all that time out of its pool.
    expect(testing.getAccountBalance(w.owner.address) - ownerMid).toBeGreater(ton("0.17"));
}

// ---- claim is sender-only: a stranger past the deadline is rejected ----

get fun `test only the sender can claim an expired order`() {
    val (_, order, _, courier) = setupOrderTest();
    testing.setNow(BASE_TIME);
    order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });

    // Past the deadline, but the caller is not the sender.
    testing.setNow(BASE_TIME + DEADLINE + 1);
    val stranger = testing.treasury("stranger");
    val r = order.sendClaimExpired(stranger.address, { value: NET_FEE });
    expect(r).toHaveFailedTx({
        from: stranger.address,
        to: order.address,
        exitCode: OrderErrors.NotSender,
    });
    expect(order.status()).toEqual(OrderStatus.Accepted);
}

get fun `test cannot claim before the deadline`() {
    val (_, order, sender, courier) = setupOrderTest();
    testing.setNow(BASE_TIME);
    order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });

    // Only a little time has passed — far short of 14 days.
    testing.setNow(BASE_TIME + 1000);
    val r = order.sendClaimExpired(sender.address, { value: NET_FEE });
    expect(r).toHaveFailedTx({
        from: sender.address,
        to: order.address,
        exitCode: OrderErrors.NotExpired,
    });
    expect(order.status()).toEqual(OrderStatus.Accepted);
}

get fun `test cannot claim an order that was never accepted`() {
    val (_, order, sender, _) = setupOrderTest();
    testing.setNow(BASE_TIME + DEADLINE + 1);

    val r = order.sendClaimExpired(sender.address, { value: NET_FEE });
    expect(r).toHaveFailedTx({
        from: sender.address,
        to: order.address,
        exitCode: OrderErrors.WrongStatus,
    });
    expect(order.status()).toEqual(OrderStatus.Open);
}

// ---- the delivery time is the sender's choice, per order ----

// A one-day order: the sender can claim it one day after the accept, not two
// weeks later, and the courier can give it up only within that day.
get fun `test a short delivery time is enforced per order`() {
    val w = setupWorld();
    val sender = testing.treasury("sender");
    val courier = testing.treasury("courier");
    val oneDay: uint32 = 24 * 60 * 60;
    var p = orderParams(0, null);
    p.deliveryTime = oneDay;
    w.create(sender, REWARD, p);
    val order = w.orderOf(sender.address, REWARD, p);
    expect(order.status()).toEqual(OrderStatus.Open);
    expect(order.orderData().deliveryTime).toEqual(oneDay);

    testing.setNow(BASE_TIME);
    order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });

    // Exactly one day later the window is still open: no claim yet.
    testing.setNow(BASE_TIME + oneDay);
    val early = order.sendClaimExpired(sender.address, { value: NET_FEE });
    expect(early).toHaveFailedTx({
        from: sender.address,
        to: order.address,
        exitCode: OrderErrors.NotExpired,
    });

    // One second after that the courier can no longer give up, and the sender
    // claims the reward back.
    testing.setNow(BASE_TIME + oneDay + 1);
    val late = order.sendCourierRelease(courier.address, { value: RELEASE_FEE });
    expect(late).toHaveFailedTx({
        from: courier.address,
        to: order.address,
        exitCode: OrderErrors.DeadlinePassed,
    });
    val r = order.sendClaimExpired(sender.address, { value: NET_FEE });
    expect(r).toHaveSuccessfulTx<ClaimExpired>({ from: sender.address, to: order.address });
    expect(w.usdtOf(sender.address)).toEqual(REWARD);
}

// ---- cancel: Open -> Cancelled, reward back to sender, buffer to owner ----

get fun `test cancel refunds the reward to the sender and the buffer to the owner`() {
    val (w, order, sender, _) = setupOrderTest();
    val ownerMid = testing.getAccountBalance(w.owner.address);

    // The sender attaches exactly the 0.3 cancel fee, nothing else.
    val senderMid = testing.getAccountBalance(sender.address);
    val r = order.sendCancelOrder(sender.address, { value: CANCEL_FEE });
    expect(r).toHaveSuccessfulTx<CancelOrder>({ from: sender.address, to: order.address });
    expect(order.status()).toEqual(OrderStatus.Cancelled);

    // The reward is back in full.
    expect(w.usdtOf(sender.address)).toEqual(REWARD);
    expect(w.usdtOf(order.address)).toEqual(0);

    // No coin comes back to the sender: the order paid the payout gas.
    expect(testing.getAccountBalance(sender.address)).toEqual(senderMid);

    // The owner earns the create fee already held plus the 0.3 cancel fee.
    expect(testing.getAccountBalance(w.owner.address) - ownerMid).toBeGreater(ton("0.38"));
}

get fun `test cancel without the cancel fee is rejected`() {
    val (w, order, sender, _) = setupOrderTest();

    // Just below the 0.3 cancel fee.
    val r = order.sendCancelOrder(sender.address, { value: CANCEL_FEE - ton("0.01") });
    expect(r).toHaveFailedTx({
        from: sender.address,
        to: order.address,
        exitCode: OrderErrors.FeeTooLow,
    });
    expect(order.status()).toEqual(OrderStatus.Open);
    expect(w.usdtOf(order.address)).toEqual(REWARD);
}

// ---- courier gives up an accepted order: it reopens and the platform earns the fee ----

get fun `test courier release reopens the order and charges the release fee`() {
    val (w, order, sender, courier) = setupOrderTest();
    testing.setNow(BASE_TIME);
    order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });
    expect(order.status()).toEqual(OrderStatus.Accepted);

    val courierMid = testing.getAccountBalance(courier.address);
    val senderMid = testing.getAccountBalance(sender.address);
    val ownerMid = testing.getAccountBalance(w.owner.address);
    val orderMid = testing.getAccountBalance(order.address);

    // Giving up the order costs the courier the 0.2 TON release fee.
    val r = order.sendCourierRelease(courier.address, { value: RELEASE_FEE });
    expect(r).toHaveSuccessfulTx<CourierRelease>({ from: courier.address, to: order.address });

    // The order reopened instead of closing, and looks like a fresh Open order:
    // no courier, no accept time, no courier contact.
    expect(order.status()).toEqual(OrderStatus.Open);
    val data = order.orderData();
    expect(data.acceptedAt).toEqual(0);
    expect(data.extra.load().courierContact.hash()).toEqual(createEmptyCell().hash());

    // The reward stays in the order's wallet for the next courier; nobody is paid.
    expect(w.usdtOf(order.address)).toEqual(REWARD);
    expect(testing.getAccountBalance(sender.address)).toEqual(senderMid);
    expect(testing.getAccountBalance(w.owner.address) - ownerMid).toBeLess(ton("0.01"));
    expect(testing.getAccountBalance(courier.address) - courierMid).toBeLess(ton("0.01"));

    // The fee stayed on the contract: 0.2 came in and nothing went out.
    expect(testing.getAccountBalance(order.address)).toBeGreater(orderMid + ton("0.1"));

    // A different courier can now take the reopened order.
    val courier2 = testing.treasury("courier2");
    val r2 = order.sendAcceptOrder(courier2.address, createEmptyCell(), { value: ACCEPT_FEE });
    expect(r2).toHaveSuccessfulTx<AcceptOrder>({ from: courier2.address, to: order.address });
    expect(order.orderData().courier!).toEqual(courier2.address);
}

// ---- release is blocked after the deadline: only the sender may act then ----

get fun `test cannot release after the deadline`() {
    val (_, order, _, courier) = setupOrderTest();
    testing.setNow(BASE_TIME);
    order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });

    // Jump past the deadline. The courier now has no actions left — a release is
    // rejected, so the order can only be settled by the sender (claim or confirm).
    testing.setNow(BASE_TIME + DEADLINE + 1);
    val r = order.sendCourierRelease(courier.address, { value: RELEASE_FEE });
    expect(r).toHaveFailedTx({
        from: courier.address,
        to: order.address,
        exitCode: OrderErrors.DeadlinePassed,
    });
    expect(order.status()).toEqual(OrderStatus.Accepted);
}

get fun `test non-courier cannot release`() {
    val (_, order, sender, courier) = setupOrderTest();
    order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });

    val r = order.sendCourierRelease(sender.address, { value: RELEASE_FEE });
    expect(r).toHaveFailedTx({
        from: sender.address,
        to: order.address,
        exitCode: OrderErrors.NotCourier,
    });
    expect(order.status()).toEqual(OrderStatus.Accepted);
}

get fun `test cannot release an order that is still open`() {
    val (_, order, _, courier) = setupOrderTest();

    val r = order.sendCourierRelease(courier.address, { value: RELEASE_FEE });
    expect(r).toHaveFailedTx({
        from: courier.address,
        to: order.address,
        exitCode: OrderErrors.WrongStatus,
    });
    expect(order.status()).toEqual(OrderStatus.Open);
}

// ---- referral: on every terminal path the chat gets HALF of the fee pool ----
// The pool is the native coin on the order's balance (the reward is USDT and
// never part of it). The chat receives a clean pool/2 (its message fees come out
// of the owner's half), so chatGain ≈ ownerGain + fees, and the owner's remainder
// must stay above zero — the platform carries the gas but never pays out of pocket.

fun expectEvenSplit(chatGain: coins, ownerGain: coins) {
    expect(ownerGain).toBeGreater(0 as coins);
    expect(chatGain).toBeGreater(ownerGain - ton("0.01"));
    expect(chatGain - ownerGain).toBeLess(ton("0.05"));
}

get fun `test confirm with a referral splits the fee pool in half`() {
    val (w, order, _, courier, chat) = setupReferralOrderTest();
    order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });

    val ownerMid = testing.getAccountBalance(w.owner.address);
    val chatMid = testing.getAccountBalance(chat.address);

    val r = order.sendConfirmWithCode(courier.address, SECRET, { value: NET_FEE });
    expect(r).toHaveSuccessfulTx<ConfirmWithCode>({ from: courier.address, to: order.address });

    // The courier's payout is untouched by the referral.
    expect(w.usdtOf(courier.address)).toEqual(REWARD);

    // Pool ≈ create buffer (~0.13) + accept fee (0.1) ≈ 0.23 → the chat ~0.11.
    val chatGain = testing.getAccountBalance(chat.address) - chatMid;
    expect(chatGain).toBeGreater(ton("0.09"));
    expectEvenSplit(chatGain, testing.getAccountBalance(w.owner.address) - ownerMid);
}

get fun `test cancel with a referral splits the fee pool in half`() {
    val (w, order, sender, _, chat) = setupReferralOrderTest();

    val ownerMid = testing.getAccountBalance(w.owner.address);
    val chatMid = testing.getAccountBalance(chat.address);

    val r = order.sendCancelOrder(sender.address, { value: CANCEL_FEE });
    expect(r).toHaveSuccessfulTx<CancelOrder>({ from: sender.address, to: order.address });
    expect(w.usdtOf(sender.address)).toEqual(REWARD);

    // Pool ≈ create buffer (~0.13) + cancel fee (0.3) ≈ 0.43 → the chat ~0.21.
    val chatGain = testing.getAccountBalance(chat.address) - chatMid;
    expect(chatGain).toBeGreater(ton("0.18"));
    expectEvenSplit(chatGain, testing.getAccountBalance(w.owner.address) - ownerMid);
}

get fun `test claim expired with a referral splits the fee pool in half`() {
    val (w, order, sender, courier, chat) = setupReferralOrderTest();
    testing.setNow(BASE_TIME);
    order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });

    val ownerMid = testing.getAccountBalance(w.owner.address);
    val chatMid = testing.getAccountBalance(chat.address);

    testing.setNow(BASE_TIME + DEADLINE + 1);
    val r = order.sendClaimExpired(sender.address, { value: NET_FEE });
    expect(r).toHaveSuccessfulTx<ClaimExpired>({ from: sender.address, to: order.address });
    expect(w.usdtOf(sender.address)).toEqual(REWARD);

    // Pool ≈ create buffer (~0.13) + accept fee (0.1) ≈ 0.23 → the chat ~0.11.
    val chatGain = testing.getAccountBalance(chat.address) - chatMid;
    expect(chatGain).toBeGreater(ton("0.09"));
    expectEvenSplit(chatGain, testing.getAccountBalance(w.owner.address) - ownerMid);
}

// Release cycles grow the pool (0.1 accept + 0.2 release each), and the dynamic
// pool/2 picks that up with no extra bookkeeping: the chat's payout grows too.
get fun `test release cycles grow the referral payout`() {
    val (w, order, _, courier, chat) = setupReferralOrderTest();
    testing.setNow(BASE_TIME);

    // Cycle: the first courier accepts and gives up (0.1 + 0.2 stay on the order).
    order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });
    order.sendCourierRelease(courier.address, { value: RELEASE_FEE });
    expect(order.status()).toEqual(OrderStatus.Open);

    // A second courier takes it and delivers.
    val courier2 = testing.treasury("courier2");
    order.sendAcceptOrder(courier2.address, createEmptyCell(), { value: ACCEPT_FEE });

    val ownerMid = testing.getAccountBalance(w.owner.address);
    val chatMid = testing.getAccountBalance(chat.address);

    val r = order.sendConfirmWithCode(courier2.address, SECRET, { value: NET_FEE });
    expect(r).toHaveSuccessfulTx<ConfirmWithCode>({ from: courier2.address, to: order.address });
    expect(w.usdtOf(courier2.address)).toEqual(REWARD);

    // Pool ≈ 0.13 + 0.1 + 0.2 (the cycle) + 0.1 (second accept) ≈ 0.53 → the
    // chat's half ≈ 0.26, clearly above the no-cycle ~0.11.
    val chatGain = testing.getAccountBalance(chat.address) - chatMid;
    expect(chatGain).toBeGreater(ton("0.22"));
    expectEvenSplit(chatGain, testing.getAccountBalance(w.owner.address) - ownerMid);
}

// ---- events: every state change emits an external-out log ----
// The events are what the off-chain worker (notifications, indexer, referral
// accounting) consumes, so each test pins the exact fields a watcher relies on.

get fun `test accept emits OrderAccepted`() {
    val (_, order, _, courier) = setupOrderTest();

    val r = order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });
    val ev = r.findExternalOutMessage<OrderAccepted>({ from: order.address });
    expect(ev).toBeNotNull();
    expect(ev!.loadBody().courier).toEqual(courier.address);
}

get fun `test confirm emits OrderCompleted with a zero referral payout`() {
    val (_, order, _, courier) = setupOrderTest();
    order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });

    val r = order.sendConfirmWithCode(courier.address, SECRET, { value: NET_FEE });
    val ev = r.findExternalOutMessage<OrderCompleted>({ from: order.address });
    expect(ev).toBeNotNull();
    val body = ev!.loadBody();
    expect(body.courier).toEqual(courier.address);
    expect(body.reward).toEqual(REWARD);
    // No referral chat on this order — the payout field must say 0.
    expect(body.referralPayout).toEqual(0 as coins);
}

get fun `test confirm with a referral emits the exact referral payout`() {
    val (_, order, _, courier, chat) = setupReferralOrderTest();
    order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });

    val chatMid = testing.getAccountBalance(chat.address);
    val r = order.sendConfirmWithCode(courier.address, SECRET, { value: NET_FEE });

    // The event's payout is the amount SENT to the chat — the field a partner
    // chat audits its earnings with. The chat's balance grows by that amount
    // minus only its own receive-side gas, so the two must agree within that
    // sliver and the payout can never be below the balance gain.
    val chatGain = testing.getAccountBalance(chat.address) - chatMid;
    val ev = r.findExternalOutMessage<OrderCompleted>({ from: order.address });
    expect(ev).toBeNotNull();
    val body = ev!.loadBody();
    expect(body.referralPayout).toBeGreater(chatGain - 1);
    expect(body.referralPayout - chatGain).toBeLess(ton("0.001"));
    expect(body.referralPayout).toBeGreater(0 as coins);
}

get fun `test cancel with a referral emits OrderCancelled with the exact payout`() {
    val (_, order, sender, _, chat) = setupReferralOrderTest();

    val chatMid = testing.getAccountBalance(chat.address);
    val r = order.sendCancelOrder(sender.address, { value: CANCEL_FEE });

    val chatGain = testing.getAccountBalance(chat.address) - chatMid;
    val ev = r.findExternalOutMessage<OrderCancelled>({ from: order.address });
    expect(ev).toBeNotNull();
    val body = ev!.loadBody();
    expect(body.reward).toEqual(REWARD);
    expect(body.referralPayout).toBeGreater(chatGain - 1);
    expect(body.referralPayout - chatGain).toBeLess(ton("0.001"));
    expect(body.referralPayout).toBeGreater(0 as coins);
}

get fun `test claim emits OrderExpired naming the courier who failed`() {
    val (_, order, sender, courier) = setupOrderTest();
    testing.setNow(BASE_TIME);
    order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });

    testing.setNow(BASE_TIME + DEADLINE + 1);
    val r = order.sendClaimExpired(sender.address, { value: NET_FEE });
    val ev = r.findExternalOutMessage<OrderExpired>({ from: order.address });
    expect(ev).toBeNotNull();
    val body = ev!.loadBody();
    expect(body.courier).toEqual(courier.address);
    expect(body.reward).toEqual(REWARD);
    expect(body.referralPayout).toEqual(0 as coins);
}

get fun `test release emits OrderReopened naming the courier who gave up`() {
    val (_, order, _, courier) = setupOrderTest();
    order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });

    val r = order.sendCourierRelease(courier.address, { value: RELEASE_FEE });
    val ev = r.findExternalOutMessage<OrderReopened>({ from: order.address });
    expect(ev).toBeNotNull();
    expect(ev!.loadBody().courier).toEqual(courier.address);
}

// ---- access control ----

get fun `test non-sender cannot cancel`() {
    val (_, order, _, courier) = setupOrderTest();

    val r = order.sendCancelOrder(courier.address, { value: CANCEL_FEE });
    expect(r).toHaveFailedTx({
        from: courier.address,
        to: order.address,
        exitCode: OrderErrors.NotSender,
    });
    expect(order.status()).toEqual(OrderStatus.Open);
}

// ---- invalid state transitions ----

get fun `test cannot accept twice`() {
    val (_, order, _, courier) = setupOrderTest();
    order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });

    val other = testing.treasury("other");
    val r = order.sendAcceptOrder(other.address, createEmptyCell(), { value: ACCEPT_FEE });
    expect(r).toHaveFailedTx({
        from: other.address,
        to: order.address,
        exitCode: OrderErrors.WrongStatus,
    });
}

get fun `test cannot confirm before accepted`() {
    val (_, order, _, courier) = setupOrderTest();

    // Even with the correct code, an order that no courier has accepted yet cannot
    // be confirmed — the status guard rejects it before the hash is checked.
    val r = order.sendConfirmWithCode(courier.address, SECRET, { value: NET_FEE });
    expect(r).toHaveFailedTx({
        from: courier.address,
        to: order.address,
        exitCode: OrderErrors.WrongStatus,
    });
}

get fun `test cannot cancel after accepted`() {
    val (_, order, sender, courier) = setupOrderTest();
    order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });

    val r = order.sendCancelOrder(sender.address, { value: CANCEL_FEE });
    expect(r).toHaveFailedTx({
        from: sender.address,
        to: order.address,
        exitCode: OrderErrors.WrongStatus,
    });
}

// ---- funding: only the Marketplace's USDT, through the order's own wallet ----
// These tests deploy an order directly, with a treasury standing in for the
// Marketplace, so each funding step can be driven (or skipped) by hand.

get fun `test InitWallet from anyone but the marketplace is rejected`() {
    val (w, order, _, _) = setupFundingOrder();
    val stranger = testing.treasury("stranger");

    val r = order.sendInitWallet(stranger.address, stranger.address, { value: ton("0.05") });
    expect(r).toHaveFailedTx({
        from: stranger.address,
        to: order.address,
        exitCode: OrderErrors.NotMarketplace,
    });
    expect(order.orderData().extra.load().jetton.load().wallet).toBeNull();
    expect(w.usdtOf(order.address)).toEqual(0);
}

get fun `test InitWallet is accepted only once`() {
    val (w, order, _, market) = setupFundingOrder();
    order.sendInitWallet(market.address, w.walletOf(order.address), { value: ton("0.05") });

    val r = order.sendInitWallet(market.address, market.address, { value: ton("0.05") });
    expect(r).toHaveFailedTx({
        from: market.address,
        to: order.address,
        exitCode: OrderErrors.WrongStatus,
    });
    expect(order.orderData().extra.load().jetton.load().wallet!).toEqual(w.walletOf(order.address));
}

get fun `test a hand-made notification cannot fund an order`() {
    val (w, order, _, market) = setupFundingOrder();
    order.sendInitWallet(market.address, w.walletOf(order.address), { value: ton("0.05") });

    // A perfect-looking notice — right amount, "from" the Marketplace — but it
    // does not come from the order's USDT wallet.
    val r = order.sendAny(
        market.address,
        (JettonNotify {
            queryId: 0,
            amount: REWARD,
            from: market.address,
            forwardPayload: emptyPayload(),
        }).toCell(),
        { value: ton("0.05") },
    );
    expect(r).toHaveFailedTx({
        from: market.address,
        to: order.address,
        exitCode: OrderErrors.NotJettonWallet,
    });
    expect(order.status()).toEqual(OrderStatus.Funding);
}

get fun `test only the marketplace's transfer of exactly the reward funds an order`() {
    val (w, order, _, market) = setupFundingOrder();
    order.sendInitWallet(market.address, w.walletOf(order.address), { value: ton("0.05") });

    // Real USDT from someone else does not fund it...
    val stranger = testing.treasury("stranger");
    w.mintUsdt(stranger.address, REWARD);
    sendJettons(
        w.minter,
        stranger,
        order.address,
        REWARD,
        ton("0.01"),
        emptyPayload(),
    );
    expect(order.status()).toEqual(OrderStatus.Funding);

    // ...nor does the Marketplace sending the wrong amount...
    w.mintUsdt(market.address, REWARD + 1);
    sendJettons(
        w.minter,
        market,
        order.address,
        1,
        ton("0.01"),
        emptyPayload(),
    );
    expect(order.status()).toEqual(OrderStatus.Funding);

    // ...and until it is funded, no courier can take it.
    val courier = testing.treasury("courier");
    val r = order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });
    expect(r).toHaveFailedTx({
        from: courier.address,
        to: order.address,
        exitCode: OrderErrors.WrongStatus,
    });

    // The Marketplace's transfer of exactly the reward does.
    sendJettons(
        w.minter,
        market,
        order.address,
        REWARD,
        ton("0.01"),
        emptyPayload(),
    );
    expect(order.status()).toEqual(OrderStatus.Open);
}

get fun `test a funding order whose notice was lost is cancelled for free`() {
    val (w, order, sender, market) = setupFundingOrder();
    order.sendInitWallet(market.address, w.walletOf(order.address), { value: ton("0.05") });

    // The USDT arrives, but with no notification (forwardTon 0) — as if the
    // notice had been lost. The order is stuck in Funding with the USDT in hand.
    w.mintUsdt(market.address, REWARD);
    sendJettons(
        w.minter,
        market,
        order.address,
        REWARD,
        0,
        emptyPayload(),
    );
    expect(order.status()).toEqual(OrderStatus.Funding);
    expect(w.usdtOf(order.address)).toEqual(REWARD);

    // The sender cancels with only the network fee — no cancel fee, the create
    // fee pays the payout — and gets the USDT straight back.
    val r = order.sendCancelOrder(sender.address, { value: NET_FEE });
    expect(r).toHaveSuccessfulTx<CancelOrder>({ from: sender.address, to: order.address });
    expect(order.status()).toEqual(OrderStatus.Cancelled);
    expect(w.usdtOf(sender.address)).toEqual(REWARD);
}

// A Funding order never went live: its only coin is the create fee, which pays
// the payout, so no referral chat earns on its cancel.
get fun `test a funding order's cancel pays no referral`() {
    val chat = testing.treasury("referral chat");
    val (w, order, sender, market) = setupFundingOrder(chat.address);
    order.sendInitWallet(market.address, w.walletOf(order.address), { value: ton("0.05") });
    w.mintUsdt(market.address, REWARD);
    sendJettons(
        w.minter,
        market,
        order.address,
        REWARD,
        0,
        emptyPayload(),
    );
    expect(order.status()).toEqual(OrderStatus.Funding);

    val chatMid = testing.getAccountBalance(chat.address);
    val r = order.sendCancelOrder(sender.address, { value: NET_FEE });
    expect(r).toHaveSuccessfulTx<CancelOrder>({ from: sender.address, to: order.address });
    expect(w.usdtOf(sender.address)).toEqual(REWARD);
    expect(testing.getAccountBalance(chat.address)).toEqual(chatMid);
    val ev = r.findExternalOutMessage<OrderCancelled>({ from: order.address });
    expect(ev).toBeNotNull();
    expect(ev!.loadBody().referralPayout).toEqual(0 as coins);
}

// ---- Rescue: USDT left in a closed order's wallet goes to its payee ----

get fun `test the courier rescues USDT sent to a completed order`() {
    val (w, order, sender, courier) = setupOrderTest();
    order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });
    order.sendConfirmWithCode(courier.address, SECRET, { value: NET_FEE });

    // Someone sends 3 USDT to the closed order by mistake.
    val stranger = testing.treasury("stranger");
    w.mintUsdt(stranger.address, usdt(3));
    sendJettons(
        w.minter,
        stranger,
        order.address,
        usdt(3),
        0,
        emptyPayload(),
    );
    expect(w.usdtOf(order.address)).toEqual(usdt(3));

    // A completed order's USDT is the courier's — the sender may not take it.
    val r = order.sendRescue(sender.address, usdt(3), { value: PAYOUT });
    expect(r).toHaveFailedTx({
        from: sender.address,
        to: order.address,
        exitCode: OrderErrors.NotPayee,
    });

    val r2 = order.sendRescue(courier.address, usdt(3), { value: PAYOUT });
    expect(r2).toHaveSuccessfulTx<Rescue>({ from: courier.address, to: order.address });
    expect(w.usdtOf(courier.address)).toEqual(REWARD + usdt(3));
    expect(w.usdtOf(order.address)).toEqual(0);
}

get fun `test the sender rescues USDT that reached an order after its cancel`() {
    val (w, order, sender, market) = setupFundingOrder();
    order.sendInitWallet(market.address, w.walletOf(order.address), { value: ton("0.05") });

    // Cancelled while its wallet is still empty: the payout bounces off it, and
    // nothing is lost.
    order.sendCancelOrder(sender.address, { value: NET_FEE });
    expect(order.status()).toEqual(OrderStatus.Cancelled);
    expect(w.usdtOf(sender.address)).toEqual(0);

    // The USDT shows up late; the sender pulls it out.
    w.mintUsdt(market.address, REWARD);
    sendJettons(
        w.minter,
        market,
        order.address,
        REWARD,
        ton("0.01"),
        emptyPayload(),
    );
    expect(order.status()).toEqual(OrderStatus.Cancelled);
    order.sendRescue(sender.address, REWARD, { value: PAYOUT });
    expect(w.usdtOf(sender.address)).toEqual(REWARD);
}

// Found on a mainnet fork: a closed order's balance is 0, so once any time has
// passed, the storage rent it owes comes out of the Rescue's own value before
// the contract sees it. A caller who attached exactly the minimum payout gas was
// refused (FeeTooLow), and the USDT stayed put. Rescue must still work years
// after the order closed.
get fun `test rescue works long after the order closed`() {
    val (w, order, _, courier) = setupOrderTest();
    order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ACCEPT_FEE });
    order.sendConfirmWithCode(courier.address, SECRET, { value: NET_FEE });

    // Years pass; the empty order now owes storage rent.
    testing.setNow(BASE_TIME);
    val stranger = testing.treasury("stranger");
    w.mintUsdt(stranger.address, usdt(3));
    sendJettons(
        w.minter,
        stranger,
        order.address,
        usdt(3),
        0,
        emptyPayload(),
    );

    // Exactly the contract's minimum (PAYOUT_GAS), not the app's PAYOUT.
    val r = order.sendRescue(courier.address, usdt(3), { value: ton("0.02") });
    expect(r).toHaveSuccessfulTx<Rescue>({ from: courier.address, to: order.address });
    expect(w.usdtOf(courier.address)).toEqual(REWARD + usdt(3));
    expect(w.usdtOf(order.address)).toEqual(0);
}

get fun `test rescue is refused on an order that is still running`() {
    val (_, order, sender, _) = setupOrderTest();

    val r = order.sendRescue(sender.address, REWARD, { value: PAYOUT });
    expect(r).toHaveFailedTx({
        from: sender.address,
        to: order.address,
        exitCode: OrderErrors.WrongStatus,
    });
}

// A funded Open order with a 10 USDT reward, created through the Marketplace.
fun setupOrderTest(): (World, Order, Treasury, Treasury) {
    val w = setupWorld();
    val sender = testing.treasury("sender");
    val courier = testing.treasury("courier");
    return (w, w.openOrder(sender, REWARD), sender, courier);
}

// The same, with a referral chat set.
fun setupReferralOrderTest(): (World, Order, Treasury, Treasury, Treasury) {
    val w = setupWorld();
    val sender = testing.treasury("sender");
    val courier = testing.treasury("courier");
    val chat = testing.treasury("referral chat");
    return (w, w.openOrder(sender, REWARD, chat.address), sender, courier, chat);
}

// An order deployed straight in the Funding state, with a treasury in place of
// the Marketplace: nothing has told it its wallet or sent it USDT yet.
fun setupFundingOrder(referral: address? = null): (World, Order, Treasury, Treasury) {
    val w = setupWorld();
    val sender = testing.treasury("sender");
    val market = testing.treasury("market stand-in");
    val order = Order.fromStorage({
        sender: sender.address,
        courier: null,
        description: createEmptyCell(),
        area: createEmptyCell(),
        origin: createEmptyCell(),
        reward: REWARD,
        status: OrderStatus.Funding,
        nonce: 0,
        createdAt: 0,
        acceptedAt: 0,
        deliveryTime: DELIVERY_TIME,
        extra: (OrderExtra {
            owner: w.owner.address,
            senderContact: createEmptyCell(),
            courierContact: createEmptyCell(),
            secretHash: secretHashOf(SECRET),
            referral,
            jetton: (OrderJetton {
                marketplace: market.address,
                wallet: null,
            }).toCell(),
        }).toCell(),
    });
    val res = order.deploy(sender.address, { value: ton("0.2") });
    expect(res).toHaveSuccessfulDeploy({ to: order.address });
    return (w, order, sender, market);
}
