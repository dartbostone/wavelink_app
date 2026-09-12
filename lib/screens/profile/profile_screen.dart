import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/common_button.dart';
import 'edit_profile_screen.dart';

/// Spec §5 — User Profile: picture, name, email, online status, Edit
/// Profile, Logout. Dark-mode toggle lives here too (Bonus 3).
class ProfileScreen extends StatelessWidget {
  final bool embedded;
  const ProfileScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final user = auth.currentUser;

    final body = SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.primary.withOpacity(0.15),
              backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
              child: user?.avatarUrl == null
                  ? Text(
                      (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 32, color: AppColors.primary, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(user?.name ?? '—', style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(user?.email ?? '', style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(height: 8),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppColors.online, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                const Text('Online', style: TextStyle(color: AppColors.online, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          CommonButton(
            label: 'Edit Profile',
            outlined: true,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Dark mode'),
            value: theme.mode == ThemeMode.dark,
            onChanged: (_) => theme.toggle(),
          ),
          const SizedBox(height: 12),
          CommonButton(
            label: 'Logout',
            color: AppColors.danger,
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Log out?'),
                  content: const Text('You will need to sign in again to make calls.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out')),
                  ],
                ),
              );
              if (confirmed == true) {
                await context.read<AuthProvider>().logout();
              }
            },
          ),
        ],
      ),
    );

    if (embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('Profile')), body: body);
  }
}
