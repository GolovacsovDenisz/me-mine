import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  Stream<User?> watchAuthState();

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<void> createUserWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<void> sendPasswordResetEmail({required String email});
}
