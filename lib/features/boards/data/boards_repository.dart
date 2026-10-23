import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BoardSummary {
  const BoardSummary({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerId,
    required this.memberIds,
    required this.updatedAt,
    required this.archivedAt,
  });

  final String id;
  final String name;
  final String description;
  final String ownerId;
  final List<String> memberIds;
  final DateTime? updatedAt;
  final DateTime? archivedAt;

  factory BoardSummary.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final updatedAtValue = data['updatedAt'];
    final archivedAtValue = data['archivedAt'];

    return BoardSummary(
      id: document.id,
      name: data['name'] as String? ?? '(Chưa có tên)',
      description: data['description'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      memberIds: (data['memberIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      updatedAt: updatedAtValue is Timestamp ? updatedAtValue.toDate() : null,
      archivedAt: archivedAtValue is Timestamp
          ? archivedAtValue.toDate()
          : null,
    );
  }
}

class BoardsRepository {
  BoardsRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<BoardSummary>> watchMyActiveBoards(String uid) {
    // This where clause is required by firestore.rules: only return boards
    // where the signed-in user is a member.
    return _firestore
        .collection('boards')
        .where('memberIds', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
          final boards = snapshot.docs
              .map(BoardSummary.fromDocument)
              .where((board) => board.archivedAt == null)
              .toList();
          boards.sort((a, b) {
            final aDate = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
          return boards;
        });
  }

  Future<String> createBoard({
    required String name,
    required String description,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Bạn cần đăng nhập trước khi tạo board.');
    }

    final cleanName = name.trim();
    final cleanDescription = description.trim();
    if (cleanName.isEmpty || cleanName.length > 100) {
      throw ArgumentError('Tên board phải có từ 1 đến 100 ký tự.');
    }
    if (cleanDescription.length > 500) {
      throw ArgumentError('Mô tả board không được dài quá 500 ký tự.');
    }

    final email = user.email?.trim().toLowerCase() ?? '';
    final displayName = (user.displayName?.trim().isNotEmpty ?? false)
        ? user.displayName!.trim()
        : email;
    if (email.isEmpty || displayName.isEmpty) {
      throw StateError('Tài khoản cần có email và tên hiển thị hợp lệ.');
    }

    final boardRef = _firestore.collection('boards').doc();
    final memberRef = boardRef.collection('members').doc(user.uid);
    final batch = _firestore.batch();

    batch.set(boardRef, {
      'name': cleanName,
      'description': cleanDescription,
      'ownerId': user.uid,
      'memberIds': [user.uid],
      'archivedAt': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Create the board and its owner record atomically so that the two records
    // cannot be left out of sync if one operation fails.
    batch.set(memberRef, {
      'role': 'owner',
      'displayName': displayName,
      'email': email,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return boardRef.id;
  }
}
