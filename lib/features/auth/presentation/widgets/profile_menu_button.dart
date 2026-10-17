import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/notification_service.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/utils/formatters.dart';
import '../../../community/presentation/community_admin_screen.dart';
import '../../../home/presentation/app_alerts_listener.dart';
import '../providers/auth_providers.dart';

class ProfileMenuButton extends ConsumerWidget {
  const ProfileMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).valueOrNull;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopupMenuButton<String>(
      tooltip: 'Account',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onSelected: (value) async {
        switch (value) {
          case 'alerts':
            await enableAlertsFromTap(context, ref);
          case 'community':
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CommunityAdminScreen()));
          case 'theme':
            ref.read(themeModeProvider.notifier).state = isDark ? ThemeMode.light : ThemeMode.dark;
          case 'logout':
            await NotificationService.instance.unregister(ref.read(firestoreProvider));
            await ref.read(authRepositoryProvider).signOut();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user?.name ?? '—', style: Theme.of(context).textTheme.titleSmall),
              Text(user?.isAdmin == true ? 'Administrator' : (user?.isKuriMember == true ? 'Kuri member' : 'Community member'),
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const PopupMenuDivider(),
        if (user?.isAdmin == true)
          const PopupMenuItem<String>(
            value: 'community',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.manage_accounts_rounded),
              title: Text('Community & access'),
            ),
          ),
        if (kIsWeb)
          const PopupMenuItem<String>(
            value: 'alerts',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.notifications_active_rounded),
              title: Text('Enable alerts'),
            ),
          ),
        PopupMenuItem<String>(
          value: 'theme',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            title: Text(isDark ? 'Light mode' : 'Dark mode'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout_rounded),
            title: Text('Sign out'),
          ),
        ),
      ],
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.berryGradient,
          border: Border.all(color: AppColors.roseGoldLight, width: 1.5),
        ),
        child: Text(
          initialsOf(user?.name ?? '?'),
          style: const TextStyle(color: AppColors.roseGoldPale, fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }
}
