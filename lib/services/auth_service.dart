import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '593151530958-msd84e8ln372r4c7m2l2o3t8o18uj3f0.apps.googleusercontent.com',
  );

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserModel> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;
    final userModel = UserModel(
      uid: user.uid,
      email: email,
      displayName: displayName,
      createdAt: DateTime.now(),
    );
    await _db.collection('users').doc(user.uid).set(userModel.toMap());
    return userModel;
  }

  Future<void> login({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserModel?> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      provider.addScope('email');
      final result = await _auth.signInWithPopup(provider);
      final user = result.user;
      if (user == null) return null;
      final doc = await _db.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        final userModel = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? 'User',
          createdAt: DateTime.now(),
        );
        await _db.collection('users').doc(user.uid).set(userModel.toMap());
        return userModel;
      }
      return UserModel.fromDoc(doc);
    }

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user!;

    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      final userModel = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? googleUser.displayName ?? 'User',
        createdAt: DateTime.now(),
      );
      await _db.collection('users').doc(user.uid).set(userModel.toMap());
      return userModel;
    }
    return UserModel.fromDoc(doc);
  }

  // App 啟動時處理 Google redirect 結果
  Future<void> handleGoogleRedirectResult() async {
    if (!kIsWeb) return;
    try {
      final result = await _auth.getRedirectResult();
      if (result.user == null) return;
      final user = result.user!;
      final doc = await _db.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        final userModel = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? 'User',
          createdAt: DateTime.now(),
        );
        await _db.collection('users').doc(user.uid).set(userModel.toMap());
      }
    } catch (_) {}
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<UserModel?> fetchUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromDoc(doc);
  }

  Future<UserModel?> fetchCurrentUser() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromDoc(doc);
  }

  Stream<UserModel?> watchCurrentUser() {
    final uid = currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromDoc(doc) : null);
  }
}
