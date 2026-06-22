import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_role.dart';
import '../../../data/services/role_service.dart';

/// Admin-only screen to search users and change roles
/// (promote moderators, demote artists, etc.).
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchController = TextEditingController();
  Future<List<Map<String, dynamic>>>? _searchFuture;

  // Default landing list: current moderators.
  Future<List<Map<String, dynamic>>> _moderatorsFuture =
      RoleService.listProfilesByRole(UserRole.moderator);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _runSearch() {
    final q = _searchController.text.trim();
    setState(() {
      _searchFuture = q.isEmpty ? null : RoleService.searchProfiles(q);
    });
  }

  Future<void> _changeRole(Map<String, dynamic> profile) async {
    final current = UserRole.fromString(profile['role'] as String?);
    final newRole = await showDialog<UserRole>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(
            'Роль для ${profile['username'] ?? profile['email'] ?? 'пользователя'}'),
        children: UserRole.values
            .map((r) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, r),
                  child: Row(
                    children: [
                      Icon(
                        r == current
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(r.label),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
    if (newRole == null || newRole == current) return;
    try {
      await RoleService.setUserRole(profile['id'] as String, newRole);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Назначено: ${newRole.label}')),
      );
      setState(() {
        _moderatorsFuture =
            RoleService.listProfilesByRole(UserRole.moderator);
        _runSearch();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ошибка: $e'), backgroundColor: AppTheme.errorColor));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Управление ролями',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Поиск по username или email',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _runSearch(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _runSearch, child: const Text('Найти')),
          ],
        ),
        const SizedBox(height: 24),
        if (_searchFuture != null) ...[
          const Text('Результаты поиска',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _ProfileList(future: _searchFuture!, onTap: _changeRole),
          const SizedBox(height: 24),
        ],
        const Text('Текущие модераторы',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _ProfileList(future: _moderatorsFuture, onTap: _changeRole),
      ],
    );
  }
}

class _ProfileList extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> future;
  final ValueChanged<Map<String, dynamic>> onTap;
  const _ProfileList({required this.future, required this.onTap});

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.purple;
      case UserRole.moderator:
        return Colors.blue;
      case UserRole.artist:
        return Colors.green;
      case UserRole.user:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Text('Ошибка: ${snap.error}');
        }
        final profiles = snap.data ?? const [];
        if (profiles.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Никого не найдено'),
          );
        }
        return Column(
          children: profiles.map((p) {
            final role = UserRole.fromString(p['role'] as String?);
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _roleColor(role),
                  child: Text(
                    ((p['username'] as String?)?.isNotEmpty == true
                            ? p['username'] as String
                            : (p['email'] as String? ?? '?'))[0]
                        .toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(p['username'] ?? p['email'] ?? '—'),
                subtitle: Text(p['email'] ?? ''),
                trailing: Chip(
                  label: Text(role.label),
                  backgroundColor: _roleColor(role).withOpacity(0.15),
                ),
                onTap: () => onTap(p),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
