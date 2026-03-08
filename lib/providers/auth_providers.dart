import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';

/// Provider for the auth service singleton
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Stream provider for Firebase auth state changes
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// Provider for the current Firebase user
final currentFirebaseUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});

/// Provider for whether user is signed in
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(currentFirebaseUserProvider) != null;
});

/// Stream provider for user profile from Firestore
final currentUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(currentFirebaseUserProvider);
  if (user == null) return Stream.value(null);
  final authService = ref.watch(authServiceProvider);
  return authService.userProfileStream(user.uid);
});

/// Provider for whether the current user is a Pro user
/// TODO: Currently returns true for all users (free launch). Re-enable with RevenueCat later.
final isProFromProfileProvider = Provider<bool>((ref) {
  return true;
});
