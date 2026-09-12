import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../models/call_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/call_history_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';

/// Spec §9 — Call History: caller/callee, call type, time, duration,
/// missed-call indicator.
class CallHistoryScreen extends StatelessWidget {
  final bool embedded;
  const CallHistoryScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().uid;

    final body = uid == null
        ? const LoadingIndicator()
        : StreamBuilder<List<CallModel>>(
            stream: CallHistoryService().watchHistory(uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const EmptyState(icon: Icons.wifi_off, title: 'Could not load call history');
              }
              if (!snapshot.hasData) return const LoadingIndicator(label: 'Loading history…');
              final calls = snapshot.data!;
              if (calls.isEmpty) {
                return const EmptyState(
                  icon: Icons.call_outlined,
                  title: 'No calls yet',
                  subtitle: 'Your audio and video calls will show up here.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: calls.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) => _CallHistoryTile(call: calls[i], myUid: uid),
              );
            },
          );

    if (embedded) return SafeArea(child: body);
    return Scaffold(appBar: AppBar(title: const Text('Call History')), body: SafeArea(child: body));
  }
}

class _CallHistoryTile extends StatelessWidget {
  final CallModel call;
  final String myUid;
  const _CallHistoryTile({required this.call, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final incoming = call.calleeId == myUid;
    final otherName = incoming ? call.callerName : call.calleeName;
    final isMissed = call.status == CallStatus.missed;
    final isRejected = call.status == CallStatus.rejected;
    final statusColor = (isMissed || isRejected) ? AppColors.danger : AppColors.textSecondary;

    String statusLabel;
    if (isMissed) {
      statusLabel = 'Missed';
    } else if (isRejected) {
      statusLabel = incoming ? 'Declined' : 'Declined by them';
    } else if (call.status == CallStatus.failed || call.status == CallStatus.disconnected) {
      statusLabel = 'Call dropped';
    } else {
      statusLabel = DateFormatUtils.duration(call.duration);
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withOpacity(0.12),
        child: Icon(
          call.type == CallType.video ? Icons.videocam : Icons.call,
          color: AppColors.primary,
        ),
      ),
      title: Text(otherName, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Row(
        children: [
          Icon(
            incoming ? Icons.call_received : Icons.call_made,
            size: 14,
            color: statusColor,
          ),
          const SizedBox(width: 4),
          Text(DateFormatUtils.relativeDay(call.createdAt), style: TextStyle(color: statusColor)),
        ],
      ),
      trailing: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
    );
  }
}
