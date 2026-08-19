const grpc = require('@grpc/grpc-js');
const { connect, signers, Gateway } = require('@hyperledger/fabric-gateway');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const CRYPTO_DIR = process.env.CRYPTO_DIR || '/crypto/peerOrganizations/recordweb.org';

const MSP_ID = process.env.MSP_ID || 'RecordWebOrgMSP';
const PEER_ENDPOINT = process.env.PEER_ENDPOINT || 'peer0.recordweb.org:7051';
const PEER_HOST_ALIAS = process.env.PEER_HOST_ALIAS || 'peer0.recordweb.org';
const CHANNEL_NAME = process.env.CHANNEL_NAME || 'root-resolver';
const CHAINCODE_NAME = process.env.CHAINCODE_NAME || 'namespace-registry';

const TLS_CERT_PATH = path.join(CRYPTO_DIR, 'peers', 'peer0.recordweb.org', 'tls', 'ca.crt');
const ADMIN_MSP_DIR = path.join(CRYPTO_DIR, 'users', 'Admin@recordweb.org', 'msp');
const CERT_PATH = path.join(ADMIN_MSP_DIR, 'signcerts', 'Admin@recordweb.org-cert.pem');
const KEY_DIR = path.join(ADMIN_MSP_DIR, 'keystore');

function loadKey() {
  const files = fs.readdirSync(KEY_DIR);
  return fs.readFileSync(path.join(KEY_DIR, files[0]));
}

async function getGateway() {
  const tlsRootCert = fs.readFileSync(TLS_CERT_PATH);
  const client = new grpc.Client(
    PEER_ENDPOINT,
    grpc.credentials.createSsl(tlsRootCert),
    { 'grpc.ssl_target_name_override': PEER_HOST_ALIAS }
  );

  const credentials = fs.readFileSync(CERT_PATH);
  const privateKeyPem = loadKey();
  const privateKey = crypto.createPrivateKey(privateKeyPem);

  const gateway = connect({
    client,
    identity: { mspId: MSP_ID, credentials },
    signer: signers.newPrivateKeySigner(privateKey),
  });

  return { gateway, client };
}

async function resolveNamespace(namespace) {
  const { gateway, client } = await getGateway();
  try {
    const network = gateway.getNetwork(CHANNEL_NAME);
    const contract = network.getContract(CHAINCODE_NAME);
    const resultBytes = await contract.evaluateTransaction('ResolveNamespace', namespace);
    const resultJson = Buffer.from(resultBytes).toString('utf8');
    return JSON.parse(resultJson);
  } finally {
    gateway.close();
    client.close();
  }
}

module.exports = { resolveNamespace };