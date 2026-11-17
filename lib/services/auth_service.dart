import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../models/user_profile.dart';
import 'household_service.dart';
import 'sync_service.dart';

/// Authentication service wrapping Firebase Auth
class AuthService {
  factory AuthService() => _instance;
  AuthService._internal();
  static final AuthService _instance = AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Explicit scope: constructing GoogleSignIn() bare can make token minting
  // on silently-restored sessions fail with MISSING_SCOPE (seen during
  // account-deletion reauth on device).
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  /// Current Firebase user
  User? get currentUser => _auth.currentUser;

  /// Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'sign-in-cancelled',
        message: 'Google sign-in was cancelled',
      );
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    await _profileAfterSignIn(userCredential.user!);
    return userCredential;
  }

  /// Sign in with email and password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _profileAfterSignIn(userCredential.user!);
    return userCredential;
  }

  /// Sign up with email and password
  Future<UserCredential> signUpWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    // The account exists and the user is signed in from here on: a dropped
    // network in the steps below must not show "sign-up failed" (Lead L1).
    // ensureProfile() retries on the next auth change / app start.
    final user = userCredential.user!;
    _pendingDisplayNames[user.uid] = displayName;
    try {
      await user.updateDisplayName(displayName);
    } catch (e) {
      debugPrint('Sign-up: setting the display name failed: $e');
    }
    await _profileAfterSignIn(user, displayName: displayName);
    return userCredential;
  }

  /// Sign in with Apple
  Future<UserCredential> signInWithApple() async {
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );

    final userCredential = await _auth.signInWithCredential(oauthCredential);

    // Apple may provide name only on first sign-in
    final name = [
      appleCredential.givenName,
      appleCredential.familyName,
    ].where((n) => n != null).join(' ');

    if (name.isNotEmpty) {
      await userCredential.user?.updateDisplayName(name);
    }

    if (name.isNotEmpty) _pendingDisplayNames[userCredential.user!.uid] = name;
    await _profileAfterSignIn(
      userCredential.user!,
      displayName: name.isNotEmpty ? name : null,
    );
    return userCredential;
  }

  /// Sign out
  Future<void> signOut() async {
    // Tear down Firestore listeners BEFORE invalidating auth. Cancelling
    // snapshot subscriptions while the token is still valid prevents the
    // `permission-denied` noise that would otherwise fire the moment the
    // user is signed out and the listener attempts one more read under a
    // null/other auth context.
    SyncService().dispose();
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Delete account and clean up Firestore data.
  ///
  /// Order matters, twice over:
  /// 1. Re-authenticate FIRST — `user.delete()` demands a recent login,
  ///    and discovering that after the wipe would leave a data-less
  ///    account behind. A stale session aborts here with nothing deleted.
  /// 2. Household teardown goes through HouseholdService: its member-first
  ///    ordering is required by the `isHouseholdMember` Firestore rule
  ///    (which reads the household doc — so that doc must be deleted
  ///    LAST), and it also cleans split proposals and reference subs.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;

    await _ensureRecentLogin(user);

    // Leave/disband household. Best-effort: a failed partner-profile
    // update must not strand the deletion — the partner's device
    // self-heals via householdCleanupProvider once the household doc
    // disappears.
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final householdId = userDoc.data()?['householdId'] as String?;
      if (householdId != null) {
        final householdDoc =
            await _firestore.collection('households').doc(householdId).get();
        if (!householdDoc.exists) {
          // Dangling reference — just clear it on our own profile.
          await _firestore.collection('users').doc(uid).update({
            'householdId': FieldValue.delete(),
          });
        } else if (householdDoc.data()?['createdBy'] == uid) {
          await HouseholdService().disbandHousehold(uid);
        } else {
          await HouseholdService().leaveHousehold(uid);
        }
      }
    } catch (e) {
      debugPrint('Household teardown during account deletion failed: $e');
    }

    // Delete the subscriptions subcollection (batched; reference subs and
    // split proposals were already removed by the household teardown).
    final subsSnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('subscriptions')
        .get();
    final docs = subsSnapshot.docs;
    for (var i = 0; i < docs.length; i += 500) {
      final batch = _firestore.batch();
      for (final doc in docs.skip(i).take(500)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    // Delete user profile document
    await _firestore.collection('users').doc(uid).delete();

    // Tear down Firestore listeners BEFORE invalidating auth — same reason
    // as signOut(): `user.delete()` revokes the token, and any listener
    // still alive at that moment fires a permission-denied error.
    SyncService().dispose();

    // Delete Firebase Auth account
    await user.delete();

    // Drop the cached Google session so a later "sign in" can't silently
    // hand back credentials for the account we just deleted.
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Google sign-out after account deletion failed: $e');
    }
  }

  /// Firebase rejects `user.delete()` when the last sign-in is older than
  /// its recent-login window (~5 minutes). Verify/refresh credentials
  /// BEFORE any data is wiped, so a stale session aborts cleanly.
  ///
  /// Google users are re-authenticated in place (silently when possible).
  /// Email/Apple users get a `requires-recent-login` error the UI can
  /// translate into "sign in again, then retry".
  Future<void> _ensureRecentLogin(User user) async {
    final lastSignIn = user.metadata.lastSignInTime;
    if (lastSignIn != null &&
        DateTime.now().difference(lastSignIn) < const Duration(minutes: 5)) {
      return;
    }

    final providers = user.providerData.map((p) => p.providerId).toSet();
    if (providers.contains('google.com')) {
      try {
        await _reauthenticateWithGoogle(user);
        return;
      } catch (e) {
        // Any reauth failure (cancelled picker, MISSING_SCOPE token errors,
        // user-mismatch) falls through to the clean abort below — nothing
        // has been deleted at this point.
        debugPrint('Google reauth for account deletion failed: $e');
      }
    }

    throw FirebaseAuthException(
      code: 'requires-recent-login',
      message:
          'For security, sign out and sign back in, then retry deleting '
          'your account.',
    );
  }

  Future<void> _reauthenticateWithGoogle(User user) async {
    var googleUser = await _googleSignIn.signInSilently();
    googleUser ??= await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google sign-in cancelled');
    }

    GoogleSignInAuthentication googleAuth;
    try {
      googleAuth = await googleUser.authentication;
    } on Exception {
      // Silently-restored sessions can fail token minting (MISSING_SCOPE).
      // Drop the session and get a fresh interactive one — new consent,
      // new tokens.
      await _googleSignIn.signOut();
      googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in cancelled');
      }
      googleAuth = await googleUser.authentication;
    }

    // Throws user-mismatch if a different Google account was picked —
    // which correctly aborts before anything is deleted.
    await user.reauthenticateWithCredential(
      GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      ),
    );
  }

  /// Send password reset email
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Get user profile from Firestore
  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromJson({...doc.data()!, 'uid': uid});
  }

  /// Stream user profile changes
  Stream<UserProfile?> userProfileStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromJson({...doc.data()!, 'uid': uid});
    });
  }

  /// Update user profile in Firestore
  Future<void> updateUserProfile(UserProfile profile) async {
    await _firestore
        .collection('users')
        .doc(profile.uid)
        .set(profile.toJson(), SetOptions(merge: true));
  }

  /// Names given at sign-up (or by Apple on first sign-in) whose profile
  /// write hasn't landed yet, so a later [ensureProfile] can still use them.
  final Map<String, String> _pendingDisplayNames = {};

  /// Profile step after a successful sign-in. Never throws: the user IS
  /// signed in, and [ensureProfile] (run on every auth change) repairs a
  /// missing profile once the network is back.
  Future<void> _profileAfterSignIn(User user, {String? displayName}) async {
    try {
      await _ensureUserProfile(user, displayName: displayName);
      _pendingDisplayNames.remove(user.uid);
    } catch (e) {
      debugPrint('Profile write after sign-in failed (will retry): $e');
    }
  }

  /// Make sure users/{uid} exists for [user]. Idempotent; called on every
  /// auth change and before household writes that `update()` the profile.
  /// Throws when the server can't be reached (callers retry).
  Future<void> ensureProfile(User user) async {
    final displayName = _pendingDisplayNames[user.uid];
    if (displayName != null && (user.displayName ?? '').isEmpty) {
      try {
        await user.updateDisplayName(displayName);
      } catch (e) {
        debugPrint('Retrying display name failed: $e');
      }
    }
    await ensureUserProfileDoc(
      _firestore,
      uid: user.uid,
      displayName: displayName ?? user.displayName ?? '',
      email: user.email ?? '',
      photoUrl: user.photoURL,
    );
    _pendingDisplayNames.remove(user.uid);
  }

  /// [ensureProfile] for the signed-in user with [uid]; no-op otherwise.
  Future<void> ensureProfileFor(String uid) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != uid) return;
    await ensureProfile(user);
  }

  /// [ensureProfile] with backoff, for the auth-state listener: a sign-up
  /// that lost the network gets its profile once the connection is back.
  Future<void> ensureProfileWithRetry(User user) async {
    const delays = [5, 15, 45, 120, 300];
    for (var attempt = 0; ; attempt++) {
      try {
        await ensureProfile(user);
        return;
      } catch (e) {
        if (attempt >= delays.length || _auth.currentUser?.uid != user.uid) {
          debugPrint('Profile still missing, giving up until next start: $e');
          return;
        }
        await Future<void>.delayed(Duration(seconds: delays[attempt]));
        if (_auth.currentUser?.uid != user.uid) return;
      }
    }
  }

  /// Ensure user profile exists in Firestore after sign-in
  Future<void> _ensureUserProfile(User user, {String? displayName}) async {
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      final profile = UserProfile(
        uid: user.uid,
        displayName: displayName ?? user.displayName ?? '',
        email: user.email ?? '',
        photoUrl: user.photoURL,
        isPro: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _firestore.collection('users').doc(user.uid).set(profile.toJson());
    } else {
      // Update last sign-in info
      await _firestore.collection('users').doc(user.uid).update({
        'updatedAt': DateTime.now().toIso8601String(),
        if (user.photoURL != null) 'photoUrl': user.photoURL,
      });
    }
  }

  /// Generate a random nonce for Apple Sign In
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  /// SHA256 hash for Apple Sign In nonce
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

/// Create users/{uid} if it doesn't exist; leave an existing one alone.
///
/// Reads from the server, never the local cache: an offline cache that
/// hasn't seen the doc would report "missing", and recreating it would
/// wipe the user's householdId. Offline → throws, nothing written.
/// The create is a merge that never sets householdId, so even a race with
/// a household write can't clear it.
Future<void> ensureUserProfileDoc(
  FirebaseFirestore firestore, {
  required String uid,
  required String displayName,
  required String email,
  String? photoUrl,
  DateTime? now,
}) async {
  final ref = firestore.collection('users').doc(uid);
  final doc = await ref.get(const GetOptions(source: Source.server));
  if (doc.exists) return;
  final at = (now ?? DateTime.now()).toIso8601String();
  await ref.set({
    'uid': uid,
    'displayName': displayName,
    'email': email,
    'photoUrl': photoUrl,
    'isPro': false,
    'createdAt': at,
    'updatedAt': at,
  }, SetOptions(merge: true),);
}
