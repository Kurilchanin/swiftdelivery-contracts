// AUTO-GENERATED, do not edit
// It's a TypeScript wrapper for a Marketplace contract in Tolk.
/* eslint-disable */

import * as c from '@ton/core';
import { beginCell, ContractProvider, Sender, SendMode } from '@ton/core';

// ————————————————————————————————————————————
//   predefined types and functions
//

type RemainingBitsAndRefs = c.Slice

type StoreCallback<T> = (obj: T, b: c.Builder) => void
type LoadCallback<T> = (s: c.Slice) => T

export type CellRef<T> = {
    ref: T
}

function makeCellFrom<T>(self: T, storeFn_T: StoreCallback<T>): c.Cell {
    let b = beginCell();
    storeFn_T(self, b);
    return b.endCell();
}

function loadAndCheckPrefix32(s: c.Slice, expected: number, structName: string): void {
    let prefix = s.loadUint(32);
    if (prefix !== expected) {
        throw new Error(`Incorrect prefix for '${structName}': expected 0x${expected.toString(16).padStart(8, '0')}, got 0x${prefix.toString(16).padStart(8, '0')}`);
    }
}

function lookupPrefix(s: c.Slice, expected: number, prefixLen: number): boolean {
    return s.remainingBits >= prefixLen && s.preloadUint(prefixLen) === expected;
}

function throwNonePrefixMatch(fieldPath: string): never {
    throw new Error(`Incorrect prefix for '${fieldPath}': none of variants matched`);
}

function storeCellRef<T>(cell: CellRef<T>, b: c.Builder, storeFn_T: StoreCallback<T>): void {
    let b_ref = c.beginCell();
    storeFn_T(cell.ref, b_ref);
    b.storeRef(b_ref.endCell());
}

function loadCellRef<T>(s: c.Slice, loadFn_T: LoadCallback<T>): CellRef<T> {
    let s_ref = s.loadRef().beginParse();
    return { ref: loadFn_T(s_ref) };
}

function storeTolkRemaining(v: RemainingBitsAndRefs, b: c.Builder): void {
    b.storeSlice(v);
}

function loadTolkRemaining(s: c.Slice): RemainingBitsAndRefs {
    let rest = s.clone();
    s.loadBits(s.remainingBits);
    while (s.remainingRefs) {
        s.loadRef();
    }
    return rest;
}

function storeTolkNullable<T>(v: T | null, b: c.Builder, storeFn_T: StoreCallback<T>): void {
    if (v === null) {
        b.storeUint(0, 1);
    } else {
        b.storeUint(1, 1);
        storeFn_T(v, b);
    }
}

// ————————————————————————————————————————————
//   parse get methods result from a TVM stack
//

class StackReader {
    constructor(private tuple: c.TupleItem[]) {
    }

    static fromGetMethod(expectedN: number, getMethodResult: { stack: c.TupleReader }): StackReader {
        let tuple = [] as c.TupleItem[];
        while (getMethodResult.stack.remaining) {
            tuple.push(getMethodResult.stack.pop());
        }
        if (tuple.length !== expectedN) {
            throw new Error(`expected ${expectedN} stack width, got ${tuple.length}`);
        }
        return new StackReader(tuple);
    }

    private popExpecting<ItemT>(itemType: string): ItemT {
        const item = this.tuple.shift();
        if (item?.type === itemType) {
            return item as ItemT;
        }
        throw new Error(`not '${itemType}' on a stack`);
    }

    private popCellLike(): c.Cell {
        const item = this.tuple.shift();
        if (item && (item.type === 'cell' || item.type === 'slice' || item.type === 'builder')) {
            return item.cell;
        }
        throw new Error(`not cell/slice on a stack`);
    }

    readBigInt(): bigint {
        return this.popExpecting<c.TupleItemInt>('int').value;
    }

    readBoolean(): boolean {
        return this.popExpecting<c.TupleItemInt>('int').value !== 0n;
    }

