import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:video_journal/core/logging/app_logger.dart';
import 'package:video_journal/features/auth/domain/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/drive.file',
    ],
  );

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<User?> signInWithGoogle() async {
    try {
      AppLogger.info(LogCategory.auth, 'Starting Google Sign-In process');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        AppLogger.info(LogCategory.auth, 'Google Sign-In was cancelled by the user');
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      AppLogger.info(LogCategory.auth, 'Successfully authenticated user: ${userCredential.user?.email}');
      return userCredential.user;
    } catch (e, stackTrace) {
      AppLogger.error(LogCategory.auth, 'Firebase authentication failed', e, stackTrace);
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      AppLogger.info(LogCategory.auth, 'Signing out user');
      await _auth.signOut();
      await _googleSignIn.signOut();
    } catch (e, stackTrace) {
      AppLogger.error(LogCategory.auth, 'Error during sign out', e, stackTrace);
    }
  }

  @override
  Future<String?> getAccessToken() async {
    try {
      final googleUser = await _googleSignIn.signInSilently();
      if (googleUser == null) return null;
      final googleAuth = await googleUser.authentication;
      return googleAuth.accessToken;
    } catch (e, stackTrace) {
      AppLogger.error(LogCategory.auth, 'Failed to fetch access token', e, stackTrace);
      return null;
    }
  }
}
