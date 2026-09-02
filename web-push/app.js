import {initializeApp} from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-app.js';
import {
  getAuth,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
} from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-auth.js';
import {
  getFunctions,
  httpsCallable,
} from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-functions.js';

const firebaseConfig = {
  apiKey: 'AIzaSyDZqlk7yFeSVoOpLD2AE-n2NVnpvXGOfdk',
  authDomain: 'freshflag.firebaseapp.com',
  projectId: 'freshflag',
  messagingSenderId: '765920629957',
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const functions = getFunctions(app, 'us-central1');

const getWebPushPublicKey = httpsCallable(functions, 'getWebPushPublicKey');
const setWebPushSubscription = httpsCallable(functions, 'setWebPushSubscription');
const removeWebPushSubscription = httpsCallable(functions, 'removeWebPushSubscription');
const testWebPushNotification = httpsCallable(functions, 'testWebPushNotification');

const installCard = document.querySelector('#installCard');
const signedOutCard = document.querySelector('#signedOutCard');
const signedInCard = document.querySelector('#signedInCard');
const signInForm = document.querySelector('#signInForm');
const signInButton = document.querySelector('#signInButton');
const signOutButton = document.querySelector('#signOutButton');
const signedInEmail = document.querySelector('#signedInEmail');
const statusText = document.querySelector('#statusText');
const statusPill = document.querySelector('#statusPill');
const enableButton = document.querySelector('#enableButton');
const testButton = document.querySelector('#testButton');
const disableButton = document.querySelector('#disableButton');
const message = document.querySelector('#message');

let serviceWorkerRegistration = null;
let currentSubscription = null;

const isIos = /iphone|ipad|ipod/i.test(navigator.userAgent);
const isStandalone = window.matchMedia('(display-mode: standalone)').matches ||
  window.navigator.standalone === true;

if (isIos && !isStandalone) {
  installCard.classList.remove('hidden');
}

if ('serviceWorker' in navigator) {
  serviceWorkerRegistration = await navigator.serviceWorker.register('/sw.js');
  await navigator.serviceWorker.ready;
}

onAuthStateChanged(auth, async (user) => {
  clearMessage();
  if (user == null) {
    signedOutCard.classList.remove('hidden');
    signedInCard.classList.add('hidden');
    return;
  }

  signedOutCard.classList.add('hidden');
  signedInCard.classList.remove('hidden');
  signedInEmail.textContent = user.email ?? 'Fresh Flag account';
  await refreshPushState();
});

signInForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  clearMessage();
  signInButton.disabled = true;
  try {
    const form = new FormData(signInForm);
    await signInWithEmailAndPassword(
      auth,
      String(form.get('email') ?? '').trim(),
      String(form.get('password') ?? ''),
    );
    signInForm.reset();
  } catch (error) {
    showError(friendlyError(error, 'Could not sign in.'));
  } finally {
    signInButton.disabled = false;
  }
});

signOutButton.addEventListener('click', async () => {
  clearMessage();
  try {
    await signOut(auth);
  } catch (error) {
    showError(friendlyError(error, 'Could not sign out.'));
  }
});

enableButton.addEventListener('click', async () => {
  clearMessage();
  setBusy(true);
  try {
    ensurePushSupported();
    if (isIos && !isStandalone) {
      throw new Error('Add Fresh Flag to the Home Screen, then enable notifications from the installed icon.');
    }

    const permission = await Notification.requestPermission();
    if (permission !== 'granted') {
      throw new Error('Notification permission was not granted.');
    }

    const keyResponse = await getWebPushPublicKey();
    const publicKey = keyResponse.data?.publicKey;
    if (typeof publicKey !== 'string' || publicKey.length === 0) {
      throw new Error('Fresh Flag Web Push is not configured yet.');
    }

    currentSubscription = await serviceWorkerRegistration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: base64UrlToUint8Array(publicKey),
    });

    await setWebPushSubscription({subscription: currentSubscription.toJSON()});
    showSuccess('Reminder notifications are enabled on this device.');
    await refreshPushState();
  } catch (error) {
    showError(friendlyError(error, 'Could not enable notifications.'));
  } finally {
    setBusy(false);
  }
});

testButton.addEventListener('click', async () => {
  clearMessage();
  setBusy(true);
  try {
    const result = await testWebPushNotification();
    const successCount = Number(result.data?.successCount ?? 0);
    if (successCount < 1) throw new Error('No active push subscription accepted the test.');
    showSuccess('Test notification sent.');
  } catch (error) {
    showError(friendlyError(error, 'Could not send the test notification.'));
  } finally {
    setBusy(false);
  }
});

disableButton.addEventListener('click', async () => {
  clearMessage();
  setBusy(true);
  try {
    ensurePushSupported();
    currentSubscription = currentSubscription ??
      await serviceWorkerRegistration.pushManager.getSubscription();
    if (currentSubscription != null) {
      await removeWebPushSubscription({endpoint: currentSubscription.endpoint});
      await currentSubscription.unsubscribe();
    }
    currentSubscription = null;
    showSuccess('Reminder notifications are disabled on this device.');
    await refreshPushState();
  } catch (error) {
    showError(friendlyError(error, 'Could not disable notifications.'));
  } finally {
    setBusy(false);
  }
});

async function refreshPushState() {
  if (!pushSupported()) {
    setStatus(false, 'Unavailable', 'This browser does not support Web Push.');
    enableButton.disabled = true;
    return;
  }

  currentSubscription = await serviceWorkerRegistration.pushManager.getSubscription();
  const enabled = currentSubscription != null && Notification.permission === 'granted';
  if (enabled) {
    setStatus(true, 'Enabled', 'This device can receive Fresh Flag expiry reminders.');
  } else if (Notification.permission === 'denied') {
    setStatus(false, 'Blocked', 'Notifications are blocked in system settings for this Home Screen app.');
  } else {
    setStatus(false, 'Off', 'Enable notifications to receive backend expiry reminders on this device.');
  }
}

function setStatus(enabled, label, text) {
  statusPill.textContent = label;
  statusPill.classList.toggle('on', enabled);
  statusText.textContent = text;
  enableButton.classList.toggle('hidden', enabled);
  testButton.classList.toggle('hidden', !enabled);
  disableButton.classList.toggle('hidden', !enabled);
}

function setBusy(busy) {
  for (const button of [enableButton, testButton, disableButton, signOutButton]) {
    button.disabled = busy;
  }
}

function pushSupported() {
  return serviceWorkerRegistration != null &&
    'PushManager' in window &&
    'Notification' in window;
}

function ensurePushSupported() {
  if (!pushSupported()) throw new Error('This browser does not support Web Push.');
}

function base64UrlToUint8Array(value) {
  const padding = '='.repeat((4 - value.length % 4) % 4);
  const base64 = (value + padding).replaceAll('-', '+').replaceAll('_', '/');
  const binary = atob(base64);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

function friendlyError(error, fallback) {
  const raw = typeof error?.message === 'string' ? error.message : '';
  if (raw.includes('auth/invalid-credential') || raw.includes('auth/wrong-password')) {
    return 'Incorrect email or password.';
  }
  if (raw.includes('auth/too-many-requests')) {
    return 'Too many attempts. Try again later.';
  }
  return raw.replace(/^Firebase:\s*/i, '') || fallback;
}

function showError(text) {
  message.textContent = text;
  message.className = 'message error';
}

function showSuccess(text) {
  message.textContent = text;
  message.className = 'message success';
}

function clearMessage() {
  message.textContent = '';
  message.className = 'message';
}