    readCell(): c.Cell {
        return this.popCellLike();
    }

    readSlice(): c.Slice {
        return this.popCellLike().beginParse();
    }
}

// ————————————————————————————————————————————
//   auto-generated serializers to/from cells
//

type coins = bigint

type uint32 = bigint
type uint64 = bigint
type uint256 = bigint

/**
 > struct (0xa00a0006) InitWallet {
 >     wallet: address
 > }
 */
export interface InitWallet {
    readonly $: 'InitWallet'
    wallet: c.Address
}

export const InitWallet = {
    PREFIX: 0xa00a0006,

    create(args: {
        wallet: c.Address
    }): InitWallet {
        return {
            $: 'InitWallet',
            ...args
        }
    },
    fromSlice(s: c.Slice): InitWallet {
        loadAndCheckPrefix32(s, 0xa00a0006, 'InitWallet');
        return {
            $: 'InitWallet',
            wallet: s.loadAddress(),
        }
    },
    store(self: InitWallet, b: c.Builder): void {
        b.storeUint(0xa00a0006, 32);
        b.storeAddress(self.wallet);
    },
    toCell(self: InitWallet): c.Cell {
        return makeCellFrom<InitWallet>(self, InitWallet.store);
    }
}

/**
 > struct (0x0f8a7ea5) JettonTransfer {
 >     queryId: uint64
 >     amount: coins
 >     destination: address
 >     responseDestination: address
 >     customPayload: cell?
 >     forwardTonAmount: coins
 >     forwardPayloadInRef: bool
 > }
 */
export interface JettonTransfer {
    readonly $: 'JettonTransfer'
    queryId: uint64
    amount: coins
    destination: c.Address
    responseDestination: c.Address
    customPayload: c.Cell | null
    forwardTonAmount: coins
    forwardPayloadInRef: boolean
}

export const JettonTransfer = {
    PREFIX: 0x0f8a7ea5,

    create(args: {
        queryId: uint64
        amount: coins
        destination: c.Address
        responseDestination: c.Address
        customPayload: c.Cell | null
        forwardTonAmount: coins
        forwardPayloadInRef: boolean
    }): JettonTransfer {
        return {
            $: 'JettonTransfer',
            ...args
        }
    },
    fromSlice(s: c.Slice): JettonTransfer {
        loadAndCheckPrefix32(s, 0x0f8a7ea5, 'JettonTransfer');
        return {
            $: 'JettonTransfer',
            queryId: s.loadUintBig(64),
            amount: s.loadCoins(),
            destination: s.loadAddress(),
            responseDestination: s.loadAddress(),
            customPayload: s.loadBoolean() ? s.loadRef() : null,
            forwardTonAmount: s.loadCoins(),
            forwardPayloadInRef: s.loadBoolean(),
        }
    },
    store(self: JettonTransfer, b: c.Builder): void {
        b.storeUint(0x0f8a7ea5, 32);
        b.storeUint(self.queryId, 64);
        b.storeCoins(self.amount);
        b.storeAddress(self.destination);
        b.storeAddress(self.responseDestination);
        storeTolkNullable<c.Cell>(self.customPayload, b,
            (v,b) => b.storeRef(v)
        );
        b.storeCoins(self.forwardTonAmount);
        b.storeBit(self.forwardPayloadInRef);
    },
    toCell(self: JettonTransfer): c.Cell {
        return makeCellFrom<JettonTransfer>(self, JettonTransfer.store);
    }
}

/**
 > struct (0x7362d09c) JettonNotify {
 >     queryId: uint64
 >     amount: coins
 >     from: address?
 >     forwardPayload: RemainingBitsAndRefs
 > }
 */
export interface JettonNotify {
    readonly $: 'JettonNotify'
    queryId: uint64
    amount: coins
    from: c.Address | null
    forwardPayload: RemainingBitsAndRefs
}

