import {
    Clarinet,
    Tx,
    Chain,
    Account,
    types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can create a new loan request within limits",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const borrower = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('p2p-lending', 'create-loan', [
                types.uint(1000000), // 1 STX
                types.uint(10),      // 10% interest
                types.uint(12)       // 12 weeks
            ], borrower.address)
        ]);
        
        block.receipts[0].result.expectOk().expectUint(0);
    }
});

Clarinet.test({
    name: "Cannot create loan outside allowed limits",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const borrower = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('p2p-lending', 'create-loan', [
                types.uint(100), // Too small
                types.uint(10),
                types.uint(12)
            ], borrower.address)
        ]);
        
        block.receipts[0].result.expectErr().expectUint(109);
    }
});

Clarinet.test({
    name: "Can fund an existing loan",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const borrower = accounts.get('wallet_1')!;
        const lender = accounts.get('wallet_2')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('p2p-lending', 'create-loan', [
                types.uint(1000000),
                types.uint(10),
                types.uint(12)
            ], borrower.address),
            Tx.contractCall('p2p-lending', 'fund-loan', [
                types.uint(0)
            ], lender.address)
        ]);
        
        block.receipts[1].result.expectOk().expectBool(true);
    }
});

Clarinet.test({
    name: "Can cancel unfunded loan",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const borrower = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('p2p-lending', 'create-loan', [
                types.uint(1000000),
                types.uint(10),
                types.uint(12)
            ], borrower.address),
            Tx.contractCall('p2p-lending', 'cancel-loan', [
                types.uint(0)
            ], borrower.address)
        ]);
        
        block.receipts[1].result.expectOk().expectBool(true);
    }
});
