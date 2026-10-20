import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthRepository {
  bool get isAvailable => Firebase.apps.isNotEmpty;

  Stream<User?> get authStateChanges => isAvailable
      ? FirebaseAuth.instance.authStateChanges()
      : Stream<User?>.value(null);

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    _requireFirebase();
    try {
      return await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_authMessage(error.code));
    } catch (_) {
      throw const AuthFailure(
        'Không thể đăng nhập lúc này. Vui lòng kiểm tra kết nối mạng và thử lại.',
      );
    }
  }

  Future<UserCredential> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    _requireFirebase();
    UserCredential? credential;
    try {
      credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthFailure('Không nhận được thông tin tài khoản mới.');
      }

      await user.updateDisplayName(displayName.trim());
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': displayName.trim(),
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await user.reload();
      return credential;
    } on AuthFailure {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_authMessage(error.code));
    } on FirebaseException catch (error) {
      if (credential?.user case final user?) {
        try {
          await user.delete();
        } catch (_) {
          await FirebaseAuth.instance.signOut();
        }
      }
      throw AuthFailure(_firestoreMessage(error.code));
    } catch (_) {
      throw const AuthFailure(
        'Không thể tạo hồ sơ người dùng. Vui lòng thử lại khi có kết nối mạng.',
      );
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    _requireFirebase();
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_authMessage(error.code));
    } catch (_) {
      throw const AuthFailure(
        'Không gửi được email đặt lại mật khẩu. Vui lòng kiểm tra kết nối mạng.',
      );
    }
  }

  Future<void> signOut() async {
    _requireFirebase();
    try {
      await FirebaseAuth.instance.signOut();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_authMessage(error.code));
    } catch (_) {
      throw const AuthFailure('Không thể đăng xuất. Vui lòng thử lại.');
    }
  }

  void _requireFirebase() {
    if (!isAvailable) {
      throw const AuthFailure(
        'Firebase chưa được cấu hình. Hãy cấu hình Firebase project để sử dụng chức năng tài khoản.',
      );
    }
  }

  String _authMessage(String code) => switch (code) {
    'email-already-in-use' =>
      'Email này đã được đăng ký. Hãy đăng nhập hoặc dùng email khác.',
    'invalid-email' => 'Địa chỉ email không hợp lệ.',
    'weak-password' => 'Mật khẩu chưa đủ mạnh. Hãy dùng ít nhất 8 ký tự.',
    'user-disabled' => 'Tài khoản này đã bị vô hiệu hóa.',
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'Email hoặc mật khẩu không đúng.',
    'too-many-requests' =>
      'Bạn đã thử quá nhiều lần. Vui lòng chờ một lúc rồi thử lại.',
    'network-request-failed' =>
      'Không có kết nối mạng. Hãy kiểm tra Internet và thử lại.',
    'operation-not-allowed' =>
      'Đăng nhập Email/Mật khẩu chưa được bật trong Firebase Authentication.',
    'requires-recent-login' =>
      'Phiên đăng nhập đã cũ. Hãy đăng nhập lại rồi thử lần nữa.',
    _ => 'Không thể xác thực tài khoản lúc này. Vui lòng thử lại.',
  };

  String _firestoreMessage(String code) => switch (code) {
    'permission-denied' =>
      'Tài khoản đã được tạo nhưng chưa lưu được hồ sơ. Hãy kiểm tra Firestore Security Rules cho users/{uid}.',
    'unavailable' || 'deadline-exceeded' =>
      'Không kết nối được Firestore. Kiểm tra Internet rồi thử lại.',
    _ => 'Không lưu được hồ sơ người dùng trong Firestore. Vui lòng thử lại.',
  };
}
