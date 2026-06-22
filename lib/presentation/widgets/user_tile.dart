import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/social_user_model.dart';
import '../providers/follow_provider.dart';
import '../providers/locale_provider.dart';
import '../screens/social/public_profile_screen.dart';

/// Re-usable tile representing a user (followers / following / search).
/// Includes an inline Follow / Following button bound to [FollowProvider].
class UserTile extends StatelessWidget {
  final SocialUser user;
  final bool showFollowButton;

  const UserTile({
    super.key,
    required this.user,
    this.showFollowButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final isSelf = myId != null && myId == user.id;

    return Consumer<FollowProvider>(
      builder: (context, follow, _) {
        final isFollowing = follow.isFollowing(user.id);
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: _Avatar(user: user),
          title: Text(
            user.username,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: user.email != null && user.email!.isNotEmpty
              ? Text(
                  user.email!,
                  style: const TextStyle(color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          trailing: (!showFollowButton || isSelf)
              ? null
              : _FollowButton(
                  isFollowing: isFollowing,
                  onPressed: () => _handleToggle(context, follow),
                ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PublicProfileScreen(user: user),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleToggle(
    BuildContext context,
    FollowProvider follow,
  ) async {
    try {
      await follow.toggle(user.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}

class _Avatar extends StatelessWidget {
  final SocialUser user;
  const _Avatar({required this.user});

  @override
  Widget build(BuildContext context) {
    final image = user.profileImage;
    return CircleAvatar(
      radius: 24,
      backgroundColor: Theme.of(context).colorScheme.primary,
      backgroundImage: image != null && image.isNotEmpty
          ? NetworkImage(image)
          : null,
      child: image == null || image.isEmpty
          ? Text(
              user.username.isNotEmpty
                  ? user.username[0].toUpperCase()
                  : 'U',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }
}

class _FollowButton extends StatelessWidget {
  final bool isFollowing;
  final VoidCallback onPressed;

  const _FollowButton({required this.isFollowing, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final color = Theme.of(context).colorScheme.primary;
    if (isFollowing) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color),
          foregroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(localeProvider.getString('following_button')),
      );
    }
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(localeProvider.getString('follow')),
    );
  }
}