export const JettonNotify = {
    PREFIX: 0x7362d09c,

    create(args: {
        queryId: uint64
        amount: coins
        from: c.Address | null
        forwardPayload: RemainingBitsAndRefs
    }): JettonNotify {
        return {
            $: 'JettonNotify',
            ...args
        }
    },
    fromSlice(s: c.Slice): JettonNotify {
        loadAndCheckPrefix32(s, 0x7362d09c, 'JettonNotify');
        return {
            $: 'JettonNotify',
            queryId: s.loadUintBig(64),
            amount: s.loadCoins(),
            from: s.loadMaybeAddress(),
            forwardPayload: loadTolkRemaining(s),
        }
    },
    store(self: JettonNotify, b: c.Builder): void {
        b.storeUint(0x7362d09c, 32);
        b.storeUint(self.queryId, 64);
        b.storeCoins(self.amount);
        b.storeAddress(self.from);
        storeTolkRemaining(self.forwardPayload, b);
    },
    toCell(self: JettonNotify): c.Cell {
        return makeCellFrom<JettonNotify>(self, JettonNotify.store);
    }
}

/**
 > struct (0xd53276db) Excesses {
 >     queryId: uint64
 > }
 */
export interface Excesses {
    readonly $: 'Excesses'
    queryId: uint64
}

export const Excesses = {
    PREFIX: 0xd53276db,

    create(args: {
        queryId: uint64
    }): Excesses {
        return {
            $: 'Excesses',
            ...args
        }
    },
    fromSlice(s: c.Slice): Excesses {
        loadAndCheckPrefix32(s, 0xd53276db, 'Excesses');
        return {
            $: 'Excesses',
            queryId: s.loadUintBig(64),
        }
    },
    store(self: Excesses, b: c.Builder): void {
        b.storeUint(0xd53276db, 32);
        b.storeUint(self.queryId, 64);
    },
    toCell(self: Excesses): c.Cell {
        return makeCellFrom<Excesses>(self, Excesses.store);
    }
}

/**
 > struct (0xa00a0100) OrderCreated {
 >     orderAddress: address
 >     sender: address
 >     reward: coins
 >     area: cell
 > }
 */
export interface OrderCreated {
    readonly $: 'OrderCreated'
    orderAddress: c.Address
    sender: c.Address
    reward: coins
    area: c.Cell
}

export const OrderCreated = {
    PREFIX: 0xa00a0100,

    create(args: {
        orderAddress: c.Address
        sender: c.Address
        reward: coins
        area: c.Cell
    }): OrderCreated {
        return {
            $: 'OrderCreated',
            ...args
        }
    },
    fromSlice(s: c.Slice): OrderCreated {
        loadAndCheckPrefix32(s, 0xa00a0100, 'OrderCreated');
        return {
            $: 'OrderCreated',
            orderAddress: s.loadAddress(),
            sender: s.loadAddress(),
            reward: s.loadCoins(),
            area: s.loadRef(),
        }
    },
    store(self: OrderCreated, b: c.Builder): void {
        b.storeUint(0xa00a0100, 32);
        b.storeAddress(self.orderAddress);
        b.storeAddress(self.sender);
        b.storeCoins(self.reward);
        b.storeRef(self.area);
    },
    toCell(self: OrderCreated): c.Cell {
        return makeCellFrom<OrderCreated>(self, OrderCreated.store);
    }
}

/**
 > struct (0xa00a0107) CreateRefused {
 >     sender: address
 >     amount: coins
 > }
 */
export interface CreateRefused {
    readonly $: 'CreateRefused'
    sender: c.Address
    amount: coins
}

