import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traveltrack/src/constants/app_colors.dart';
import 'package:traveltrack/src/viewmodels/analytics_consent_viewmodel.dart';
import 'package:traveltrack/src/viewmodels/auth_viewmodel.dart';
import 'package:traveltrack/src/widgets/analytics_consent_tile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.auth});

  final AuthViewModel? auth;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final Stream<User?> _userChanges;
  late final AuthViewModel _auth;
  bool _isSigningOut = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _auth = widget.auth ?? authViewModel;
    _userChanges = _auth.authStateChanges.map((state) => state.session?.user);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      await _auth.signOut();
    } catch (error, stackTrace) {
      debugPrint('Impossible de se déconnecter : $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de se déconnecter. Réessaie.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
            onPressed: _isSigningOut ? null : _signOut,
          ),
        ],
      ),
      body: StreamBuilder<User?>(
        stream: _userChanges,
        initialData: _auth.currentUser,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Impossible de charger le profil du compte.'),
            );
          }
          final user = snapshot.data;
          if (user == null) {
            return const Center(child: Text('Aucun compte connecté.'));
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _ProfileHeader(user: user)),
              const SliverToBoxAdapter(child: _StatsSection()),
              const SliverToBoxAdapter(
                child: _UnavailableSection(title: 'Progression par pays'),
              ),
              const SliverToBoxAdapter(
                child: _UnavailableSection(title: 'Mes badges'),
              ),
              if (analyticsConsentViewModel.isAnalyticsAvailable)
                const SliverToBoxAdapter(child: AnalyticsConsentTile()),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(tabController: _tabController),
              ),
              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    _UnavailableTab(
                      icon: Icons.explore_outlined,
                      message:
                          'Les quêtes de ton profil ne sont pas encore disponibles.',
                    ),
                    _UnavailableTab(
                      icon: Icons.photo_library_outlined,
                      message:
                          'Les photos de ton profil ne sont pas encore disponibles.',
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final User user;

  String? _metadataString(String key) {
    final value = user.userMetadata?[key];
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  @override
  Widget build(BuildContext context) {
    final firstName = _metadataString('first_name');
    final lastName = _metadataString('last_name');
    final registeredName = [firstName, lastName].whereType<String>().join(' ');
    final name = registeredName.isNotEmpty
        ? registeredName
        : _metadataString('full_name') ??
              _metadataString('name') ??
              'Mon profil';
    final email = user.email?.trim();
    final avatar = _metadataString('avatar_url') ?? _metadataString('picture');
    final avatarUri = avatar == null ? null : Uri.tryParse(avatar);
    final hasAvatar =
        avatarUri != null &&
        (avatarUri.scheme == 'https' || avatarUri.scheme == 'http') &&
        avatarUri.host.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.orange.withValues(alpha: 0.1),
            child: ClipOval(
              child: hasAvatar && avatar != null
                  ? Image.network(
                      avatar,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const _DefaultAvatar(),
                    )
                  : const _DefaultAvatar(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          if (email != null && email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              email,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }
}

class _DefaultAvatar extends StatelessWidget {
  const _DefaultAvatar();

  @override
  Widget build(BuildContext context) =>
      const Icon(Icons.person, size: 52, color: AppColors.orange);
}

class _StatsSection extends StatelessWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              _StatItem(label: 'Quêtes'),
              _StatItem(label: 'Pays'),
              _StatItem(label: 'Amis'),
              _StatItem(label: 'Followers'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Statistiques non disponibles',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          '—',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.orange,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}

class _UnavailableSection extends StatelessWidget {
  const _UnavailableSection({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Données non disponibles pour le moment.',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate({required this.tabController});

  final TabController tabController;

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: TabBar(
        controller: tabController,
        labelColor: AppColors.orange,
        unselectedLabelColor: Colors.grey,
        indicatorColor: AppColors.orange,
        indicatorWeight: 3,
        tabs: const [
          Tab(text: 'Quêtes'),
          Tab(text: 'Photos'),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) =>
      tabController != oldDelegate.tabController;
}

class _UnavailableTab extends StatelessWidget {
  const _UnavailableTab({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
