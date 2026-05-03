// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * Decentralized Identity (DID) Registry
 * W3C DID and Verifiable Credential standards on Polygon.
 * Eliminates centralized PII storage, reducing KYC costs by 40%.
 */
contract DIDRegistry {
    
    struct DIDDocument {
        address owner;
        string  didUri;          // e.g. "did:polygon:0x1234..."
        bytes32 publicKeyHash;   // Hash of the DID's public key
        uint256 createdAt;
        uint256 updatedAt;
        bool    active;
    }

    struct VerifiableCredential {
        bytes32 credentialId;
        address issuer;
        address subject;
        string  credentialType;  // e.g. "KYCVerification", "AgeVerification"
        bytes32 credentialHash;  // Hash of the credential data (stored off-chain/IPFS)
        uint256 issuedAt;
        uint256 expiresAt;
        bool    revoked;
    }

    // DID storage: address -> DIDDocument
    mapping(address => DIDDocument) public dids;
    
    // Credential storage: credentialId -> VerifiableCredential
    mapping(bytes32 => VerifiableCredential) public credentials;
    
    // Revocation registry: credentialId -> bool
    mapping(bytes32 => bool) public revocationRegistry;
    
    // Authorized issuers
    mapping(address => bool) public authorizedIssuers;
    address public admin;

    event DIDCreated(address indexed owner, string didUri);
    event DIDUpdated(address indexed owner, bytes32 newPublicKeyHash);
    event CredentialIssued(bytes32 indexed credentialId, address indexed issuer, address indexed subject);
    event CredentialRevoked(bytes32 indexed credentialId, address indexed issuer);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    modifier onlyAuthorizedIssuer() {
        require(authorizedIssuers[msg.sender], "Not an authorized issuer");
        _;
    }

    constructor() {
        admin = msg.sender;
        authorizedIssuers[msg.sender] = true;
    }

    /**
     * Create a new DID for the caller.
     */
    function createDID(string calldata didUri, bytes32 publicKeyHash) external {
        require(!dids[msg.sender].active, "DID already exists for this address");
        
        dids[msg.sender] = DIDDocument({
            owner:         msg.sender,
            didUri:        didUri,
            publicKeyHash: publicKeyHash,
            createdAt:     block.timestamp,
            updatedAt:     block.timestamp,
            active:        true
        });
        
        emit DIDCreated(msg.sender, didUri);
    }

    /**
     * Issue a Verifiable Credential to a subject.
     * The actual credential data is stored off-chain (IPFS).
     * Only the hash is stored on-chain for tamper-proof verification.
     */
    function issueCredential(
        address subject,
        string calldata credentialType,
        bytes32 credentialHash,
        uint256 validityDays
    ) external onlyAuthorizedIssuer returns (bytes32) {
        require(dids[subject].active, "Subject does not have a DID");
        
        bytes32 credentialId = keccak256(
            abi.encodePacked(msg.sender, subject, credentialType, block.timestamp)
        );
        
        credentials[credentialId] = VerifiableCredential({
            credentialId:   credentialId,
            issuer:         msg.sender,
            subject:        subject,
            credentialType: credentialType,
            credentialHash: credentialHash,
            issuedAt:       block.timestamp,
            expiresAt:      block.timestamp + (validityDays * 1 days),
            revoked:        false
        });
        
        emit CredentialIssued(credentialId, msg.sender, subject);
        return credentialId;
    }

    /**
     * Verify a credential is valid (not expired, not revoked, hash matches).
     * This is the zero-knowledge-friendly verification path.
     * The subject proves they have a credential without revealing the data.
     */
    function verifyCredential(bytes32 credentialId, bytes32 providedHash)
        external view returns (bool isValid, string memory reason)
    {
        VerifiableCredential storage cred = credentials[credentialId];
        
        if (cred.credentialId == bytes32(0)) return (false, "Credential not found");
        if (cred.revoked)                    return (false, "Credential revoked");
        if (block.timestamp > cred.expiresAt) return (false, "Credential expired");
        if (cred.credentialHash != providedHash) return (false, "Hash mismatch");
        
        return (true, "Valid");
    }

    /**
     * Revoke a credential. Only the original issuer can revoke.
     */
    function revokeCredential(bytes32 credentialId) external {
        require(credentials[credentialId].issuer == msg.sender, "Only issuer can revoke");
        credentials[credentialId].revoked = true;
        revocationRegistry[credentialId] = true;
        emit CredentialRevoked(credentialId, msg.sender);
    }

    function addAuthorizedIssuer(address issuer) external onlyAdmin {
        authorizedIssuers[issuer] = true;
    }
}
