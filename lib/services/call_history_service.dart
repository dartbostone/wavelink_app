import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/call_model.dart';

/// Reads completed calls for the Call History screen. Call *creation* is
/// handled by [CallingService] (every call is one `calls/{id}` document
/// used first for signaling, then kept as the history record).
class CallHistoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<CallModel>> watchHistory(String myUid) {
    final query = _db
        .collection('calls')
        .where(
          Filter.or(
            Filter('callerId', isEqualTo: myUid),
            Filter('calleeId', isEqualTo: myUid),
          ),
        );
    return query.snapshots().map((snapshot) {
      final calls = snapshot.docs
          .map((doc) => CallModel.fromMap(doc.id, doc.data()))
          // Only show calls that reached a terminal state.
          .where(
            (c) =>
                c.status != CallStatus.ringing &&
                c.status != CallStatus.calling,
          )
          .toList();
      calls.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return calls;
    });
  }
}
