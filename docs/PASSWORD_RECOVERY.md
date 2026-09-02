# Fresh Flag password recovery

Fresh Flag separates normal user recovery from project-operator recovery.

## User recovery

### Forgot password

The login screen uses Firebase Authentication's password-reset email API.

This path is confirmed working in production: password-reset requests from both the Fresh Flag app and the Firebase Console produced reset emails. During testing, the emails were initially hard to locate, which made delivery appear broken even though Firebase had sent them.

Because Firebase accepting a reset request does not itself prove that a message has reached the inbox yet, the app deliberately shows a non-enumerating confirmation:

> If an account exists for that email, a reset link will be sent. Check your inbox and spam folder.

The normal forgotten-password flow remains:

```text
Login → Forgot password? → Firebase reset email → Firebase reset link → choose a new password
```

If the message is not immediately visible, check spam/junk, search all mail for the Firebase sender, and allow for delivery/indexing delay before treating the path as failed.

### Change password while signed in

A signed-in email/password user can go to:

```text
Settings → Change password
```

Fresh Flag requires the current password, reauthenticates with Firebase, and then changes the password. This path does not depend on reset-email delivery.

## Project-operator emergency recovery

Household `owner` and `admin` roles are application authorization roles. They must **not** be able to change another user's Firebase Authentication password.

A trusted Fresh Flag project operator with Firebase/Google Cloud administrative credentials can reset an account out of band with the repository's Admin SDK tool when normal user recovery is genuinely unavailable.

The tool is local-only and is not deployed as a Cloud Function or shipped in the iPhone app.

### Prerequisites

Use Application Default Credentials for a Google account/service identity authorized to administer the `freshflag` Firebase project. For example, on an operator workstation with the Google Cloud CLI:

```bash
gcloud auth application-default login
```

Do not commit service-account JSON files, passwords, or other credentials to the repository.

### Reset a user's password

From the repository root:

```bash
cd functions
read -s -p 'Temporary password: ' FRESHFLAG_RESET_PASSWORD
echo
export FRESHFLAG_RESET_PASSWORD
npm run admin:reset-password -- user@example.com
unset FRESHFLAG_RESET_PASSWORD
```

The tool resolves the Firebase user by email and updates that user's Firebase Authentication password directly.

After an operator reset, give the temporary password to the user through an appropriate private channel and ask them to sign in and immediately use **Settings → Change password**.

## Security boundary

- Household Owner/Admin: manage household data and access only.
- Individual user: can use the normal Firebase reset-email flow or change their own password after reauthentication.
- Firebase project operator: can perform emergency account recovery using privileged Admin SDK credentials.
- No password is ever readable or recoverable from Firebase; recovery always sets a new password.
