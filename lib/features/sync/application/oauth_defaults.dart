/// Product-wide Google OAuth client, baked into the build so customers never
/// see client IDs — they just tap "Connect Google Drive" and approve.
///
/// ONE-TIME developer setup (you, not your users — see docs/GOOGLE_DRIVE.md):
///  1. Google Cloud Console → create project → enable Drive API.
///  2. OAuth consent screen → External → fill name/email →
///     **Publish to production** (in "Testing" mode Google expires refresh
///     tokens after 7 days — customers would be disconnected weekly).
///  3. Credentials → Create OAuth client ID → type **Desktop app**.
///  4. Paste the two values below and rebuild/release.
///
/// Installed-app client secrets are explicitly non-confidential per Google's
/// OAuth docs — embedding them is the standard pattern for desktop/mobile
/// apps. Access to a user's Drive is still gated by their own Google login
/// and consent.
const kDefaultGoogleClientId =
    '1032567323356-jcrts74acnbpmacgr5a19d76bdeantlo.apps.googleusercontent.com';
const kDefaultGoogleClientSecret = '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';

bool get hasEmbeddedGoogleClient =>
    kDefaultGoogleClientId.isNotEmpty && kDefaultGoogleClientSecret.isNotEmpty;
