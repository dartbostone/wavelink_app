import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/contacts_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/user_tile.dart';
import '../call/audio_call_screen.dart';
import '../call/video_call_screen.dart';

/// Spec §4 (Contacts) + §10 (Search) — full list of users with avatar,
/// online/offline status, and audio/video call buttons.
class ContactsScreen extends StatefulWidget {
  /// When `true`, this screen is a tab inside [HomeScreen]'s shell and
  /// shouldn't render its own AppBar/Scaffold chrome twice.
  final bool embedded;
  const ContactsScreen({super.key, this.embedded = false});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.embedded) return; // HomeScreen already started the stream.
    final uid = context.read<AuthProvider>().uid;
    if (uid != null) context.read<ContactsProvider>().start(uid);
  }

  @override
  Widget build(BuildContext context) {
    final contacts = context.watch<ContactsProvider>();

    final body = SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: contacts.search,
              decoration: InputDecoration(
                hintText: 'Search people...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(child: _buildList(contacts)),
        ],
      ),
    );

    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('Contacts')), body: body);
  }

  Widget _buildList(ContactsProvider contacts) {
    if (contacts.isLoading) return const LoadingIndicator(label: 'Loading contacts…');
    if (contacts.errorMessage != null) {
      return EmptyState(icon: Icons.wifi_off, title: contacts.errorMessage!);
    }
    if (contacts.visibleContacts.isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline,
        title: 'No contacts found',
        subtitle: 'Try a different search, or invite someone new.',
      );
    }
    return ListView.separated(
      itemCount: contacts.visibleContacts.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final user = contacts.visibleContacts[i];
        return UserTile(
          user: user,
          onAudioCall: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AudioCallScreen(callee: user)),
          ),
          onVideoCall: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => VideoCallScreen(callee: user)),
          ),
        );
      },
    );
  }
}
