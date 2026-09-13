// Test helpers for the USDT flow: a stand-in USDT (the Tolk Notcoin jetton in
// tests/jetton, same wallet layout as Tether's), a Marketplace that accepts it,
// and the sender-side steps the frontend performs — mint, transfer with the
// CreateOrder payload, read balances.
import "@acton/build"
import "@acton/emulation/network"
import "@acton/emulation/testing"
import "@acton/testing/expect"

import "@contracts/types"
import "@wrappers/Marketplace.gen"
import "@wrappers/Order.gen"
import "@tests/jetton/messages"
import "@tests/jetton/storage"

// What the UI attaches to the create transfer in total: exactly the 0.1 create
// fee. CREATE_TON of it is forwarded to the Marketplace; every hop's unused coin
// comes back to the order (see World.create), so the order keeps 0.1 - network.
const CREATE_ATTACH = ton("0.1")
const CREATE_TON = ton("0.08")
// What the UI attaches to confirm / claim / a Funding cancel: only the network
// fee of running the order's code. The payout itself is paid by the order.
const NET_FEE = ton("0.01")
// What the UI attaches to a Rescue (a closed order is empty, so the caller brings
// the payout gas and gets the unused part back).
const PAYOUT = ton("0.1")
// The delivery time test orders use: the longest allowed, 14 days.
const DELIVERY_TIME = 14 * 24 * 60 * 60

// A delivery secret and its on-chain commitment. The commitment is the
// representation hash of a cell holding the 256-bit secret — exactly the
// construct ConfirmWithCode verifies and the frontend reproduces with @ton/core.
const SECRET: uint256 = 0xC0DE1234C0DE1234C0DE1234C0DE1234C0DE1234C0DE1234C0DE1234C0DE1234
const WRONG_SECRET: uint256 = 0xBADC0DE

fun secretHashOf(secret: uint256): uint256 {
    return beginCell().storeUint(secret, 256).endCell().hash();
}

// USDT has 6 decimals: usdt(10) is 10 USDT.
fun usdt(whole: int): coins {
    return (whole * 1000000) as coins;
}

struct World {
    minter: address
    market: Marketplace
    owner: Treasury
}

// Deploy a jetton minter whose admin (the only one who may mint) is `admin`.
fun deployMinter(admin: Treasury): address {
    val stateInit = ContractState {
        code: build("JettonMinter"),
        data: (MinterStorage {
            totalSupply: 0,
            adminAddress: admin.address,
            nextAdminAddress: null,
            jettonWalletCode: build("JettonWallet"),
            metadataUri: "",
        }).toCell(),
    };
    net.send(
        admin.address,
        createMessage({
            bounce: false,
            value: ton("1"),
            dest: { stateInit },
            body: TopUpTons {},
        }),
    );
    return AutoDeployAddress { stateInit }.calculateAddress();
}

fun walletOf(minter: address, owner: address): address {
    return net.runGetMethod(minter, "get_wallet_address", [owner]);
}

struct WalletData {
    balance: coins
    owner: address
    minter: address
    code: cell
}

fun balanceOf(minter: address, owner: address): coins {
    val wallet = walletOf(minter, owner);
    if (!testing.isDeployed(wallet)) {
        return 0;
    }
    val data: WalletData = net.runGetMethod(wallet, "get_wallet_data");
    return data.balance;
}

// The TL-B `Either Cell ^Cell` forward payload with nothing in it.
fun emptyPayload(): RemainingBitsAndRefs {
    return beginCell().storeBool(false).endCell().beginParse();
}

fun mint(minter: address, admin: Treasury, to: address, amount: coins) {
    net.send(
        admin.address,
        createMessage({
            bounce: true,
            value: ton("0.2"),
            dest: minter,
            body: MintNewJettons {
                queryId: 0,
                mintRecipient: to,
                tonAmount: ton("0.1"),
                internalTransferMsg: (InternalTransferStep {
                    queryId: 0,
                    jettonAmount: amount,
                    transferInitiator: null,
                    sendExcessesTo: null,
                    forwardTonAmount: 0,
                    forwardPayload: emptyPayload(),
                }).toCell(),
            },
        }),
    );
}

