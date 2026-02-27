import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Service for Firebase Authentication operations
///
/// Handles user authentication with Firebase Auth including:
/// - Email/password signup and signin
/// - Google Sign-In
/// - Apple Sign-In
/// - Email verification
/// - Password reset
/// - Token management
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  /// Get the currently authenticated Firebase user
  User? get currentUser => _auth.currentUser;

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Get the current user's Firebase ID token
  ///
  /// This token is used for authenticating API requests to the Django backend.
  /// Firebase automatically refreshes tokens, so this method can be called
  /// frequently without concern about token expiration.
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    return await _auth.currentUser?.getIdToken(forceRefresh);
  }

  /// Create a new user account with email and password
  ///
  /// Throws FirebaseAuthException if signup fails
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign in an existing user with email and password
  ///
  /// Throws FirebaseAuthException if signin fails
  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign in with Google using Firebase Auth
  ///
  /// Flow:
  /// 1. Google Sign-In → Google ID token
  /// 2. Create Firebase credential with Google token
  /// 3. Sign in to Firebase with credential
  /// 4. Firebase ID token → Backend (handled by AuthProvider)
  ///
  /// Throws FirebaseAuthException if signin fails
  Future<UserCredential> signInWithGoogle() async {
    try {
      // 1. Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'ERROR_ABORTED_BY_USER',
          message: 'Google Sign-In cancelled by user',
        );
      }

      // 2. Obtain Google auth details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 3. Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Sign in to Firebase
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(
        code: 'ERROR_GOOGLE_SIGN_IN_FAILED',
        message: 'Google Sign-In failed: $e',
      );
    }
  }

  /// Sign in with Apple using Firebase Auth
  ///
  /// Flow:
  /// 1. Apple Sign-In → Apple ID token
  /// 2. Create Firebase credential with Apple token
  /// 3. Sign in to Firebase with credential
  /// 4. Firebase ID token → Backend (handled by AuthProvider)
  ///
  /// Throws FirebaseAuthException if signin fails
  Future<UserCredential> signInWithApple() async {
    try {
      // Check if Apple Sign-In is available (iOS 13+, macOS 10.15+)
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        throw FirebaseAuthException(
          code: 'ERROR_APPLE_SIGNIN_NOT_AVAILABLE',
          message: 'Apple Sign-In is not available on this device',
        );
      }

      // 1. Trigger Apple Sign-In flow
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: Platform.isAndroid
            ? WebAuthenticationOptions(
                clientId:
                    'com.burundi.au.burundi_au_chairmanship.service', // Service ID
                redirectUri: Uri.parse(
                  'https://b4africa-700f7.firebaseapp.com/__/auth/handler',
                ),
              )
            : null,
      );

      // 2. Create Firebase credential
      final oAuthProvider = OAuthProvider('apple.com');
      final credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // 3. Sign in to Firebase
      final userCredential = await _auth.signInWithCredential(credential);

      // 4. Update display name if provided (only on first sign-in)
      if (appleCredential.givenName != null &&
          appleCredential.familyName != null &&
          userCredential.additionalUserInfo?.isNewUser == true) {
        final displayName =
            '${appleCredential.givenName} ${appleCredential.familyName}';
        await userCredential.user?.updateDisplayName(displayName);
      }

      return userCredential;
    } on FirebaseAuthException {
      rethrow;
    } on SignInWithAppleAuthorizationException catch (e) {
      throw FirebaseAuthException(
        code: 'ERROR_APPLE_AUTHORIZATION',
        message: 'Apple Sign-In authorization failed: ${e.code}',
      );
    } catch (e) {
      throw FirebaseAuthException(
        code: 'ERROR_APPLE_SIGN_IN_FAILED',
        message: 'Apple Sign-In failed: $e',
      );
    }
  }

  /// Send email verification to the current user
  ///
  /// Should be called after signup to verify the user's email address
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Reload the current user to get updated verification status
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  /// Send a password reset email to the specified email address
  ///
  /// Firebase will send an email with a link to reset the password
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Sign out the current user from all providers
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  /// Delete the current user's account
  ///
  /// Note: This only deletes the Firebase Auth account.
  /// The Django backend should also delete the user's data.
  Future<void> deleteAccount() async {
    await _auth.currentUser?.delete();
  }

  /// Get a user-friendly error message from FirebaseAuthException
  String getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      // Email/Password errors
      case 'email-already-in-use':
        return 'This email is already registered. Please login instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email. Please sign up first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled. Please contact support.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';

      // Google Sign-In errors
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email but different sign-in credentials. Try signing in using a different method.';
      case 'ERROR_ABORTED_BY_USER':
        return 'Sign-in cancelled. Please try again.';
      case 'ERROR_GOOGLE_SIGN_IN_FAILED':
        return 'Google Sign-In failed. Please check your internet connection and try again.';

      // Apple Sign-In errors
      case 'ERROR_APPLE_SIGNIN_NOT_AVAILABLE':
        return 'Apple Sign-In is not available on this device. Please use iOS 13+ or macOS 10.15+.';
      case 'ERROR_APPLE_AUTHORIZATION':
        return 'Apple Sign-In authorization failed. Please try again.';
      case 'ERROR_APPLE_SIGN_IN_FAILED':
        return 'Apple Sign-In failed. Please try again.';

      // Credential already in use
      case 'credential-already-in-use':
        return 'This account is already associated with another user.';

      default:
        return 'Authentication error: ${e.message ?? e.code}';
    }
  }
}
