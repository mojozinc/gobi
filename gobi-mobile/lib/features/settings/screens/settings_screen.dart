import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/app_providers.dart';
import '../../../data/local/test_data_hydrator.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final isDarkMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Profile Section
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  child: user?.photoUrl != null
                      ? ClipOval(
                          child: Image.network(
                            user!.photoUrl!,
                            fit: BoxFit.cover,
                            width: 100,
                            height: 100,
                          ),
                        )
                      : Icon(
                          Icons.person,
                          size: 50,
                          color: AppColors.primary,
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  user?.name ?? 'User',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (user?.phone != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    user!.phone!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const Divider(),
          // Settings Options
          _SettingsTile(
            icon: Icons.person_outline,
            title: 'Edit Profile',
            subtitle: 'Update your personal information',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile editing coming soon!'),
                ),
              );
            },
          ),
          _SettingsTile(
            icon: isDarkMode ? Icons.dark_mode : Icons.light_mode,
            title: 'Theme',
            subtitle: isDarkMode ? 'Dark mode' : 'Light mode',
            trailing: Switch(
              value: isDarkMode,
              onChanged: (value) {
                ref.read(themeModeProvider.notifier).state = value;
              },
            ),
          ),
          const Divider(),
          // App Information
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'App version ${AppConfig.appVersion}',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: AppConfig.appName,
                applicationVersion: AppConfig.appVersion,
                applicationIcon: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.health_and_safety,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                children: const [
                  Text('Your Personal Medical Assistant'),
                  SizedBox(height: 16),
                  Text(
                    'Gobi helps you manage medications, track health records, and keep your family\'s medical information secure.',
                  ),
                ],
              );
            },
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'How we protect your data',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Privacy policy coming soon!'),
                ),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            subtitle: 'Terms and conditions',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Terms of service coming soon!'),
                ),
              );
            },
          ),
          const Divider(),
          if (kDebugMode) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'DEVELOPER OPTIONS (DEBUG ONLY)',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            _SettingsTile(
              icon: Icons.science_outlined,
              iconColor: AppColors.primary,
              title: 'Seed Sample Medications',
              subtitle: 'Populate 3 rich datasets (Amoxicillin, Prednisone, Metformin)',
              onTap: () async {
                final db = ref.read(appDatabaseProvider);
                await TestDataHydrator.seedSampleDatasets(db, clearExisting: false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sample datasets seeded into SQLite!')),
                  );
                }
              },
            ),
            _SettingsTile(
              icon: Icons.refresh,
              iconColor: AppColors.warning,
              title: 'Reset & Re-Seed Test Data',
              subtitle: 'Wipe local database and reload fresh sample datasets',
              onTap: () async {
                final db = ref.read(appDatabaseProvider);
                await TestDataHydrator.seedSampleDatasets(db, clearExisting: true);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Local database wiped and re-seeded!')),
                  );
                }
              },
            ),
            _SettingsTile(
              icon: Icons.delete_outline,
              iconColor: AppColors.error,
              title: 'Clear Local Database',
              subtitle: 'Reset to an empty state for zero-data testing',
              onTap: () async {
                final db = ref.read(appDatabaseProvider);
                await TestDataHydrator.clearAllLocalData(db);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Local database cleared.')),
                  );
                }
              },
            ),
            _SettingsTile(
              icon: Icons.analytics_outlined,
              iconColor: AppColors.accent,
              title: 'Database Diagnostics',
              subtitle: 'Inspect local SQLite records and sync queue status',
              onTap: () async {
                final db = ref.read(appDatabaseProvider);
                final stats = await TestDataHydrator.getDiagnostics(db);
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Database Diagnostics'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Active Medications: ${stats['active_medications']}'),
                          const SizedBox(height: 6),
                          Text('Today Doses: ${stats['today_doses']}'),
                          const SizedBox(height: 6),
                          Text('Total Dose Logs: ${stats['total_doses']}'),
                          const SizedBox(height: 6),
                          Text('Unsynced CDC Events: ${stats['unsynced_cdc_events']}'),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
            const Divider(),
          ],
          // Logout
          _SettingsTile(
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'Sign out of your account',
            titleColor: AppColors.error,
            iconColor: AppColors.error,
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await ref.read(authStateProvider.notifier).logout();
                        if (context.mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/login',
                            (route) => false,
                          );
                        }
                      },
                      child: const Text(
                        'Logout',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? titleColor;
  final Color? iconColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.titleColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: titleColor != null
            ? TextStyle(color: titleColor)
            : null,
      ),
      subtitle: Text(subtitle),
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: trailing != null ? null : onTap,
    );
  }
}