// A jetton transfer exactly as a wallet app sends it: to the sender's OWN
// jetton wallet, which moves the tokens to `to`'s wallet and (forwardTon > 0)
// notifies `to` with `payload`.
fun sendJettons(
    minter: address,
    from: Treasury,
    to: address,
    amount: coins,
    forwardTon: coins,
    payload: RemainingBitsAndRefs,
    attach: coins? = null,
    excessesTo: address? = null,
): SendResultList {
    return net.send(
        from.address,
        createMessage({
            bounce: true,
            value: attach == null ? forwardTon + ton("0.1") : attach!,
            dest: walletOf(minter, from.address),
            body: AskToTransfer {
                queryId: 0,
                jettonAmount: amount,
                transferRecipient: to,
                sendExcessesTo: excessesTo == null ? from.address : excessesTo!,
                customPayload: null,
                forwardTonAmount: forwardTon,
                forwardPayload: payload,
            },
        }),
    );
}

// The create payload the frontend builds: CreateOrder in a ref.
fun payloadOf(p: CreateOrder): RemainingBitsAndRefs {
    return beginCell().storeBool(true).storeRef(p.toCell()).endCell().beginParse();
}

fun orderParams(nonce: uint64, referral: address?): CreateOrder {
    return {
        nonce,
        createdAt: 1700000000,
        deliveryTime: DELIVERY_TIME,
        description: createEmptyCell(),
        area: createEmptyCell(),
        origin: createEmptyCell(),
        senderContact: createEmptyCell(),
        secretHash: secretHashOf(SECRET),
        referral,
    };
}

fun setupWorld(): World {
    val owner = testing.treasury("owner");
    val minter = deployMinter(testing.treasury("tether"));
    val market = Marketplace.fromStorage({
        owner: owner.address,
        orderCode: build("Order"),
        orderCount: 0,
        usdtMaster: minter,
        jettonWalletCode: build("JettonWallet"),
    });
    val res = market.deploy(owner.address, { value: ton("1") });
    expect(res).toHaveSuccessfulDeploy({ to: market.address });
    return {
        minter,
        market,
        owner,
    };
}

fun World.mintUsdt(self, to: address, amount: coins) {
    mint(self.minter, testing.treasury("tether"), to, amount);
}

fun World.usdtOf(self, owner: address): coins {
    return balanceOf(self.minter, owner);
}

fun World.walletOf(self, owner: address): address {
    return walletOf(self.minter, owner);
}

// Mint `reward` USDT to the sender and create an order with it, the way the app
// does: exactly CREATE_ATTACH in total, and the unused coin of the sender's own
// USDT hop sent to the order (its address is known before signing). A test that
// forwards more than the app does attaches a little on top of its forward.
fun World.create(
    self,
    sender: Treasury,
    reward: coins,
    p: CreateOrder,
    forwardTon: coins = CREATE_TON,
): SendResultList {
    self.mintUsdt(sender.address, reward);
    return sendJettons(
        self.minter,
        sender,
        self.market.address,
        reward,
        forwardTon,
        payloadOf(p),
        forwardTon > CREATE_TON ? forwardTon + ton("0.02") : CREATE_ATTACH,
        self.orderOf(sender.address, reward, p).address,
    );
}

fun World.orderOf(self, sender: address, reward: coins, p: CreateOrder): Order {
    return Order.fromAddress(
        self
            .market
            .orderAddress(
                sender,
                reward,
                p.nonce,
                p.createdAt,
                p.deliveryTime,
                p.description,
                p.area,
                p.origin,
                p.senderContact,
                p.secretHash,
                p.referral,
            ),
    );
}

// A funded Open order, created through the Marketplace like the app does.
fun World.openOrder(self, sender: Treasury, reward: coins, referral: address? = null): Order {
    val p = orderParams(0, referral);
    self.create(sender, reward, p);
    val order = self.orderOf(sender.address, reward, p);
    expect(order.status()).toEqual(OrderStatus.Open);
    return order;
}
