// api.js – schlanker fetch-Wrapper für die REST-API des Backends.
// Übersetzt HTTP-Fehler in verständliche Meldungen (nutzt das {error: ...}-Feld
// des Backends, falls vorhanden) und wirft im Fehlerfall ein Error-Objekt mit
// zusätzlichem .status-Feld.

async function request(method, path, body) {
  let response;
  try {
    response = await fetch(path, {
      method,
      headers: body ? { 'Content-Type': 'application/json' } : undefined,
      body: body ? JSON.stringify(body) : undefined,
    });
  } catch {
    // Netzwerk-/Verbindungsfehler (Server nicht erreichbar).
    throw new Error('Server nicht erreichbar. Läuft das Backend?');
  }

  // 204 / leerer Body: nichts zu parsen.
  const text = await response.text();
  const data = text ? safeJson(text) : null;

  if (!response.ok) {
    const message =
      (data && data.error) ||
      `Anfrage fehlgeschlagen (HTTP ${response.status})`;
    const err = new Error(message);
    err.status = response.status;
    throw err;
  }
  return data;
}

function safeJson(text) {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

export const api = {
  get: (path) => request('GET', path),
  post: (path, body) => request('POST', path, body),
  put: (path, body) => request('PUT', path, body),
};
