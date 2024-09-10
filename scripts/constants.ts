import { BigNumberish, ec } from "starknet";

export const LOCAL_CHAIN_ID = "393402133025997798000961";

export const SELLER_PRIVATE_KEY1 = '0x1';
export const SELLER_PRIVATE_KEY2 = '0x2';
export const SELLER_PRIVATE_KEY3 = '0x3';

export const BUYER_PRIVATE_KEY1 = '0x11';
export const BUYER_PRIVATE_KEY2 = '0x12';
export const BUYER_PRIVATE_KEY3 = '0x13';

export const SELLER1: BigNumberish = ec.starkCurve.getStarkKey(SELLER_PRIVATE_KEY1);
export const SELLER2: BigNumberish = ec.starkCurve.getStarkKey(SELLER_PRIVATE_KEY2);
export const SELLER3: BigNumberish = ec.starkCurve.getStarkKey(SELLER_PRIVATE_KEY3);

export const BUYER1: BigNumberish = ec.starkCurve.getStarkKey(BUYER_PRIVATE_KEY1);
export const BUYER2: BigNumberish = ec.starkCurve.getStarkKey(BUYER_PRIVATE_KEY2);
export const BUYER3: BigNumberish = ec.starkCurve.getStarkKey(BUYER_PRIVATE_KEY3);