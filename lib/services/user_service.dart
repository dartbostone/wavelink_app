import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

/// Reads the `users` collection: contact list, search, single profile lookups.
class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Live list of every user except [myUid], ordered online-first then by name.
  Stream<List<UserModel>> watchContacts(String myUid) {
    return _db.collection('users').snapshots().map((snapshot) {
      final users = snapshot.docs
          .where((doc) => doc.id != myUid)
          .map((doc) => UserModel.fromMap(doc.id, doc.data()))
          .toList();
      users.sort((a, b) {
        if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return users;
    });
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.id, doc.data()!);
  }

  Stream<UserModel?> watchUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.id, doc.data()!);
    });
  }

  /// Client-side search over the already-cached contact list. Fine for the
  /// scale of this assignment; a production app would use a search index
  /// (e.g. Algolia) once the user base grows large.
  List<UserModel> filter(List<UserModel> users, String query) {
    if (query.trim().isEmpty) return users;
    final q = query.trim().toLowerCase();
    return users
        .where(
          (u) =>
              u.name.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> updateProfile(
    String uid, {
    String? name,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (avatarUrl != null) updates['avatarUrl'] = avatarUrl;
    if (updates.isEmpty) return;
    await _db
        .collection('users')
        .doc(uid)
        .set(updates, SetOptions(merge: true));
  }
}
