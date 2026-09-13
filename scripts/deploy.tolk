import "@acton/build"
import "@acton/env"
import "@acton/io"
import "@acton/emulation/network"
import "@acton/emulation/scripts"
import "@contracts/types"
import "@wrappers/Marketplace.gen"

// Deploys the single Marketplace contract. The Order code, the owner and the
// one USDT it accepts are set here and can never change afterwards.
//
//   USDT_MASTER=<master> acton script scripts/deploy.tolk --net testnet
//   USDT_MASTER=<master> OWNER=<fee wallet> acton script scripts/deploy.tolk --net mainnet
//
// USDT_MASTER (required):
//   mainnet  EQCxE6mUtQJKFnGfaROTKOt1lZbDiiX1kCixRv7Nw2Id_sDs  (Tether USD₮)
//   testnet  a test USDT made with scripts/deploy-test-usdt.tolk (same stablecoin
//            code; the public test-USDT faucet no longer works)
// OWNER (optional, defaults to the deployer): the platform fee wallet. It is
//   frozen forever — there is no message that can change it.
//
// The jetton wallet code is read from the master itself, so it is always the
// right one for the network: on mainnet a library cell, on testnet the plain code.

// What get_jetton_data returns (TEP-74).
struct JettonData {
    totalSupply: int
    mintable: bool
    admin: address?
    content: cell
    walletCode: cell
}

fun main() {
    val deployer = scripts.wallet("deployer");
    val master = env<address>("USDT_MASTER");
    if (master == null) {
        println("USDT_MASTER is not set — see the header of scripts/deploy.tolk");
        return;
    }
    val owner = env<address>("OWNER") ?? deployer.address;
    val jetton: JettonData = net.runGetMethod(master!, "get_jetton_data");

    val market = Marketplace.fromStorage({
        owner,
        orderCode: build("Order"),
        orderCount: 0,
        usdtMaster: master!,
        jettonWalletCode: jetton.walletCode,
    });
    val res = market.deploy(deployer.address, { value: ton("0.1") });
    println(res.waitForTrace());

    println("Deployed Marketplace to {}", market.address);
    println("Owner is {}", market.owner());
    println("USDT master is {}", market.usdtMaster());
    println("Order count is {}", market.orderCount());

    // The Marketplace's wallet math must agree with the master's, or it would
    // reject every real USDT transfer. Checked on the live contracts.
    val mine: address = market.usdtWalletOf(market.address);
    val theirs: address = net.runGetMethod(master!, "get_wallet_address", [market.address]);
    println("USDT wallet MATCH = {}", mine == theirs);
}
