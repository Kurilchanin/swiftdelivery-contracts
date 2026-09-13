import "@acton/build"
import "@acton/emulation/network"
import "@acton/emulation/testing"
import "@acton/testing/expect"
import "@acton/types/message"

import "@contracts/types"
import "@tests/usdt"
import "@wrappers/Marketplace.gen"
import "@wrappers/Order.gen"

const REWARD = 10000000 // 10 USDT

get fun `test create deploys an order and forwards the USDT to it`() {
    val w = setupWorld();
    val sender = testing.treasury("sender");
    val p = orderParams(12345, null);

    val r = w.create(sender, REWARD, p);
    expect(r).toHaveSuccessfulTx<JettonNotify>({ to: w.market.address });
    expect(w.market.orderCount()).toEqual(1);

    // The order exists at the recomputed address, holds the sender's fields and
    // turned Open once its USDT arrived.
    val order = w.orderOf(sender.address, REWARD, p);
    expect(order.status()).toEqual(OrderStatus.Open);
    val data = order.orderData();
    expect(data.sender).toEqual(sender.address);
    expect(data.reward).toEqual(REWARD);

    // The whole reward moved on: the order's own wallet holds it, the
    // Marketplace's wallet and the sender hold nothing.
    expect(w.usdtOf(order.address)).toEqual(REWARD);
    expect(w.usdtOf(w.market.address)).toEqual(0);
    expect(w.usdtOf(sender.address)).toEqual(0);

    // The order was told its wallet, and it is the real one.
    val jetton = data.extra.load().jetton.load();
    expect(jetton.marketplace).toEqual(w.market.address);
    expect(jetton.wallet!).toEqual(w.walletOf(order.address));
}

get fun `test the order takes the USDT excesses without failing`() {
    val w = setupWorld();
    val sender = testing.treasury("sender");
    val p = orderParams(1, null);

    // Both USDT hops of a create send their unused coin to the order.
    val r = w.create(sender, REWARD, p);
    val order = w.orderOf(sender.address, REWARD, p);
    expect(r).toHaveSuccessfulTx<Excesses>({ to: order.address });
    expect(r).toHaveAllSuccessfulTxs();
}

get fun `test the whole 0.1 create fee ends up on the order`() {
    val w = setupWorld();
    val sender = testing.treasury("sender");
    val senderBefore = testing.getAccountBalance(sender.address);
    val order = w.openOrder(sender, REWARD);

    // The sender attached exactly 0.1. Every network fee of the create came out
    // of it and everything left is on the order: nothing more, nothing back.
    val buffer = testing.getAccountBalance(order.address);
    expect(buffer).toBeGreater(ton("0.09"));
    expect(buffer).toBeLess(ton("0.1"));
    // A treasury's balance does not drop by what it sends, only grows by what it
    // receives: no "excesses" came back to the sender.
    expect(testing.getAccountBalance(sender.address)).toEqual(senderBefore);
}

get fun `test creating orders does not spend the marketplace's own balance`() {
    val w = setupWorld();
    val sender = testing.treasury("sender");
    val before = testing.getAccountBalance(w.market.address);

    w.create(sender, REWARD, orderParams(1, null));
    w.create(sender, REWARD, orderParams(2, null));
    expect(w.market.orderCount()).toEqual(2);

    // Every coin spent (gas, the USDT hop, the event, the deploy) came from what
    // the senders attached; the Marketplace only pays its own storage rent.
    expect(testing.getAccountBalance(w.market.address)).toBeGreater(before - ton("0.001"));
}

// The deploy and the USDT hop are shares of the attached coin, not fixed
// amounts: the on-chain minimum still works, and a sender (the app) that
// attaches more gives the hop more margin — all of it ends up on the order.
get fun `test a create with the least coin still turns the order Open`() {
    val w = setupWorld();
    val sender = testing.treasury("sender");
    val p = orderParams(1, null);

    val r = w.create(sender, REWARD, p, ton("0.05"));
    expect(r).toHaveAllSuccessfulTxs();
    val order = w.orderOf(sender.address, REWARD, p);
    expect(order.status()).toEqual(OrderStatus.Open);
    expect(w.usdtOf(order.address)).toEqual(REWARD);
}

