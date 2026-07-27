// dashboard.js – Dashboard-Logik: Liste, Bearbeiten, Registrieren, Historie.
import { api } from './api.js';

const IDENTITY_KEY = 'rootResolverIdentity';

// ── Session-Guard ──────────────────────────────────────────────────────────
// Ohne "eingeloggte" Identität zurück zum Login.
const identity = sessionStorage.getItem(IDENTITY_KEY);
if (!identity) {
  window.location.replace('index.html');
}

// ── DOM-Referenzen ───────────────────────────────────────────────────────────
const $ = (id) => document.getElementById(id);

const loadingEl = $('loading');
const tableEl = $('namespaces-table');
const bodyEl = $('namespaces-body');
const emptyHintEl = $('empty-hint');
const messageEl = $('message');

const editDialog = $('edit-dialog');
const registerDialog = $('register-dialog');
const historyDialog = $('history-dialog');

// ── Init ──────────────────────────────────────────────────────────────────
$('current-identity').textContent = identity;

$('logout-link').addEventListener('click', (e) => {
  e.preventDefault();
  sessionStorage.removeItem(IDENTITY_KEY);
  window.location.href = 'index.html';
});

$('reload-btn').addEventListener('click', loadNamespaces);
$('register-btn').addEventListener('click', openRegisterDialog);

// Alle "Abbrechen/Schliessen"-Buttons schliessen ihren Dialog.
document.querySelectorAll('[data-close-dialog]').forEach((btn) => {
  btn.addEventListener('click', () => $(btn.dataset.closeDialog).close());
});

$('edit-form').addEventListener('submit', onEditSubmit);
$('register-form').addEventListener('submit', onRegisterSubmit);

loadNamespaces();

// ── Statusmeldungen ──────────────────────────────────────────────────────────
function showMessage(text, kind) {
  messageEl.textContent = text;
  messageEl.className = `message message-${kind}`;
}
function clearMessage() {
  messageEl.className = 'message hidden';
  messageEl.textContent = '';
}

// ── Liste laden & rendern ────────────────────────────────────────────────────
async function loadNamespaces() {
  clearMessage();
  loadingEl.classList.remove('hidden');
  tableEl.classList.add('hidden');
  emptyHintEl.classList.add('hidden');

  try {
    const records = await api.get('/api/namespaces');
    renderTable(records ?? []);
  } catch (err) {
    showMessage(`Fehler beim Laden der Namespaces: ${err.message}`, 'error');
  } finally {
    loadingEl.classList.add('hidden');
  }
}

function renderTable(records) {
  bodyEl.replaceChildren();

  if (records.length === 0) {
    emptyHintEl.classList.remove('hidden');
    tableEl.classList.add('hidden');
    return;
  }

  for (const rec of records) {
    bodyEl.appendChild(buildRow(rec));
  }
  tableEl.classList.remove('hidden');
}

// Zeile per DOM-API bauen (textContent) → kein HTML-Injection-Risiko aus
// Ledger-/Benutzerdaten.
function buildRow(rec) {
  const tr = document.createElement('tr');

  appendCell(tr, rec.namespace);
  appendCell(tr, rec.resolverEndpoint);
  appendCell(tr, rec.registeredBy);
  appendCell(tr, rec.registeredAt);
  appendCell(tr, Array.isArray(rec.endorsedBy) ? rec.endorsedBy.join(', ') : '');

  const actions = document.createElement('td');
  actions.className = 'actions';
  actions.appendChild(makeButton('Bearbeiten', 'btn', () => openEditDialog(rec)));
  actions.appendChild(
    makeButton('Historie', 'btn btn-ghost', () => openHistoryDialog(rec.namespace)),
  );
  tr.appendChild(actions);

  return tr;
}

function appendCell(tr, value) {
  const td = document.createElement('td');
  td.textContent = value ?? '';
  tr.appendChild(td);
}

function makeButton(label, className, onClick) {
  const btn = document.createElement('button');
  btn.type = 'button';
  btn.className = className;
  btn.textContent = label;
  btn.addEventListener('click', onClick);
  return btn;
}

// ── Bearbeiten (PUT) ─────────────────────────────────────────────────────────
function openEditDialog(rec) {
  $('edit-namespace').textContent = rec.namespace;
  $('edit-endpoint').value = rec.resolverEndpoint ?? '';
  hideDialogError('edit-error');
  editDialog.dataset.namespace = rec.namespace;
  editDialog.showModal();
}