export const CreateRefused = {
    PREFIX: 0xa00a0107,

    create(args: {
        sender: c.Address
        amount: coins
    }): CreateRefused {
        return {
            $: 'CreateRefused',
            ...args
        }
    },
    fromSlice(s: c.Slice): CreateRefused {
        loadAndCheckPrefix32(s, 0xa00a0107, 'CreateRefused');
        return {
            $: 'CreateRefused',
            sender: s.loadAddress(),
            amount: s.loadCoins(),
        }
    },
    store(self: CreateRefused, b: c.Builder): void {
        b.storeUint(0xa00a0107, 32);
        b.storeAddress(self.sender);
        b.storeCoins(self.amount);
    },
    toCell(self: CreateRefused): c.Cell {
        return makeCellFrom<CreateRefused>(self, CreateRefused.store);
    }
}

/**
 > struct MarketplaceStorage {
 >     owner: address
 >     orderCode: cell
 >     orderCount: uint32
 >     usdtMaster: address
 >     jettonWalletCode: cell
 > }
 */
export interface MarketplaceStorage {
    readonly $: 'MarketplaceStorage'
    owner: c.Address
    orderCode: c.Cell
    orderCount: uint32
    usdtMaster: c.Address
    jettonWalletCode: c.Cell
}

export const MarketplaceStorage = {
    create(args: {
        owner: c.Address
        orderCode: c.Cell
        orderCount: uint32
        usdtMaster: c.Address
        jettonWalletCode: c.Cell
    }): MarketplaceStorage {
        return {
            $: 'MarketplaceStorage',
            ...args
        }
    },
    fromSlice(s: c.Slice): MarketplaceStorage {
        return {
            $: 'MarketplaceStorage',
            owner: s.loadAddress(),
            orderCode: s.loadRef(),
            orderCount: s.loadUintBig(32),
            usdtMaster: s.loadAddress(),
            jettonWalletCode: s.loadRef(),
        }
    },
    store(self: MarketplaceStorage, b: c.Builder): void {
        b.storeAddress(self.owner);
        b.storeRef(self.orderCode);
        b.storeUint(self.orderCount, 32);
        b.storeAddress(self.usdtMaster);
        b.storeRef(self.jettonWalletCode);
    },
    toCell(self: MarketplaceStorage): c.Cell {
        return makeCellFrom<MarketplaceStorage>(self, MarketplaceStorage.store);
    }
}

// ————————————————————————————————————————————
//    class Marketplace
//

interface ExtraSendOptions {
    bounce?: boolean                    // default: false
    sendMode?: SendMode                 // default: SendMode.PAY_GAS_SEPARATELY
    extraCurrencies?: c.ExtraCurrency   // default: empty dict
}

interface DeployedAddrOptions {
    workchain?: number                  // default: 0 (basechain)
    toShard?: { fixedPrefixLength: number; closeTo: c.Address }
    overrideContractCode?: c.Cell
}

function calculateDeployedAddress(code: c.Cell, data: c.Cell, options: DeployedAddrOptions): c.Address {
    const stateInitCell = beginCell().store(c.storeStateInit({
        code,
        data,
        splitDepth: options.toShard?.fixedPrefixLength,
        special: null,
        libraries: null,
    })).endCell();

    let addrHash = stateInitCell.hash();
    if (options.toShard) {
        const shardDepth = options.toShard.fixedPrefixLength;
        addrHash = beginCell()
            .storeBits(new c.BitString(options.toShard.closeTo.hash, 0, shardDepth))
            .storeBits(new c.BitString(stateInitCell.hash(), shardDepth, 256 - shardDepth))
            .endCell()
            .beginParse().loadBuffer(32);
    }

    return new c.Address(options.workchain ?? 0, addrHash);
}

