import { initializeApp } from 'https://www.gstatic.com/firebasejs/9.23.0/firebase-app.js';
import { getAuth, signInAnonymously, onAuthStateChanged } from 'https://www.gstatic.com/firebasejs/9.23.0/firebase-auth.js';

if (!window.FIREBASE_CONFIG) {
  console.warn('FIREBASE_CONFIG missing. Copy app.config.sample.js to app.config.js.');
} else {
  const app = initializeApp(window.FIREBASE_CONFIG);
  window.FIREBASE_APP = app;
  const auth = getAuth(app);
  signInAnonymously(auth).catch(err => console.error('Auth error', err));
  onAuthStateChanged(auth, user => {
    if (user) {
      window.AUTH = { uid: user.uid };
      if (window.log) window.log('Signed in as ' + user.uid);
    }
  });
}
