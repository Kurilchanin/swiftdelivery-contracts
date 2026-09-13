import "@acton/build"
import "@acton/io"
import "@acton/emulation/network"
import "@acton/emulation/scripts"
import "@contracts/types"
import "@wrappers/Marketplace.gen"

// Prints what the contracts compute for fixed inputs — the create payload's hash
// and the order address the Marketplace's orderAddress() getter returns — so the
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
        senderContact: beginCell().storeUint(4, 8).endCell(),
        secretHash: 0xC0DE1234C0DE1234C0DE1234C0DE1234C0DE1234C0DE1234C0DE1234C0DE1234,
        referral,
    };
    var pNull = p;
    pNull.referral = null;

    println("MARKET {}", market.address);
    println("PAYLOAD_HASH {}", p.toCell().hash());
    println("PAYLOAD_NULL_HASH {}", pNull.toCell().hash());
    val sender = address("0:3333333333333333333333333333333333333333333333333333333333333333");
    println("ORDER {}", market.orderAddress(sender, 10000000, p.nonce, p.createdAt,
        p.deliveryTime, p.description, p.area, p.origin, p.senderContact, p.secretHash,
        p.referral));
    println("ORDER_NULL {}", market.orderAddress(sender, 10000000, p.nonce, p.createdAt,
        p.deliveryTime, p.description, p.area, p.origin, p.senderContact, p.secretHash, null));
}