export class Marketplace implements c.Contract {
    static CodeCell = c.Cell.fromBase64('te6ccgECGQEAA/cAART/APSkE/S88sgLAQIBYgIDAgLPBAUCASAMDQFDPiRkTDgINcsI5sWhOTjAtcsJqmTttwxkTDghA8BxwDy9IAYB9ztou37Im6SXwTgcIBAJAOCCvrwgLmOGF8DIIIID0JAuZRfA9sx4IIK+vCAcfgoWd6LAsjPkoAoBB5SYPpSJfoCycjPhyASznHPC2HMyXL7AG3Ii8D4p+pQAAAAAAAAAAjPFlAF+gIV+lIS+lIS9ADPhBDJyM+FiBT6UgGALAvgx7UTQ+kjU0x8g+kjXTPgoIsjPhAIS+lL6UskhyM+E0MzM+RbIz4oAQMv/z1D4kiHHBfLgyW1tbW1tbW1tbXAREdM/MfoA+lBTIVYUVhRWFFYTVhNWFlYUm1ttbW1tbW1tbW1w7eO6eX/tEYrtQe3xAfL/lVYQbsMAkX/iBwgAdGyThA870gBQu/L0CdTR0NcsJQBQAATyv9M/0x/TH9TU1NTT//pQ0QkREQkJERAJEJ8QnhCdEJqBAIYC/pF/mlYRgggPQkC5wwDikX+a+JeCCvrwgLnDAOKRf44RIG6zmCD6RDDDAMMAkXDiwwDikX+YJoIBUYC5wwDikX+ZJoIIEnUAvMMA4pkQn18P+JcT8AHgDaQvyPpSL88Uyx8azsntVG2I+ChtAcj6UvpUyREQyPpSE8wSzBnL/xsUCQH++lQczMlUfbzI+lIZ+lQTzBfMGcxQCPoCz4QWEss/yx/PkAAAAAIVyx/MyVMEyM+E0MzM+RbIz4oAQMv/z1D4l6sAIcjPhAL6UhX6UslQA8jPhNDMzPkWyM+KAEDL/89QyM+JCAFTJsjPhNDMzPkWzwv/UAT6AoEAjM8LcBXMFAoA8szPkoAoABr6Uslx+wCLAsjPkoAoBAJSMPpSFfpSJfoCE8zJyM+HIBTOcc8LYRPMyXL7APgnbxD4l6Fy+wJtggiYloDIi8D4p+pQAAAAAAAAAAjPFlAF+gJSMPpSE/pSEvQAWPoCz4HJyM+FiBL6UnHPC27MyYMG+wAAGPoCcc8LahLMyQH7AAIBag4PAgEgEBEAEbFHe1E0PpIMIAAXsCg7UTQ1DHXTPkAgAgEgEhMAE7vEftRNDXTPkAgBtbW6vaiaH0ka6Y2xHwUNoDkfSl9KmSCZH0pC+YLZgpl/4l9KmZkhWR9KQl9KgpmCWZmKAL9AWfCCwnln+WP58gAAAABZY+JZmSA5GfCaGZmfItkZ8UAIGX/56hAUAgEgFRYAAAIBIBcYAB2zKntRND6SDHTHzH6SDCAAF6zzdqJofSQY64WPwABbrNT2omh9JBjqGOmPmP0ka6ZkZ8IBCf0pfSlkgORnwmhmZnyLZGfFACBl/+eoQA==');

    static Errors = {
        'MarketplaceErrors.NotJettonWallet': 201,
        'MarketplaceErrors.InvalidMessage': 65535,
    }

    readonly address: c.Address
    readonly init: { code: c.Cell, data: c.Cell } | undefined

    protected constructor(address: c.Address, init?: { code: c.Cell, data: c.Cell }) {
        this.address = address;
        this.init = init;
    }

    static fromAddress(address: c.Address) {
        return new Marketplace(address);
    }

    static fromStorage(emptyStorage: {
        owner: c.Address
        orderCode: c.Cell
        orderCount: uint32
        usdtMaster: c.Address
        jettonWalletCode: c.Cell
    }, deployedOptions?: DeployedAddrOptions) {
        const initialState = {
            code: deployedOptions?.overrideContractCode ?? Marketplace.CodeCell,
            data: MarketplaceStorage.toCell(MarketplaceStorage.create(emptyStorage)),
        };
        const address = calculateDeployedAddress(initialState.code, initialState.data, deployedOptions ?? {});
        return new Marketplace(address, initialState);
    }

