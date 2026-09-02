import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

const email = process.argv[2]?.trim();
const newPassword = process.env.FRESHFLAG_RESET_PASSWORD;

if (!email || !email.includes('@')) {
  console.error('Usage: FRESHFLAG_RESET_PASSWORD=<new password> npm run admin:reset-password -- user@example.com');
  process.exit(2);
}

if (!newPassword || newPassword.length < 6) {
  console.error('Set FRESHFLAG_RESET_PASSWORD to a password with at least 6 characters.');
  process.exit(2);
}

initializeApp({
  credential: applicationDefault(),
  projectId: process.env.GOOGLE_CLOUD_PROJECT || 'freshflag',
});

const auth = getAuth();
const user = await auth.getUserByEmail(email);
await auth.updateUser(user.uid, { password: newPassword });

console.log(`Password reset completed for ${email} (${user.uid}).`);
console.log('Ask the user to sign in with the new password and change it again in Fresh Flag Settings.');