get fun `test a create with extra coin gives all of it to the order`() {
    val w = setupWorld();
    val sender = testing.treasury("sender");
    val marketBefore = testing.getAccountBalance(w.market.address);
    val p = orderParams(1, null);

    val r = w.create(sender, REWARD, p, ton("1"));
    expect(r).toHaveAllSuccessfulTxs();
    val order = w.orderOf(sender.address, REWARD, p);
    expect(order.status()).toEqual(OrderStatus.Open);
    expect(testing.getAccountBalance(order.address)).toBeGreater(ton("0.99"));
    expect(testing.getAccountBalance(w.market.address)).toBeGreater(marketBefore - ton("0.001"));
}

get fun `test create with a referral stores it and the address round-trips`() {
    val w = setupWorld();
    val sender = testing.treasury("sender");
    val chat = testing.treasury("referral chat");
    val p = orderParams(7, chat.address);

    w.create(sender, REWARD, p);

    // The getter includes the referral: the order is live at that address.
    val order = w.orderOf(sender.address, REWARD, p);
    expect(order.status()).toEqual(OrderStatus.Open);
    expect(order.orderData().extra.load().referral!).toEqual(chat.address);

    // Without the referral the address is different (and nothing lives there).
    val other = w.orderOf(sender.address, REWARD, orderParams(7, null));
    expect(other.address).toNotEqual(order.address);
    expect(testing.isDeployed(other.address)).toBeFalse();
}

get fun `test create emits OrderCreated and the order emits OrderFunded`() {
    val w = setupWorld();
    val sender = testing.treasury("sender");
    val area = beginCell().storeUint(0xA2EA, 16).endCell();
    var p = orderParams(3, null);
    p.area = area;

    val r = w.create(sender, REWARD, p);
    val order = w.orderOf(sender.address, REWARD, p);

    val created = r.findExternalOutMessage<OrderCreated>({ from: w.market.address });
    expect(created).toBeNotNull();
    val body = created!.loadBody();
    expect(body.orderAddress).toEqual(order.address);
    expect(body.sender).toEqual(sender.address);
    expect(body.reward).toEqual(REWARD);
    expect(body.area.hash()).toEqual(area.hash());

    val funded = r.findExternalOutMessage<OrderFunded>({ from: order.address });
    expect(funded).toBeNotNull();
    expect(funded!.loadBody().reward).toEqual(REWARD);
}

// ---- every problem after real USDT arrived is a refund, never a stuck token ----

fun expectRefunded(w: World, r: SendResultList, sender: Treasury, amount: coins) {
    // The Marketplace handled the notification without failing...
    expect(r).toHaveSuccessfulTx<JettonNotify>({ to: w.market.address });
    // ...and the USDT is back with the sender, nothing is left with it.
    expect(w.usdtOf(sender.address)).toEqual(amount);
    expect(w.usdtOf(w.market.address)).toEqual(0);
    expect(w.market.orderCount()).toEqual(0);
    val refused = r.findExternalOutMessage<CreateRefused>({ from: w.market.address });
    expect(refused).toBeNotNull();
    expect(refused!.loadBody().sender).toEqual(sender.address);
}

get fun `test a reward below the minimum is refunded`() {
    val w = setupWorld();
    val sender = testing.treasury("sender");
    val p = orderParams(1, null);
    val small = 500000 as coins; // 0.5 USDT, below the 1 USDT floor

    val r = w.create(sender, small, p);
    expectRefunded(w, r, sender, small);
    expect(testing.isDeployed(w.orderOf(sender.address, small, p).address)).toBeFalse();
}

get fun `test too little attached coin is refunded`() {
    val w = setupWorld();
    val sender = testing.treasury("sender");
    val p = orderParams(1, null);

    // 0.04 is below CREATE_MIN_VALUE (0.05). It is also below REFUND_GAS, so the
    // Marketplace pays the refund of this real amount itself.
    val r = w.create(sender, REWARD, p, ton("0.04"));
    expectRefunded(w, r, sender, REWARD);
    expect(testing.isDeployed(w.orderOf(sender.address, REWARD, p).address)).toBeFalse();
}

get fun `test an inline payload is refunded`() {
    val w = setupWorld();
    val sender = testing.treasury("sender");
    w.mintUsdt(sender.address, REWARD);

    // CreateOrder never fits inline, so an inline payload is always malformed.
    val inline = beginCell().storeBool(false).storeUint(0xa00a0000, 32).endCell().beginParse();
    val r = sendJettons(
        w.minter,
        sender,
        w.market.address,
        REWARD,
        CREATE_TON,
        inline,
    );
    expectRefunded(w, r, sender, REWARD);
}