    static createCellOfJettonNotify(body: {
        queryId: uint64
        amount: coins
        from: c.Address | null
        forwardPayload: RemainingBitsAndRefs
    }) {
        return JettonNotify.toCell(JettonNotify.create(body));
    }

    static createCellOfExcesses(body: {
        queryId: uint64
    }) {
        return Excesses.toCell(Excesses.create(body));
    }

    async sendDeploy(provider: ContractProvider, via: Sender, msgValue: coins, extraOptions?: ExtraSendOptions) {
        return provider.internal(via, {
            value: msgValue,
            body: c.Cell.EMPTY,
            ...extraOptions
        });
    }

    async sendJettonNotify(provider: ContractProvider, via: Sender, msgValue: coins, body: {
        queryId: uint64
        amount: coins
        from: c.Address | null
        forwardPayload: RemainingBitsAndRefs
    }, extraOptions?: ExtraSendOptions) {
        return provider.internal(via, {
            value: msgValue,
            body: JettonNotify.toCell(JettonNotify.create(body)),
            ...extraOptions
        });
    }

    async sendExcesses(provider: ContractProvider, via: Sender, msgValue: coins, body: {
        queryId: uint64
    }, extraOptions?: ExtraSendOptions) {
        return provider.internal(via, {
            value: msgValue,
            body: Excesses.toCell(Excesses.create(body)),
            ...extraOptions
        });
    }

    async getOrderCount(provider: ContractProvider): Promise<uint32> {
        const r = StackReader.fromGetMethod(1, await provider.get('orderCount', []));
        return r.readBigInt();
    }

    async getOwner(provider: ContractProvider): Promise<c.Address> {
        const r = StackReader.fromGetMethod(1, await provider.get('owner', []));
        return r.readSlice().loadAddress();
    }

    async getOrderCodeHash(provider: ContractProvider): Promise<uint256> {
        const r = StackReader.fromGetMethod(1, await provider.get('orderCodeHash', []));
        return r.readBigInt();
    }

    async getUsdtMaster(provider: ContractProvider): Promise<c.Address> {
        const r = StackReader.fromGetMethod(1, await provider.get('usdtMaster', []));
        return r.readSlice().loadAddress();
    }

    async getJettonWalletCodeHash(provider: ContractProvider): Promise<uint256> {
        const r = StackReader.fromGetMethod(1, await provider.get('jettonWalletCodeHash', []));
        return r.readBigInt();
    }

    async getUsdtWalletOf(provider: ContractProvider, owner: c.Address): Promise<c.Address> {
        const r = StackReader.fromGetMethod(1, await provider.get('usdtWalletOf', [
            { type: 'slice', cell: makeCellFrom<c.Address>(owner,
                (v,b) => b.storeAddress(v)
            ) },
        ]));
        return r.readSlice().loadAddress();
    }

    async getOrderAddress(provider: ContractProvider, sender: c.Address, reward: coins, nonce: uint64, createdAt: uint32, deliveryTime: uint32, description: c.Cell, area: c.Cell, origin: c.Cell, senderContact: c.Cell, secretHash: uint256, referral: c.Address | null): Promise<c.Address> {
        const r = StackReader.fromGetMethod(1, await provider.get('orderAddress', [
            { type: 'slice', cell: makeCellFrom<c.Address>(sender,
                (v,b) => b.storeAddress(v)
            ) },
            { type: 'int', value: reward },
            { type: 'int', value: nonce },
            { type: 'int', value: createdAt },
            { type: 'int', value: deliveryTime },
            { type: 'cell', cell: description },
            { type: 'cell', cell: area },
            { type: 'cell', cell: origin },
            { type: 'cell', cell: senderContact },
            { type: 'int', value: secretHash },
            referral === null ? { type: 'null' } : { type: 'slice', cell: makeCellFrom<c.Address | null>(referral,
                (v,b) => b.storeAddress(v)
            ) },
        ]));
        return r.readSlice().loadAddress();
    }
}
