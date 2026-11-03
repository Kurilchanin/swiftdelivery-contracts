import "@acton/build"
import "@acton/crypto"
import "@acton/io"
import "@acton/emulation/network"
import "@acton/emulation/scripts"
import "@contracts/types"
import "@wrappers/Marketplace.gen"

// Prints what the contracts compute for fixed inputs — the create payload's hash,
// the order address the Marketplace's orderAddress() getter returns, and an
// accept invite (key pair from a seed, the signed cell's hash, the signature) — so the
// frontend test (src/contracts/orders.test.js in the app repo) can check that it
// computes the very same thing. Run it after ANY change to Order or Marketplace,
// and paste the new values into that test:
//
//   acton script scripts/xcheck.tolk
//
// Local emulation only; nothing is broadcast.
fun main() {
    val owner = address("0:1111111111111111111111111111111111111111111111111111111111111111");
    val master = address("EQCxE6mUtQJKFnGfaROTKOt1lZbDiiX1kCixRv7Nw2Id_sDs");
    val referral = address("0:2222222222222222222222222222222222222222222222222222222222222222");
    val deployer = scripts.wallet("deployer");
    val keys = crypto.seedToKeyPair(0x5EED5EED5EED5EED5EED5EED5EED5EED5EED5EED5EED5EED5EED5EED5EED5EED);
    val market = Marketplace.fromStorage({
        owner,
        orderCode: build("Order"),
        orderCount: 0,
        usdtMaster: master,
        jettonWalletCode: build("JettonWallet"),
    });
    market.deploy(deployer.address, { value: ton("0.5") });

    val p = CreateOrder {
        nonce: 12345,
        createdAt: 1700000000,
        deliveryTime: 14 * 24 * 60 * 60,
        description: beginCell().storeUint(1, 8).endCell(),
        area: beginCell().storeUint(2, 8).endCell(),
        origin: beginCell().storeUint(3, 8).endCell(),
        clientContact: beginCell().storeUint(4, 8).endCell(),
        secretHash: 0xC0DE1234C0DE1234C0DE1234C0DE1234C0DE1234C0DE1234C0DE1234C0DE1234,
        acceptKey: keys.publicKey,
        referral,
    };
    var pNull = p;
    pNull.referral = null;

    println("MARKET {}", market.address);
    println("PAYLOAD_HASH {}", p.toCell().hash());
    println("PAYLOAD_NULL_HASH {}", pNull.toCell().hash());
    val client = address("0:3333333333333333333333333333333333333333333333333333333333333333");
    println("ORDER {}", market.orderAddress(client, 10000000, p.nonce, p.createdAt,
        p.deliveryTime, p.description, p.area, p.origin, p.clientContact, p.secretHash,
        p.acceptKey, p.referral));
    println("ORDER_NULL {}", market.orderAddress(client, 10000000, p.nonce, p.createdAt,
        p.deliveryTime, p.description, p.area, p.origin, p.clientContact, p.secretHash,
        p.acceptKey, null));

    val invite = AcceptInvite {
        order: client, // any two addresses do for the check
        courier: referral,
        validUntil: 1700003600,
    };
    println("ACCEPT_KEY {}", keys.publicKey);
    println("INVITE_HASH {}", invite.toCell().hash());
    var sig = crypto.sign(keys.privateKey, invite.toCell());
    println("INVITE_SIG_R {}", sig.loadUint(256));
    println("INVITE_SIG_S {}", sig.loadUint(256));
}
