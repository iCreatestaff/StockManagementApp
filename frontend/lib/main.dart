import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/product_list_screen.dart';
import 'screens/user_management_screen.dart';
import 'screens/history_screen.dart';
import 'screens/stats_screen.dart';

void main() {
  runApp(const ProviderScope(child: StockManagementApp()));
}

class StockManagementApp extends ConsumerWidget {
  const StockManagementApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);

    return MaterialApp(
      title: 'Stock Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          elevation: 2,
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
      ),
      home: isLoggedIn ? const MainShell() : const LoginScreen(),
    );
  }
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final isAdmin = ref.watch(isAdminProvider);

    // Define pages based on role
    final pages = [
      const ProductListScreen(),
      if (isAdmin) const UserManagementScreen(),
      if (isAdmin) const HistoryScreen(),
      if (isAdmin) const StatsScreen(),
    ];

    // Define navigation items based on role
    final navItems = [
      const NavigationRailDestination(
        icon: Icon(Icons.inventory_2_outlined),
        selectedIcon: Icon(Icons.inventory_2),
        label: Text('Products'),
      ),
      if (isAdmin)
        const NavigationRailDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: Text('Users'),
        ),
      if (isAdmin)
        const NavigationRailDestination(
          icon: Icon(Icons.history),
          selectedIcon: Icon(Icons.history),
          label: Text('History'),
        ),
      if (isAdmin)
        const NavigationRailDestination(
          icon: Icon(Icons.insights),
          selectedIcon: Icon(Icons.insights),
          label: Text('Insights'),
        ),
    ];

    // Ensure selected index is valid when role changes
    if (_selectedIndex >= pages.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      body: Row(
        children: [
          // Sidebar navigation
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: navItems,
            backgroundColor: Colors.blue.shade800,
            selectedIconTheme: const IconThemeData(color: Colors.white),
            unselectedIconTheme: const IconThemeData(color: Colors.white70),
            selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  const Icon(Icons.inventory_2, size: 32, color: Colors.white),
                  const SizedBox(height: 4),
                  const Text(
                    'Stock',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            trailing: Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white24,
                          radius: 16,
                          child: Icon(
                            isAdmin ? Icons.admin_panel_settings : Icons.person,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentUser?.username ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 16),
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.white70),
                          onPressed: () {
                            ref.read(authTokenProvider.notifier).setToken(null);
                            ref.read(currentUserProvider.notifier).setUser(null);
                          },
                          tooltip: 'Logout',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Main content
          Expanded(
            child: pages[_selectedIndex],
          ),
        ],
      ),
    );
  }
}
