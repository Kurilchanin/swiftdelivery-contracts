// AUTO-GENERATED, do not edit
// It's a TypeScript wrapper for a Order contract in Tolk.
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

    readNullable<T>(readFn_T: (r: StackReader) => T): T | null {
        if (this.tuple[0].type === 'null') {
            this.tuple.shift();
            return null;
        }
        return readFn_T(this);
    }

    readCellRef<T>(loadFn_T: LoadCallback<T>): CellRef<T> {
        return { ref: loadFn_T(this.readCell().beginParse()) };
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
 > enum OrderStatus { 6 variants }
 */
export type OrderStatus = bigint

export const OrderStatus = {
    Open: 0n,
    Accepted: 1n,
    Completed: 2n,
    Cancelled: 3n,
    Expired: 4n,
    Funding: 5n,

    fromSlice(s: c.Slice): OrderStatus {
        return s.loadUintBig(8);
    },
    store(self: OrderStatus, b: c.Builder): void {
        b.storeUint(self, 8);
    },
    toCell(self: OrderStatus): c.Cell {
        return makeCellFrom<OrderStatus>(self, OrderStatus.store);
    }
}

/**
 > struct OrderJetton {
 >     marketplace: address
 >     wallet: address?
 > }
 */
export interface OrderJetton {
    readonly $: 'OrderJetton'
    marketplace: c.Address
    wallet: c.Address | null
}

export const OrderJetton = {
    create(args: {
        marketplace: c.Address
        wallet: c.Address | null
    }): OrderJetton {
        return {
            $: 'OrderJetton',
            ...args
        }
    },
    fromSlice(s: c.Slice): OrderJetton {
        return {
            $: 'OrderJetton',
            marketplace: s.loadAddress(),
            wallet: s.loadMaybeAddress(),
        }
    },
    store(self: OrderJetton, b: c.Builder): void {
        b.storeAddress(self.marketplace);
        b.storeAddress(self.wallet);
    },
    toCell(self: OrderJetton): c.Cell {
        return makeCellFrom<OrderJetton>(self, OrderJetton.store);
    }
}

/**
 > struct OrderExtra {
 >     owner: address
 >     clientContact: cell
 >     courierContact: cell
 >     secretHash: uint256
 >     referral: address?
 >     jetton: Cell<OrderJetton>
 > }
 */
export interface OrderExtra {
    readonly $: 'OrderExtra'
    owner: c.Address
    clientContact: c.Cell
    courierContact: c.Cell
    secretHash: uint256
    referral: c.Address | null
    jetton: CellRef<OrderJetton>
}

export const OrderExtra = {
    create(args: {
        owner: c.Address
        clientContact: c.Cell
        courierContact: c.Cell
        secretHash: uint256
        referral: c.Address | null
        jetton: CellRef<OrderJetton>
    }): OrderExtra {
        return {
            $: 'OrderExtra',
            ...args
        }
    },
    fromSlice(s: c.Slice): OrderExtra {
        return {
            $: 'OrderExtra',
            owner: s.loadAddress(),
            clientContact: s.loadRef(),
            courierContact: s.loadRef(),
            secretHash: s.loadUintBig(256),
            referral: s.loadMaybeAddress(),
            jetton: loadCellRef<OrderJetton>(s, OrderJetton.fromSlice),
        }
    },
    store(self: OrderExtra, b: c.Builder): void {
        b.storeAddress(self.owner);
        b.storeRef(self.clientContact);
        b.storeRef(self.courierContact);
        b.storeUint(self.secretHash, 256);
        b.storeAddress(self.referral);
        storeCellRef<OrderJetton>(self.jetton, b, OrderJetton.store);
    },
    toCell(self: OrderExtra): c.Cell {
        return makeCellFrom<OrderExtra>(self, OrderExtra.store);
    }
}

/**
 > struct OrderStorage {
 >     client: address
 >     courier: address?
 >     description: cell
 >     area: cell
 >     origin: cell
 >     reward: coins
 >     status: OrderStatus
 >     nonce: uint64
 >     createdAt: uint32
 >     acceptedAt: uint32
 >     deliveryTime: uint32
 >     extra: Cell<OrderExtra>
 > }
 */
export interface OrderStorage {
    readonly $: 'OrderStorage'
    client: c.Address
    courier: c.Address | null
    description: c.Cell
    area: c.Cell
    origin: c.Cell
    reward: coins
    status: OrderStatus
    nonce: uint64
    createdAt: uint32
    acceptedAt: uint32
    deliveryTime: uint32
    extra: CellRef<OrderExtra>
}

export const OrderStorage = {
    create(args: {
        client: c.Address
        courier: c.Address | null
        description: c.Cell
        area: c.Cell
        origin: c.Cell
        reward: coins
        status: OrderStatus
        nonce: uint64
        createdAt: uint32
        acceptedAt: uint32
        deliveryTime: uint32
        extra: CellRef<OrderExtra>
    }): OrderStorage {
        return {
            $: 'OrderStorage',
            ...args
        }
    },
    fromSlice(s: c.Slice): OrderStorage {
        return {
            $: 'OrderStorage',
            client: s.loadAddress(),
            courier: s.loadMaybeAddress(),
            description: s.loadRef(),
            area: s.loadRef(),
            origin: s.loadRef(),
            reward: s.loadCoins(),
            status: OrderStatus.fromSlice(s),
            nonce: s.loadUintBig(64),
            createdAt: s.loadUintBig(32),
            acceptedAt: s.loadUintBig(32),
            deliveryTime: s.loadUintBig(32),
            extra: loadCellRef<OrderExtra>(s, OrderExtra.fromSlice),
        }
    },
    store(self: OrderStorage, b: c.Builder): void {
        b.storeAddress(self.client);
        b.storeAddress(self.courier);
        b.storeRef(self.description);
        b.storeRef(self.area);
        b.storeRef(self.origin);
        b.storeCoins(self.reward);
        OrderStatus.store(self.status, b);
        b.storeUint(self.nonce, 64);
        b.storeUint(self.createdAt, 32);
        b.storeUint(self.acceptedAt, 32);
        b.storeUint(self.deliveryTime, 32);
        storeCellRef<OrderExtra>(self.extra, b, OrderExtra.store);
    },
    toCell(self: OrderStorage): c.Cell {
        return makeCellFrom<OrderStorage>(self, OrderStorage.store);
    }
}

/**
 > struct (0xa00a0001) AcceptOrder {
 >     courierContact: cell
 > }
 */
export interface AcceptOrder {
    readonly $: 'AcceptOrder'
    courierContact: c.Cell
}

export const AcceptOrder = {
    PREFIX: 0xa00a0001,

    create(args: {
        courierContact: c.Cell
    }): AcceptOrder {
        return {
            $: 'AcceptOrder',
            ...args
        }
    },
    fromSlice(s: c.Slice): AcceptOrder {
        loadAndCheckPrefix32(s, 0xa00a0001, 'AcceptOrder');
        return {
            $: 'AcceptOrder',
            courierContact: s.loadRef(),
        }
    },
    store(self: AcceptOrder, b: c.Builder): void {
        b.storeUint(0xa00a0001, 32);
        b.storeRef(self.courierContact);
    },
    toCell(self: AcceptOrder): c.Cell {
        return makeCellFrom<AcceptOrder>(self, AcceptOrder.store);
    }
}

/**
 > struct (0xa00a0002) ConfirmWithCode {
 >     secret: uint256
 > }
 */
export interface ConfirmWithCode {
    readonly $: 'ConfirmWithCode'
    secret: uint256
}

export const ConfirmWithCode = {
    PREFIX: 0xa00a0002,

    create(args: {
        secret: uint256
    }): ConfirmWithCode {
        return {
            $: 'ConfirmWithCode',
            ...args
        }
    },
    fromSlice(s: c.Slice): ConfirmWithCode {
        loadAndCheckPrefix32(s, 0xa00a0002, 'ConfirmWithCode');
        return {
            $: 'ConfirmWithCode',
            secret: s.loadUintBig(256),
        }
    },
    store(self: ConfirmWithCode, b: c.Builder): void {
        b.storeUint(0xa00a0002, 32);
        b.storeUint(self.secret, 256);
    },
    toCell(self: ConfirmWithCode): c.Cell {
        return makeCellFrom<ConfirmWithCode>(self, ConfirmWithCode.store);
    }
}

/**
 > struct (0xa00a0003) CancelOrder {
 > }
 */
export interface CancelOrder {
    readonly $: 'CancelOrder'
}

export const CancelOrder = {
    PREFIX: 0xa00a0003,

    create(): CancelOrder {
        return {
            $: 'CancelOrder',
        }
    },
    fromSlice(s: c.Slice): CancelOrder {
        loadAndCheckPrefix32(s, 0xa00a0003, 'CancelOrder');
        return {
            $: 'CancelOrder',
        }
    },
    store(self: CancelOrder, b: c.Builder): void {
        b.storeUint(0xa00a0003, 32);
    },
    toCell(self: CancelOrder): c.Cell {
        return makeCellFrom<CancelOrder>(self, CancelOrder.store);
    }
}

/**
 > struct (0xa00a0004) ClaimExpired {
 > }
 */
export interface ClaimExpired {
    readonly $: 'ClaimExpired'
}

export const ClaimExpired = {
    PREFIX: 0xa00a0004,

    create(): ClaimExpired {
        return {
            $: 'ClaimExpired',
        }
    },
    fromSlice(s: c.Slice): ClaimExpired {
        loadAndCheckPrefix32(s, 0xa00a0004, 'ClaimExpired');
        return {
            $: 'ClaimExpired',
        }
    },
    store(self: ClaimExpired, b: c.Builder): void {
        b.storeUint(0xa00a0004, 32);
    },
    toCell(self: ClaimExpired): c.Cell {
        return makeCellFrom<ClaimExpired>(self, ClaimExpired.store);
    }
}

/**
 > struct (0xa00a0005) CourierRelease {
 > }
 */
export interface CourierRelease {
    readonly $: 'CourierRelease'
}

export const CourierRelease = {
    PREFIX: 0xa00a0005,

    create(): CourierRelease {
        return {
            $: 'CourierRelease',
        }
    },
    fromSlice(s: c.Slice): CourierRelease {
        loadAndCheckPrefix32(s, 0xa00a0005, 'CourierRelease');
        return {
            $: 'CourierRelease',
        }
    },
    store(self: CourierRelease, b: c.Builder): void {
        b.storeUint(0xa00a0005, 32);
    },
    toCell(self: CourierRelease): c.Cell {
        return makeCellFrom<CourierRelease>(self, CourierRelease.store);
    }
}

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
 > struct (0xa00a0007) Rescue {
 >     amount: coins
 > }
 */
export interface Rescue {
    readonly $: 'Rescue'
    amount: coins
}

export const Rescue = {
    PREFIX: 0xa00a0007,

    create(args: {
        amount: coins
    }): Rescue {
        return {
            $: 'Rescue',
            ...args
        }
    },
    fromSlice(s: c.Slice): Rescue {
        loadAndCheckPrefix32(s, 0xa00a0007, 'Rescue');
        return {
            $: 'Rescue',
            amount: s.loadCoins(),
        }
    },
    store(self: Rescue, b: c.Builder): void {
        b.storeUint(0xa00a0007, 32);
        b.storeCoins(self.amount);
    },
    toCell(self: Rescue): c.Cell {
        return makeCellFrom<Rescue>(self, Rescue.store);
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
 > struct (0xa00a0101) OrderAccepted {
 >     courier: address
 > }
 */
export interface OrderAccepted {
    readonly $: 'OrderAccepted'
    courier: c.Address
}

export const OrderAccepted = {
    PREFIX: 0xa00a0101,

    create(args: {
        courier: c.Address
    }): OrderAccepted {
        return {
            $: 'OrderAccepted',
            ...args
        }
    },
    fromSlice(s: c.Slice): OrderAccepted {
        loadAndCheckPrefix32(s, 0xa00a0101, 'OrderAccepted');
        return {
            $: 'OrderAccepted',
            courier: s.loadAddress(),
        }
    },
    store(self: OrderAccepted, b: c.Builder): void {
        b.storeUint(0xa00a0101, 32);
        b.storeAddress(self.courier);
    },
    toCell(self: OrderAccepted): c.Cell {
        return makeCellFrom<OrderAccepted>(self, OrderAccepted.store);
    }
}

/**
 > struct (0xa00a0102) OrderCompleted {
 >     courier: address
 >     reward: coins
 >     referralPayout: coins
 > }
 */
export interface OrderCompleted {
    readonly $: 'OrderCompleted'
    courier: c.Address
    reward: coins
    referralPayout: coins
}

export const OrderCompleted = {
    PREFIX: 0xa00a0102,

    create(args: {
        courier: c.Address
        reward: coins
        referralPayout: coins
    }): OrderCompleted {
        return {
            $: 'OrderCompleted',
            ...args
        }
    },
    fromSlice(s: c.Slice): OrderCompleted {
        loadAndCheckPrefix32(s, 0xa00a0102, 'OrderCompleted');
        return {
            $: 'OrderCompleted',
            courier: s.loadAddress(),
            reward: s.loadCoins(),
            referralPayout: s.loadCoins(),
        }
    },
    store(self: OrderCompleted, b: c.Builder): void {
        b.storeUint(0xa00a0102, 32);
        b.storeAddress(self.courier);
        b.storeCoins(self.reward);
        b.storeCoins(self.referralPayout);
    },
    toCell(self: OrderCompleted): c.Cell {
        return makeCellFrom<OrderCompleted>(self, OrderCompleted.store);
    }
}

/**
 > struct (0xa00a0103) OrderCancelled {
 >     reward: coins
 >     referralPayout: coins
 > }
 */
export interface OrderCancelled {
    readonly $: 'OrderCancelled'
    reward: coins
    referralPayout: coins
}

export const OrderCancelled = {
    PREFIX: 0xa00a0103,

    create(args: {
        reward: coins
        referralPayout: coins
    }): OrderCancelled {
        return {
            $: 'OrderCancelled',
            ...args
        }
    },
    fromSlice(s: c.Slice): OrderCancelled {
        loadAndCheckPrefix32(s, 0xa00a0103, 'OrderCancelled');
        return {
            $: 'OrderCancelled',
            reward: s.loadCoins(),
            referralPayout: s.loadCoins(),
        }
    },
    store(self: OrderCancelled, b: c.Builder): void {
        b.storeUint(0xa00a0103, 32);
        b.storeCoins(self.reward);
        b.storeCoins(self.referralPayout);
    },
    toCell(self: OrderCancelled): c.Cell {
        return makeCellFrom<OrderCancelled>(self, OrderCancelled.store);
    }
}

/**
 > struct (0xa00a0104) OrderExpired {
 >     courier: address
 >     reward: coins
 >     referralPayout: coins
 > }
 */
export interface OrderExpired {
    readonly $: 'OrderExpired'
    courier: c.Address
    reward: coins
    referralPayout: coins
}

export const OrderExpired = {
    PREFIX: 0xa00a0104,

    create(args: {
        courier: c.Address
        reward: coins
        referralPayout: coins
    }): OrderExpired {
        return {
            $: 'OrderExpired',
            ...args
        }
    },
    fromSlice(s: c.Slice): OrderExpired {
        loadAndCheckPrefix32(s, 0xa00a0104, 'OrderExpired');
        return {
            $: 'OrderExpired',
            courier: s.loadAddress(),
            reward: s.loadCoins(),
            referralPayout: s.loadCoins(),
        }
    },
    store(self: OrderExpired, b: c.Builder): void {
        b.storeUint(0xa00a0104, 32);
        b.storeAddress(self.courier);
        b.storeCoins(self.reward);
        b.storeCoins(self.referralPayout);
    },
    toCell(self: OrderExpired): c.Cell {
        return makeCellFrom<OrderExpired>(self, OrderExpired.store);
    }
}

/**
 > struct (0xa00a0105) OrderReopened {
 >     courier: address
 > }
 */
export interface OrderReopened {
    readonly $: 'OrderReopened'
    courier: c.Address
}

export const OrderReopened = {
    PREFIX: 0xa00a0105,

    create(args: {
        courier: c.Address
    }): OrderReopened {
        return {
            $: 'OrderReopened',
            ...args
        }
    },
    fromSlice(s: c.Slice): OrderReopened {
        loadAndCheckPrefix32(s, 0xa00a0105, 'OrderReopened');
        return {
            $: 'OrderReopened',
            courier: s.loadAddress(),
        }
    },
    store(self: OrderReopened, b: c.Builder): void {
        b.storeUint(0xa00a0105, 32);
        b.storeAddress(self.courier);
    },
    toCell(self: OrderReopened): c.Cell {
        return makeCellFrom<OrderReopened>(self, OrderReopened.store);
    }
}

/**
 > struct (0xa00a0106) OrderFunded {
 >     reward: coins
 > }
 */
export interface OrderFunded {
    readonly $: 'OrderFunded'
    reward: coins
}

export const OrderFunded = {
    PREFIX: 0xa00a0106,

    create(args: {
        reward: coins
    }): OrderFunded {
        return {
            $: 'OrderFunded',
            ...args
        }
    },
    fromSlice(s: c.Slice): OrderFunded {
        loadAndCheckPrefix32(s, 0xa00a0106, 'OrderFunded');
        return {
            $: 'OrderFunded',
            reward: s.loadCoins(),
        }
    },
    store(self: OrderFunded, b: c.Builder): void {
        b.storeUint(0xa00a0106, 32);
        b.storeCoins(self.reward);
    },
    toCell(self: OrderFunded): c.Cell {
        return makeCellFrom<OrderFunded>(self, OrderFunded.store);
    }
}

// ————————————————————————————————————————————
//    class Order
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

export class Order implements c.Contract {
    static CodeCell = c.Cell.fromBase64('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');

    static Errors = {
        'OrderErrors.WrongStatus': 100,
        'OrderErrors.NotClient': 101,
        'OrderErrors.NotCourier': 102,
        'OrderErrors.FeeTooLow': 103,
        'OrderErrors.NotExpired': 104,
        'OrderErrors.DeadlinePassed': 105,
        'OrderErrors.BadCode': 108,
        'OrderErrors.NotMarketplace': 109,
        'OrderErrors.NotJettonWallet': 110,
        'OrderErrors.NotPayee': 111,
        'OrderErrors.InvalidMessage': 65535,
    }

    readonly address: c.Address
    readonly init: { code: c.Cell, data: c.Cell } | undefined

    protected constructor(address: c.Address, init?: { code: c.Cell, data: c.Cell }) {
        this.address = address;
        this.init = init;
    }

    static fromAddress(address: c.Address) {
        return new Order(address);
    }

    static fromStorage(emptyStorage: {
        client: c.Address
        courier: c.Address | null
        description: c.Cell
        area: c.Cell
        origin: c.Cell
        reward: coins
        status: OrderStatus
        nonce: uint64
        createdAt: uint32
        acceptedAt: uint32
        deliveryTime: uint32
        extra: CellRef<OrderExtra>
    }, deployedOptions?: DeployedAddrOptions) {
        const initialState = {
            code: deployedOptions?.overrideContractCode ?? Order.CodeCell,
            data: OrderStorage.toCell(OrderStorage.create(emptyStorage)),
        };
        const address = calculateDeployedAddress(initialState.code, initialState.data, deployedOptions ?? {});
        return new Order(address, initialState);
    }

    static createCellOfAcceptOrder(body: {
        courierContact: c.Cell
    }) {
        return AcceptOrder.toCell(AcceptOrder.create(body));
    }

    static createCellOfConfirmWithCode(body: {
        secret: uint256
    }) {
        return ConfirmWithCode.toCell(ConfirmWithCode.create(body));
    }

    static createCellOfCancelOrder(body: {
    }) {
        return CancelOrder.toCell(CancelOrder.create());
    }

    static createCellOfClaimExpired(body: {
    }) {
        return ClaimExpired.toCell(ClaimExpired.create());
    }

    static createCellOfCourierRelease(body: {
    }) {
        return CourierRelease.toCell(CourierRelease.create());
    }

    static createCellOfInitWallet(body: {
        wallet: c.Address
    }) {
        return InitWallet.toCell(InitWallet.create(body));
    }

    static createCellOfRescue(body: {
        amount: coins
    }) {
        return Rescue.toCell(Rescue.create(body));
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

    async sendAcceptOrder(provider: ContractProvider, via: Sender, msgValue: coins, body: {
        courierContact: c.Cell
    }, extraOptions?: ExtraSendOptions) {
        return provider.internal(via, {
            value: msgValue,
            body: AcceptOrder.toCell(AcceptOrder.create(body)),
            ...extraOptions
        });
    }

    async sendConfirmWithCode(provider: ContractProvider, via: Sender, msgValue: coins, body: {
        secret: uint256
    }, extraOptions?: ExtraSendOptions) {
        return provider.internal(via, {
            value: msgValue,
            body: ConfirmWithCode.toCell(ConfirmWithCode.create(body)),
            ...extraOptions
        });
    }

    async sendCancelOrder(provider: ContractProvider, via: Sender, msgValue: coins, body: {
    }, extraOptions?: ExtraSendOptions) {
        return provider.internal(via, {
            value: msgValue,
            body: CancelOrder.toCell(CancelOrder.create()),
            ...extraOptions
        });
    }

    async sendClaimExpired(provider: ContractProvider, via: Sender, msgValue: coins, body: {
    }, extraOptions?: ExtraSendOptions) {
        return provider.internal(via, {
            value: msgValue,
            body: ClaimExpired.toCell(ClaimExpired.create()),
            ...extraOptions
        });
    }

    async sendCourierRelease(provider: ContractProvider, via: Sender, msgValue: coins, body: {
    }, extraOptions?: ExtraSendOptions) {
        return provider.internal(via, {
            value: msgValue,
            body: CourierRelease.toCell(CourierRelease.create()),
            ...extraOptions
        });
    }

    async sendInitWallet(provider: ContractProvider, via: Sender, msgValue: coins, body: {
        wallet: c.Address
    }, extraOptions?: ExtraSendOptions) {
        return provider.internal(via, {
            value: msgValue,
            body: InitWallet.toCell(InitWallet.create(body)),
            ...extraOptions
        });
    }

    async sendRescue(provider: ContractProvider, via: Sender, msgValue: coins, body: {
        amount: coins
    }, extraOptions?: ExtraSendOptions) {
        return provider.internal(via, {
            value: msgValue,
            body: Rescue.toCell(Rescue.create(body)),
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

    async getOrderData(provider: ContractProvider): Promise<OrderStorage> {
        const r = StackReader.fromGetMethod(12, await provider.get('orderData', []));
        return ({
            $: 'OrderStorage',
            client: r.readSlice().loadAddress(),
            courier: r.readNullable<c.Address>(
                (r) => r.readSlice().loadAddress()
            ),
            description: r.readCell(),
            area: r.readCell(),
            origin: r.readCell(),
            reward: r.readBigInt(),
            status: r.readBigInt(),
            nonce: r.readBigInt(),
            createdAt: r.readBigInt(),
            acceptedAt: r.readBigInt(),
            deliveryTime: r.readBigInt(),
            extra: r.readCellRef<OrderExtra>(OrderExtra.fromSlice),
        });
    }

    async getStatus(provider: ContractProvider): Promise<OrderStatus> {
        const r = StackReader.fromGetMethod(1, await provider.get('status', []));
        return r.readBigInt();
    }
}
