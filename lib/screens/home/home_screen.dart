import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../models/call_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/contacts_provider.dart';
import '../../services/call_history_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/user_tile.dart';
import '../call/audio_call_screen.dart';
import '../call/video_call_screen.dart';
import '../contacts/contacts_screen.dart';
import '../history/call_history_screen.dart';
import '../profile/profile_screen.dart';

/// Spec §3 — Home shell: bottom navigation between Home / Contacts /
/// Calls / Profile. The Home tab itself shows the profile summary,
/// search, a contacts preview, and recent calls, all in one screen.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthProvider>().uid;
    if (uid != null) context.read<ContactsProvider>().start(uid);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const _DashboardTab(),
      const ContactsScreen(embedded: true),
      const CallHistoryScreen(embedded: true),
      const ProfileScreen(embedded: true),
    ];

    return Scaffold(
      body: tabs[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Contacts',
          ),
          NavigationDestination(
            icon: Icon(Icons.call_outlined),
            selectedIcon: Icon(Icons.call),
            label: 'Calls',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final contacts = context.watch<ContactsProvider>();
    final user = auth.currentUser;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    child: Text(
                      (user?.name.isNotEmpty ?? false)
                          ? user!.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, ${user?.name.split(' ').first ?? 'there'}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          AppStrings.tagline,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                onChanged: contacts.search,
                decoration: InputDecoration(
                  hintText: 'Search people...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                'Contacts',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          if (contacts.isLoading)
            const SliverToBoxAdapter(
              child: SizedBox(height: 120, child: LoadingIndicator()),
            )
          else if (contacts.errorMessage != null)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 160,
                child: EmptyState(
                  icon: Icons.wifi_off,
                  title: contacts.errorMessage!,
                ),
              ),
            )
          else if (contacts.visibleContacts.isEmpty)
            const SliverToBoxAdapter(
              child: SizedBox(
                height: 160,
                child: EmptyState(
                  icon: Icons.people_outline,
                  title: 'No contacts yet',
                  subtitle: 'Invite someone to ConnectCall.',
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final contact = contacts.visibleContacts[i];
                  return UserTile(
                    user: contact,
                    onAudioCall: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AudioCallScreen(callee: contact),
                      ),
                    ),
                    onVideoCall: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => VideoCallScreen(callee: contact),
                      ),
                    ),
                  );
                },
                childCount: contacts.visibleContacts.length > 5
                    ? 5
                    : contacts.visibleContacts.length,
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'Recent calls',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          SliverToBoxAdapter(child: _RecentCallsPreview(myUid: auth.uid ?? '')),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _RecentCallsPreview extends StatelessWidget {
  final String myUid;
  const _RecentCallsPreview({required this.myUid});

  @override
  Widget build(BuildContext context) {
    if (myUid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<List<CallModel>>(
      stream: CallHistoryService().watchHistory(myUid),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const SizedBox(height: 80, child: LoadingIndicator());
        final calls = snapshot.data!.take(3).toList();
        if (calls.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('No calls yet.'),
          );
        }
        return Column(
          children: calls
              .map((c) => _RecentCallRow(call: c, myUid: myUid))
              .toList(),
        );
      },
    );
  }
}

class _RecentCallRow extends StatelessWidget {
  final CallModel call;
  final String myUid;
  const _RecentCallRow({required this.call, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final incoming = call.calleeId == myUid;
    final otherName = incoming ? call.callerName : call.calleeName;
    final missed =
        call.status == CallStatus.missed || call.status == CallStatus.rejected;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withOpacity(0.12),
        child: Icon(
          call.type == CallType.video ? Icons.videocam : Icons.call,
          color: AppColors.primary,
          size: 18,
        ),
      ),
      title: Text(otherName),
      subtitle: Row(
        children: [
          Icon(
            incoming ? Icons.call_received : Icons.call_made,
            size: 14,
            color: missed ? AppColors.danger : AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            missed ? 'Missed' : 'Today',
            style: TextStyle(
              color: missed ? AppColors.danger : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
