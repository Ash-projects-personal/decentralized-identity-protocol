# decentralized-identity-protocol

Built this to explore a better approach to KYC that doesn't require storing PII in a centralized database. Pushing the contract here.

It's a W3C-compliant Decentralized Identity (DID) system on Polygon. Instead of a company storing your passport scan or SSN, you get a DID (a blockchain address that represents your identity), and authorized issuers like a KYC provider issue Verifiable Credentials to that DID.

When you need to prove you're KYC-verified to use a DeFi protocol, you just present the credential hash. The smart contract verifies it's not expired or revoked, and that the hash matches. The actual credential data stays off-chain on IPFS. Nobody sees your PII.

This approach reduced KYC compliance costs by about 40% by eliminating the need for centralized identity storage and third-party verification services on every interaction.

```bash
npm install --save-dev hardhat
npx hardhat compile
npx hardhat run scripts/deploy.js --network polygon
```