async function onEditSubmit(event) {
  event.preventDefault();
  const namespace = editDialog.dataset.namespace;
  const resolverEndpoint = $('edit-endpoint').value.trim();

  try {
    // callerMSP wird automatisch aus der Sitzungs-Identität gesetzt, NICHT als
    // sichtbares Feld. Der Chaincode akzeptiert die Änderung nur, wenn
    // callerMSP == registeredBy des bestehenden Records (sonst 403).
    await api.put(`/api/namespaces/${encodeURIComponent(namespace)}`, {
      resolverEndpoint,
      callerMSP: identity,
    });
    editDialog.close();
    showMessage(`Namespace "${namespace}" aktualisiert.`, 'success');
    await loadNamespaces();
  } catch (err) {
    showDialogError('edit-error', translateWriteError(err));
  }
}

// ── Registrieren (POST) ──────────────────────────────────────────────────────
function openRegisterDialog() {
  $('register-namespace').value = '';
  $('register-endpoint').value = '';
  hideDialogError('register-error');
  registerDialog.showModal();
}

async function onRegisterSubmit(event) {
  event.preventDefault();
  const namespace = $('register-namespace').value.trim();
  const resolverEndpoint = $('register-endpoint').value.trim();

  try {
    // registeredBy und endorsedBy werden bewusst aus der Sitzungs-Identität
    // abgeleitet (nicht als Formularfelder): In dieser Demo repräsentiert die
    // "eingeloggte" Identität den registrierenden Akteur. endorsedBy startet
    // mit genau diesem einen Endorser ([identity]); weitere Endorsements
    // entstehen später über den (Multi-Org-)Chaincode-Flow, nicht im UI.
    await api.post('/api/namespaces', {
      namespace,
      resolverEndpoint,
      registeredBy: identity,
      endorsedBy: [identity],
    });
    registerDialog.close();
    showMessage(`Namespace "${namespace}" registriert.`, 'success');
    await loadNamespaces();
  } catch (err) {
    showDialogError('register-error', translateWriteError(err));
  }
}

// ── Historie ─────────────────────────────────────────────────────────────────
async function openHistoryDialog(namespace) {
  $('history-namespace').textContent = namespace;
  const content = $('history-content');
  content.replaceChildren(document.createTextNode('Lade Historie …'));
  historyDialog.showModal();

  try {
    const entries = await api.get(
      `/api/namespaces/${encodeURIComponent(namespace)}/history`,
    );
    renderHistory(content, entries ?? []);
  } catch (err) {
    content.replaceChildren();
    const p = document.createElement('p');
    p.className = 'dialog-error';
    p.textContent = `Fehler beim Laden der Historie: ${err.message}`;
    content.appendChild(p);
  }
}

function renderHistory(container, entries) {
  container.replaceChildren();

  if (entries.length === 0) {
    const p = document.createElement('p');
    p.className = 'muted';
    p.textContent = 'Keine Historie vorhanden.';
    container.appendChild(p);
    return;
  }

  const list = document.createElement('ol');
  list.className = 'history-list';

  for (const entry of entries) {
    const li = document.createElement('li');

    const meta = document.createElement('div');
    meta.className = 'history-meta';
    meta.textContent = `${entry.timestamp ?? '–'} · txId ${entry.txId ?? '–'}${
      entry.isDelete ? ' · GELÖSCHT' : ''
    }`;
    li.appendChild(meta);

    if (entry.record) {
      const detail = document.createElement('div');
      detail.className = 'history-detail';
      detail.textContent = `Endpoint: ${entry.record.resolverEndpoint ?? '–'} · registeredBy: ${
        entry.record.registeredBy ?? '–'
      }`;
      li.appendChild(detail);
    }

    list.appendChild(li);
  }
  container.appendChild(list);
}

// ── Fehler-Hilfen ──────────────────────────────────────────────────────────
function translateWriteError(err) {
  if (err.status === 403) {
    return `Nicht autorisiert: Deine Identität ("${identity}") stimmt nicht mit dem Registranten (registeredBy) dieses Namespace überein.`;
  }
  if (err.status === 409) {
    return 'Dieser Namespace existiert bereits.';
  }
  if (err.status === 400) {
    return `Ungültige Eingabe: ${err.message}`;
  }
  return err.message;
}

function showDialogError(id, text) {
  const el = $(id);
  el.textContent = text;
  el.classList.remove('hidden');
}
function hideDialogError(id) {
  const el = $(id);
  el.textContent = '';
  el.classList.add('hidden');
}
