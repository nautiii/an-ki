import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthState {
  final User? user;
  final bool isLoading;
  final String? errorMessage;

  AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isAuthenticated => user != null;
  bool get isAnonymous => user?.isAnonymous ?? false;
}

class AuthProvider extends StateNotifier<AuthState> {
  final FirebaseAuth? _firebaseAuthOverride;
  final GoogleSignIn? _googleSignInOverride;

  AuthProvider({FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn})
      : _firebaseAuthOverride = firebaseAuth,
        _googleSignInOverride = googleSignIn,
        super(AuthState()) {
    initializeAuth();
  }

  FirebaseAuth get _firebaseAuth => _firebaseAuthOverride ?? FirebaseAuth.instance;
  GoogleSignIn get _googleSignIn => _googleSignInOverride ?? GoogleSignIn();

  void initializeAuth() {
    _firebaseAuth.authStateChanges().listen((User? user) {
      state = state.copyWith(user: user);
    });
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String surname,
  }) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        await user.updateDisplayName("$name $surname");
        await user.reload();
      }

      state = state.copyWith(
        user: _firebaseAuth.currentUser,
        isLoading: false,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        errorMessage: _getErrorMessage(e.code),
        isLoading: false,
      );
      return false;
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      state = state.copyWith(
        user: userCredential.user,
        isLoading: false,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        errorMessage: _getErrorMessage(e.code),
        isLoading: false,
      );
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      state = state.copyWith(isLoading: true);

      await _firebaseAuth.signOut();
      await _googleSignIn.signOut();
      state = AuthState();
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Erreur lors de la déconnexion',
        isLoading: false,
      );
    }
  }

  Future<bool> signInAnonymously() async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final userCredential = await _firebaseAuth.signInAnonymously();
      state = state.copyWith(
        user: userCredential.user,
        isLoading: false,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        errorMessage: _getErrorMessage(e.code),
        isLoading: false,
      );
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        state = state.copyWith(isLoading: false);
        return false;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );
      state = state.copyWith(
        user: userCredential.user,
        isLoading: false,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        errorMessage: _getErrorMessage(e.code),
        isLoading: false,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Erreur lors de la connexion Google',
        isLoading: false,
      );
      return false;
    }
  }

  Future<bool> linkWithGoogle() async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        state = state.copyWith(isLoading: false);
        return false;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // On lie les identifiants Google au compte anonyme actuel
      final userCredential = await state.user?.linkWithCredential(credential);
      state = state.copyWith(
        user: userCredential?.user,
        isLoading: false,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        errorMessage: _getErrorMessage(e.code),
        isLoading: false,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Erreur lors de la liaison du compte',
        isLoading: false,
      );
      return false;
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'Le mot de passe est trop faible.';
      case 'email-already-in-use':
        return 'Cet email est déjà utilisé.';
      case 'invalid-email':
        return 'L\'email n\'est pas valide.';
      case 'user-not-found':
        return 'Utilisateur non trouvé.';
      case 'wrong-password':
        return 'Mot de passe incorrect.';
      default:
        return 'Une erreur est survenue.';
    }
  }
}

final authProvider = StateNotifierProvider<AuthProvider, AuthState>(
  (ref) => AuthProvider(),
);
