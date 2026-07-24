const express = require('express');
const fetch = require('node-fetch');
const path = require('path');
const { resolveNamespace } = require('./fabricConnect');
const mockResolver = require('./mockResolver');

const app = express();
app.use(express.static(path.join(__dirname, 'public')));
app.use('/mock-resolver', mockResolver);

app.get('/api/resolve', async (req, res) => {
  const did = req.query.did;
  if (!did || !did.startsWith('did:rwp:')) {
    return res.status(400).json({ error: 'Ungültige did:rwp-ID' });
  }

  const parts = did.split(':');
  const namespace = parts[2];
  if (!namespace) {
    return res.status(400).json({ error: 'Namespace konnte nicht extrahiert werden' });
  }

  try {
    const chaincodeResult = await resolveNamespace(namespace);
    const resolverEndpoint = chaincodeResult.resolverEndpoint;

    let didRecord;
    let resolverSource = 'live';
    try {
      const httpRes = await fetch(`${resolverEndpoint}/${did}`, { timeout: 4000 });
      if (!httpRes.ok) throw new Error(`HTTP ${httpRes.status}`);
      didRecord = await httpRes.json();
    } catch (err) {
      resolverSource = 'mock-fallback';
      const mockUrl = `http://localhost:${PORT}/mock-resolver/rwp/v2/${did}`;
      const mockRes = await fetch(mockUrl);
      didRecord = await mockRes.json();
    }

    res.json({
      inputDid: did,
      extractedNamespace: namespace,
      chaincodeResult,
      resolverEndpointCalled: resolverEndpoint,
      resolverSource,
      didRecord
    });
  } catch (err) {
    res.status(500).json({ error: err.message, stack: err.stack });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Demo läuft auf http://localhost:${PORT}`));