get fun `test garbage in the payload ref is refunded`() {
    val w = setupWorld();
    val sender = testing.treasury("sender");
    w.mintUsdt(sender.address, REWARD);

    val garbage = beginCell()
        .storeBool(true)
        .storeRef(beginCell().storeUint(0xBAD, 32).endCell())
        .endCell()
        .beginParse();
    val r = sendJettons(
        w.minter,
        sender,
        w.market.address,
        REWARD,
        CREATE_TON,
        garbage,
    );
    expectRefunded(w, r, sender, REWARD);
}

get fun `test a real amount with no gas is refunded from the marketplace balance`() {
    val w = setupWorld();
    val sender = testing.treasury("sender");
    // 0.02 is too little even for the refund, so the Marketplace pays it
    // itself — the reward is real money, it must not get stuck.
    val r = w.create(sender, REWARD, orderParams(1, null), ton("0.02"));
    expectRefunded(w, r, sender, REWARD);
}

get fun `test dust with no gas is not refunded at the marketplace's cost`() {
    val w = setupWorld();
    val sender = testing.treasury("sender");
    val dust = 1000 as coins; // 0.001 USDT
    val before = testing.getAccountBalance(w.market.address);

    val r = w.create(sender, dust, orderParams(1, null), ton("0.02"));
    expect(r).toHaveSuccessfulTx<JettonNotify>({ to: w.market.address });
    // Refunding dust would let anyone drain the Marketplace; it stays put.
    expect(w.usdtOf(w.market.address)).toEqual(dust);
    expect(testing.getAccountBalance(w.market.address)).toBeGreater(before - ton("0.001"));
}

// A low-gas refund is paid from the Marketplace's balance, so its unused coin
// must come back to the Marketplace. Were it the sender's, a loop of such
// refunds would move the Marketplace's balance to them (and leave nothing for
// refunding an honest mistake).
get fun `test a low-gas refund returns its unused coin to the marketplace`() {
    val w = setupWorld();
    val attacker = testing.treasury("attacker");
    w.mintUsdt(attacker.address, usdt(1));
    val garbage = beginCell()
        .storeBool(true)
        .storeRef(beginCell().storeUint(0xBAD, 32).endCell())
        .endCell()
        .beginParse();
    val marketBefore = testing.getAccountBalance(w.market.address);
    val attackerBefore = testing.getAccountBalance(attacker.address);

    var i = 0;
    while (i < 5) {
        val r = sendJettons(
            w.minter,
            attacker,
            w.market.address,
            usdt(1),
            ton("0.01"),
            garbage,
            ton("0.05"),
        );
        // The Marketplace takes the refund's excesses without failing.
        expect(r).toHaveSuccessfulTx<Excesses>({ to: w.market.address });
        expect(r).toHaveAllSuccessfulTxs();
        i += 1;
    }
    expect(w.usdtOf(attacker.address)).toEqual(usdt(1));
    expect(w.usdtOf(w.market.address)).toEqual(0);
    // A treasury's balance grows only by what it receives: the attacker
    // attached 5 x 0.05 and got back less than that — no profit.
    expect(testing.getAccountBalance(attacker.address) - attackerBefore).toBeLess(ton("0.25"));
    // The Marketplace paid only what the network really charged.
    expect(marketBefore - testing.getAccountBalance(w.market.address)).toBeLess(ton("0.02"));
}

// An Order pays its referral on every closing path without IGNORE_ERRORS, so a
// referral in a workchain that does not exist would make every close fail and
// lock the USDT for good. Such a create must never become an order.
get fun `test a referral in a missing workchain is refunded`() {
    val w = setupWorld();
    val sender = testing.treasury("sender");
    val p = orderParams(1, address.fromWorkchainAndHash(1, 12345));

    val r = w.create(sender, REWARD, p);
    expectRefunded(w, r, sender, REWARD);
    expect(testing.isDeployed(w.orderOf(sender.address, REWARD, p).address)).toBeFalse();
}

// Only the basechain is allowed: partners' wallets live there, and nothing else
// needs to be supported.
get fun `test a masterchain referral is refunded`() {
    val w = setupWorld();
    val sender = testing.treasury("sender");
    val p = orderParams(1, address.fromWorkchainAndHash(-1, 12345));

    val r = w.create(sender, REWARD, p);
    expectRefunded(w, r, sender, REWARD);
    expect(testing.isDeployed(w.orderOf(sender.address, REWARD, p).address)).toBeFalse();
}

