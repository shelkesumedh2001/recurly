import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../models/user_profile.dart';
import 'sync_service.dart';

/// Authentication service wrapping Firebase Auth
class AuthService {
  factory AuthService() => _instance;
  AuthService._internal();
  static final AuthService _instance = AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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
    await _ensureUserProfile(userCredential.user!);
    return userCredential;
  }

  /// Sign in with email and password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _ensureUserProfile(userCredential.user!);
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
    await userCredential.user?.updateDisplayName(displayName);
    await _ensureUserProfile(userCredential.user!, displayName: displayName);
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

    await _ensureUserProfile(
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

  /// Delete account and clean up Firestore data
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;

    // Delete user's subscriptions subcollection
    final subsSnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('subscriptions')
        .get();
    for (final doc in subsSnapshot.docs) {
      await doc.reference.delete();
    }

    // Remove from household if in one
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (userDoc.exists) {
      final data = userDoc.data();
      final householdId = data?['householdId'] as String?;
      if (householdId != null) {
        final householdDoc =
            await _firestore.collection('households').doc(householdId).get();
        if (householdDoc.exists) {
          final householdData = householdDoc.data()!;
          final members =
              (householdData['members'] as List<dynamic>?)?.cast<String>() ??
                  [];
          if (householdData['createdBy'] == uid) {
            // Creator disbanding — remove household
            await _firestore.collection('households').doc(householdId).delete();
            // Clear householdId for other members
            for (final memberId in members) {
              if (memberId != uid) {
                await _firestore.collection('users').doc(memberId).update({
                  'householdId': FieldValue.delete(),
                });
              }
            }
          } else {
            // Member leaving
            members.remove(uid);
            await _firestore.collection('households').doc(householdId).update({
              'members': members,
            });
          }
        }
      }
    }

    // Delete user profile document
    await _firestore.collection('users').doc(uid).delete();

    // Tear down Firestore listeners BEFORE invalidating auth — same reason
    // as signOut(): `user.delete()` revokes the token, and any listener
    // still alive at that moment fires a permission-denied error.
    SyncService().dispose();

    // Delete Firebase Auth account
    await user.delete();
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

/// Custom exception for auth errors
class FirebaseAuthException implements Exception {
  final String code;
  final String message;
  FirebaseAuthException({required this.code, required this.message});

  @override
  String toString() => message;
}
