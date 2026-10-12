# Test-only USDT stand-in

These files are copied from
[ton-blockchain/tolk-bench](https://github.com/ton-blockchain/tolk-bench),
`contracts_Tolk/03_notcoin`, commit `57e1009743bfc19748caa95d76180d9e9793e4c5`,
under the MIT license in [LICENSE](LICENSE). One change: `get_jetton_data` in
`JettonMinter.tolk` reports 6 decimals (was 9), like USDT, so wallet apps show
the test USDT deployed from it (`scripts/deploy-test-usdt.tolk`) right.

It is the Tolk port of the Notcoin jetton. Its wallet keeps the same storage as
Tether's USDT wallet (`status:uint4 balance owner master`) and handles
transfers, notifications and bounces the same way, so the emulator tests
exercise the Marketplace / Order USDT logic as it runs on mainnet. It is never
deployed.

The real Tether wallet code (a library cell) is exercised separately on a local
fork of mainnet: `acton script scripts/fork-e2e.tolk --fork-net mainnet`.
