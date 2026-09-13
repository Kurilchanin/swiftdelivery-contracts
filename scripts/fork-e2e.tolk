import "@acton/build"
import "@acton/io"
import "@acton/emulation/network"
import "@acton/emulation/scripts"
import "@acton/emulation/testing"
import "@contracts/types"
import "@wrappers/Marketplace.gen"
import "@wrappers/Order.gen"

// End-to-end run against Tether's REAL USDT on a local fork of mainnet — the
// real stablecoin wallet code (a library cell) and its real gas checks, which
// the emulator tests only imitate with the Notcoin mock. Nothing is broadcast:
//
//   acton script scripts/fork-e2e.tolk --fork-net mainnet
//
// A large USDT holder is impersonated as the order's sender (in emulation any
// address can send). Checks: create → Open with the USDT in the order's wallet;
// accept; confirm (the order pays the USDT payout from its fee pool) → the
// courier holds the reward; a second order is cancelled → the sender gets it back.

const MASTER = address("EQCxE6mUtQJKFnGfaROTKOt1lZbDiiX1kCixRv7Nw2Id_sDs")
// Any address holding enough USDT on mainnet.
const HOLDER = address("0:23FA979918F1FE702DB9100BF843E87C7015ECCD39A4721E9B6BAC170BC04CE3")
const REWARD = 10000000 // 10 USDT
const SECRET: uint256 = 0xC0DE1234C0DE1234C0DE1234C0DE1234C0DE1234C0DE1234C0DE1234C0DE1234

struct JettonData {
    totalSupply: int
    mintable: bool
    admin: address?
    content: cell
    walletCode: cell
}

struct WalletData {
    balance: coins
    owner: address
    master: address
    code: cell
}

fun usdtOf(owner: address): coins {
    val wallet: address = net.runGetMethod(MASTER, "get_wallet_address", [owner]);
    if (!scripts.isContractDeployed(wallet)) {
        return 0;
    }
    val data: WalletData = net.runGetMethod(wallet, "get_wallet_data");
    return data.balance;
}

fun params(nonce: uint64): CreateOrder {
    return {
        nonce,
        createdAt: 1700000000,
        deliveryTime: 14 * 24 * 60 * 60,
        description: createEmptyCell(),
        area: createEmptyCell(),
        origin: createEmptyCell(),
        senderContact: createEmptyCell(),
        secretHash: beginCell().storeUint(SECRET, 256).endCell().hash(),
        referral: null,
    };
}

// The create transfer exactly as the frontend builds it: to the sender's own
// USDT wallet, 0.2 forwarded, CreateOrder in the forward payload's ref.
fun create(market: Marketplace, p: CreateOrder): Order {
    val holderWallet: address = net.runGetMethod(MASTER, "get_wallet_address", [HOLDER]);
    val body = beginCell()
        .storeUint(0x0f8a7ea5, 32)
        .storeUint(0, 64)
        .storeCoins(REWARD)
        .storeAddress(market.address)
        .storeAddress(HOLDER)
        .storeBool(false)
        .storeCoins(ton("0.2"))
        .storeBool(true)
        .storeRef(p.toCell())
        .endCell();
    net.send(HOLDER, createMessage({
        bounce: true,
        value: ton("0.3"),
        dest: holderWallet,
        body,
    }));
    return Order.fromAddress(market.orderAddress(
        HOLDER,
        REWARD,
        p.nonce,
        p.createdAt,
        p.deliveryTime,
        p.description,
        p.area,
        p.origin,
        p.senderContact,
        p.secretHash,
        p.referral,
    ));
}

// Tether's wallet code is a library cell; the emulator must know the library to
// run a wallet (its transfers and its get-methods).
const USDT_WALLET_LIBRARY = "8f452d7a4dfd74066b682365177259ed05734435be76b5fd4bd5d8af2b7c3d68"

fun main() {
    val lib = net.loadLibrary(USDT_WALLET_LIBRARY);
    if (lib == null) {
        println("USDT wallet library not found on the fork");
        return;
    }
    testing.registerLibrary(lib!);
    val owner = scripts.wallet("deployer");
    val courier = scripts.wallet("courier");
    val jetton: JettonData = net.runGetMethod(MASTER, "get_jetton_data");
    val market = Marketplace.fromStorage({
        owner: owner.address,
        orderCode: build("Order"),
        orderCount: 0,
        usdtMaster: MASTER,
        jettonWalletCode: jetton.walletCode,
    });
    market.deploy(owner.address, { value: ton("0.5") });

    // 1. Create.
    val holderBefore = usdtOf(HOLDER);
    val order = create(market, params(1));
    println("create:  status {} (Open = 0), order USDT {}, holder paid {}",
        order.status(), usdtOf(order.address), holderBefore - usdtOf(HOLDER));
    println("         order fee buffer {:ton}", scripts.fetchAccountBalance(order.address));

    // 2. Accept and confirm. The confirm needs only its network fee; 0.08 is
    //    plenty, and the order pays the USDT payout.
    order.sendAcceptOrder(courier.address, createEmptyCell(), { value: ton("0.1") });
    val ownerBefore = scripts.fetchAccountBalance(owner.address);
    order.sendConfirmWithCode(courier.address, SECRET, { value: ton("0.08") });
    println("confirm: status {} (Completed = 2), courier USDT {}, order USDT {}",
        order.status(), usdtOf(courier.address), usdtOf(order.address));
    println("         owner earned {:ton}", scripts.fetchAccountBalance(owner.address) - ownerBefore);

    // 3. A second order, cancelled.
    val second = create(market, params(2));
    val holderMid = usdtOf(HOLDER);
    second.sendCancelOrder(HOLDER, { value: ton("0.4") });
    println("cancel:  status {} (Cancelled = 3), USDT back to the sender {}",
        second.status(), usdtOf(HOLDER) - holderMid);
}
