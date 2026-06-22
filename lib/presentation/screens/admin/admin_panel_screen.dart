import 'package:flutter/material.dart';

import 'admin_dashboard_screen.dart';
import 'admin_users_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  int _selectedIndex = 0;

  static const _screens = [
    AdminDashboardScreen(),
    AdminUsersScreen(),
  ];

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Дашборд',
    ),
    NavigationDestination(
      icon: Icon(Icons.manage_accounts_outlined),
      selectedIcon: Icon(Icons.manage_accounts),
      label: 'Роли',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      appBar: AppBar(title: const Text('Админ-панель'), centerTitle: false),
      body: isWide ? _buildWideLayout(context) : _screens[_selectedIndex],
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
              },
              destinations: _destinations,
            ),
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return Row(
      children: [
        NavigationRail(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          extended: MediaQuery.of(context).size.width > 960,
          leading: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Icon(
              Icons.admin_panel_settings,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: Text('Дашборд'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.manage_accounts_outlined),
              selectedIcon: Icon(Icons.manage_accounts),
              label: Text('Роли'),
            ),
          ],
        ),
        const VerticalDivider(thickness: 1, width: 1),
        Expanded(child: _screens[_selectedIndex]),
      ],
    );
  }
}
