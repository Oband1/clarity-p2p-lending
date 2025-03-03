import {
    Clarinet,
    Tx,
    Chain,
    Account,
    types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can create a new loan request with collateral",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const borrower = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('p2p-lending', 'create-loan', [
                types.uint(1000000), // 1 STX
                types.uint(10),      // 10% interest
                types.uint(12),      // 12 weeks
                types.uint(500000)   // 0.5 STX collateral
            ], borrower.address)
        ]);
        
        block.receipts[0].result.expectOk().expectUint(0);
        block.receipts[0].events.expectSTXTransferEvent(
            500000,
            borrower.address,
            `${block.receipts[0].contractAddress}.p2p-lending`
        );
    }
});

Clarinet.test({
    name: "Can make partial repayments",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const borrower = accounts.get('wallet_1')!;
        const lender = accounts.get('wallet_2')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('p2p-lending', 'create-loan', [
                types.uint(1000000),
                types.uint(10),
                types.uint(12),
                types.uint(500000)
            ], borrower.address),
            Tx.contractCall('p2p-lending', 'fund-loan', [
                types.uint(0)
            ], lender.address),
            Tx.contractCall('p2p-lending', 'repay-loan', [
                types.uint(0),
                types.uint(500000)
            ], borrower.address)
        ]);
        
        block.receipts[2].result.expectOk().expectBool(true);
    }
});

Clarinet.test({
    name: "Can claim collateral after default",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const borrower = accounts.get('wallet_1')!;
        const lender = accounts.get('wallet_2')!;
        
        // Implementation needed
    }
});
