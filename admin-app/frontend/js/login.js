// login.js – Demo-"Login": speichert die eingegebene Identität clientseitig.
// KEIN Server-Call, keine echte Authentifizierung. Der Wert dient in der
// Sitzung als registeredBy/callerMSP für Schreibaktionen im Dashboard.

const IDENTITY_KEY = 'rootResolverIdentity';

// Bereits "eingeloggt" (z.B. nach Reload)? Direkt ins Dashboard.
if (sessionStorage.getItem(IDENTITY_KEY)) {
  window.location.replace('dashboard.html');
}

const form = document.getElementById('login-form');
form.addEventListener('submit', (event) => {
  event.preventDefault();
  const identity = document.getElementById('identity').value.trim();
  if (!identity) {
    return;
  }
  sessionStorage.setItem(IDENTITY_KEY, identity);
  window.location.href = 'dashboard.html';
});
