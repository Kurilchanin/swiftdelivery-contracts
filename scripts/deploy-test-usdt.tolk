import "@acton/build"
import "@acton/env"
import "@acton/io"
import "@acton/emulation/network"
import "@acton/emulation/scripts"
import "@tests/jetton/messages"
import "@tests/jetton/storage"

// A test USDT for testnet: the jetton from tests/jetton (Tether's wallet layout,
// 6 decimals) with the "deployer" wallet as its only minter. The public
// test-USDT faucet bot stopped working (2026-09), and a Marketplace accepts the
// one master fixed at its deploy, so testnet runs use this jetton instead.
//
//   acton script scripts/deploy-test-usdt.tolk --net testnet
//       deploys it (once — the address is always the same) and mints 100 test
//       USDT to the "courier" wallet
//   MINT_TO=<address> AMOUNT_USDT=<n> acton script scripts/deploy-test-usdt.tolk --net testnet
//       mints n test USDT to any address, e.g. your own testnet wallet
//
// Then deploy a Marketplace for it: USDT_MASTER=<printed master> ... deploy.tolk
fun main() {
    val admin = scripts.wallet("deployer");
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
    val master = AutoDeployAddress { stateInit }.calculateAddress();
    if (!scripts.isContractDeployed(master)) {
        net.send(admin.address, createMessage({
            bounce: false,
            value: ton("0.05"),
            dest: { stateInit },
            body: TopUpTons {},
        })).waitForTrace();
    }
    println("test USDT master {}", master);

    val whole = env<int>("AMOUNT_USDT") ?? 100;
    val to = env<address>("MINT_TO") ?? scripts.wallet("courier").address;
    net.send(admin.address, createMessage({
        bounce: true,
        value: ton("0.15"),
        dest: master,
        body: MintNewJettons {
            queryId: 0,
            mintRecipient: to,
            tonAmount: ton("0.1"),
            internalTransferMsg: (InternalTransferStep {
                queryId: 0,
                jettonAmount: (whole * 1000000) as coins,
                transferInitiator: null,
                sendExcessesTo: admin.address,
                forwardTonAmount: 0,
                forwardPayload: beginCell().storeBool(false).endCell().beginParse(),
            }).toCell(),
        },
    })).waitForTrace();
    println("minted {} test USDT to {}", whole, to);
}