// The delivery time must be 1..14 days (the range itself is used by the Order
// tests: 14 days everywhere, one day in the short-delivery test).
get fun `test a delivery time under one day is refunded`() {
    val w = setupWorld();
    val sender = testing.treasury("sender");
    var p = orderParams(1, null);
    p.deliveryTime = 24 * 60 * 60 - 1;

    val r = w.create(sender, REWARD, p);
    expectRefunded(w, r, sender, REWARD);
    expect(testing.isDeployed(w.orderOf(sender.address, REWARD, p).address)).toBeFalse();
}

get fun `test a delivery time over fourteen days is refunded`() {
    val w = setupWorld();
    val sender = testing.treasury("sender");
    var p = orderParams(1, null);
    p.deliveryTime = 14 * 24 * 60 * 60 + 1;

    val r = w.create(sender, REWARD, p);
    expectRefunded(w, r, sender, REWARD);
    expect(testing.isDeployed(w.orderOf(sender.address, REWARD, p).address)).toBeFalse();
}

// ---- a resent create (the very same fields) goes back to the sender ----

get fun `test a resent create goes back to the sender`() {
    val w = setupWorld();
    val sender = testing.treasury("sender");
    val p = orderParams(0, null);
    w.create(sender, REWARD, p);

    // The same create again lands at the same, already running order.
    w.create(sender, REWARD, p);
    val order = w.orderOf(sender.address, REWARD, p);
    expect(order.status()).toEqual(OrderStatus.Open);
    expect(w.usdtOf(order.address)).toEqual(REWARD);
    expect(w.usdtOf(sender.address)).toEqual(REWARD);
}

get fun `test a resent create after completion is not the courier's`() {
    val w = setupWorld();
    val sender = testing.treasury("sender");
    val courier = testing.treasury("courier");
    val p = orderParams(0, null);
    w.create(sender, REWARD, p);
    val order = w.orderOf(sender.address, REWARD, p);
    order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ton("0.1") });
    order.sendConfirmWithCode(courier.address, SECRET, { value: ton("0.01") });
    expect(order.status()).toEqual(OrderStatus.Completed);

    // The closed order holds no coin, yet the duplicate brings enough for its
    // own payout, and the USDT goes back to the sender.
    w.create(sender, REWARD, p);
    expect(w.usdtOf(sender.address)).toEqual(REWARD);
    expect(w.usdtOf(order.address)).toEqual(0);

    // Nothing is left for the courier to pull out with Rescue.
    order.sendRescue(courier.address, REWARD, { value: ton("0.05") });
    expect(w.usdtOf(courier.address)).toEqual(REWARD);
}

// ---- only our own USDT wallet's word counts ----

get fun `test a transfer of another jetton is rejected`() {
    val w = setupWorld();
    val scammer = testing.treasury("scammer");
    val fake = deployMinter(scammer);
    mint(fake, scammer, scammer.address, REWARD);

    // Same wallet code, same payload — but a different jetton master, so its
    // notification comes from a wallet that is not the Marketplace's own.
    val p = orderParams(1, null);
    val r = sendJettons(
        fake,
        scammer,
        w.market.address,
        REWARD,
        CREATE_TON,
        payloadOf(p),
    );
    expect(r).toHaveFailedTx({
        to: w.market.address,
        exitCode: MarketplaceErrors.NotJettonWallet,
    });
    expect(w.market.orderCount()).toEqual(0);
    expect(testing.isDeployed(w.orderOf(scammer.address, REWARD, p).address)).toBeFalse();
}

get fun `test a hand-made notification is rejected`() {
    val w = setupWorld();
    val scammer = testing.treasury("scammer");

    val r = w
        .market
        .sendAny(
            scammer.address,
            (JettonNotify {
                queryId: 0,
                amount: REWARD,
                from: scammer.address,
                forwardPayload: payloadOf(orderParams(1, null)),
            }).toCell(),
            { value: ton("0.5") },
        );
    expect(r).toHaveFailedTx({
        from: scammer.address,
        to: w.market.address,
        exitCode: MarketplaceErrors.NotJettonWallet,
    });
    expect(w.market.orderCount()).toEqual(0);
}

// ---- getters ----

get fun `test getters expose the frozen setup`() {
    val w = setupWorld();
    expect(w.market.owner()).toEqual(w.owner.address);
    expect(w.market.usdtMaster()).toEqual(w.minter);
    expect(w.market.jettonWalletCodeHash()).toEqual(build("JettonWallet").hash());
    expect(w.market.orderCodeHash()).toEqual(build("Order").hash());
    // The Marketplace's wallet math agrees with the jetton master's.
    val someone = testing.treasury("someone");
    expect(w.market.usdtWalletOf(someone.address)).toEqual(w.walletOf(someone.address));
}
