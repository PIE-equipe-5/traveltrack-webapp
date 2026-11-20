// lib/src/screens/quest_list_screen.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/quest.dart';
import '../services/quest_service.dart';
import '../viewmodels/map_location_viewmodel.dart';
import '../widgets/quest_card.dart';

class QuestListScreen extends StatefulWidget {
  const QuestListScreen({super.key});

  @override
  State<QuestListScreen> createState() => _QuestListScreenState();
}

class _QuestListScreenState extends State<QuestListScreen> {
  late QuestCategory _selectedCategory;
  late SortType _sortType;
  String _searchQuery = '';
  List<Quest> _quests = [];
  bool _isLoading = true;
  String? _error;
  final _locationViewModel = MapLocationViewModel();

  @override
  void initState() {
    super.initState();
    _selectedCategory = QuestCategory.all;
    _sortType = SortType.distance;
    _locationViewModel.addListener(_onLocationChanged);
    _locationViewModel.startTrackingIfAlreadyAllowed();
    _loadQuests();
  }

  @override
  void dispose() {
    _locationViewModel.removeListener(_onLocationChanged);
    _locationViewModel.dispose();
    super.dispose();
  }

  void _onLocationChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadQuests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final quests = await QuestService.fetchQuests();
      if (mounted) setState(() => _quests = quests);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Impossible de charger les quêtes : $error');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double? _distanceKm(Quest quest) {
    final location = _locationViewModel.currentLocation;
    if (location == null) return null;
    return Geolocator.distanceBetween(
          location.latitude,
          location.longitude,
          quest.lat,
          quest.lng,
        ) /
        1000;
  }

  @override
  Widget build(BuildContext context) {
    List<Quest> filtered = _getFilteredAndSortedQuests();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: TextField(
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            hintText: 'Rechercher un lieu, une quête...',
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Catégories scroll horizontal
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildCategoryChip(QuestCategory.all, 'Toutes'),
                      _buildCategoryChip(QuestCategory.histoire, 'Histoire'),
                      _buildCategoryChip(QuestCategory.gastro, 'Gastro'),
                      _buildCategoryChip(QuestCategory.social, 'Social'),
                      _buildCategoryChip(QuestCategory.sport, 'Sport'),
                      _buildCategoryChip(QuestCategory.nature, 'Nature'),
                      _buildCategoryChip(QuestCategory.culture, 'Culture'),
                      _buildCategoryChip(QuestCategory.art, 'Art'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Tri + Filtres
                Row(
                  children: [
                    _buildSortDropdown(),
                    const Spacer(),
                    _buildFiltersButton(),
                  ],
                ),
                if (_sortType == SortType.distance &&
                    _locationViewModel.currentLocation == null)
                  const Text(
                    'Activez la localisation sur la carte pour trier par distance.',
                  ),
              ],
            ),
          ),
          // Liste des quêtes
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        TextButton(
                          onPressed: _loadQuests,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  )
                : filtered.isEmpty
                ? Center(
                    child: Text(
                      'Aucune quête trouvée',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return QuestCard(
                        quest: filtered[index],
                        distanceKm: _distanceKm(filtered[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<Quest> _getFilteredAndSortedQuests() {
    List<Quest> quests = [..._quests];

    // Filtrer par catégorie
    if (_selectedCategory != QuestCategory.all) {
      quests = quests.where((q) => q.category == _selectedCategory).toList();
    }

    // Filtrer par recherche
    if (_searchQuery.isNotEmpty) {
      quests = quests
          .where(
            (q) =>
                q.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                q.startAddress.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
          )
          .toList();
    }

    // Trier
    if (_sortType == SortType.distance) {
      if (_locationViewModel.currentLocation != null) {
        quests.sort((a, b) => _distanceKm(a)!.compareTo(_distanceKm(b)!));
      }
    } else if (_sortType == SortType.xp) {
      quests.sort((a, b) => b.xp.compareTo(a.xp));
    } else if (_sortType == SortType.alphabetic) {
      quests.sort((a, b) => a.title.compareTo(b.title));
    }

    return quests;
  }

  Widget _buildCategoryChip(QuestCategory category, String label) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedCategory = category);
        },
        backgroundColor: Colors.white,
        selectedColor: Theme.of(context).colorScheme.primary,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: FontWeight.w500,
        ),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[300]!,
        ),
      ),
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<SortType>(
        value: _sortType,
        underline: const SizedBox(),
        items: [
          DropdownMenuItem(
            value: SortType.distance,
            child: const Text('↓ Distance'),
          ),
          DropdownMenuItem(value: SortType.xp, child: const Text('↓ XP')),
          DropdownMenuItem(
            value: SortType.alphabetic,
            child: const Text('↓ Alphabétique'),
          ),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() => _sortType = value);
          }
        },
      ),
    );
  }

  Widget _buildFiltersButton() {
    return IconButton(
      icon: const Icon(Icons.tune),
      onPressed: () {
        // TODO: Ouvrir bottom sheet de filtres avancés
      },
    );
  }
}

enum SortType { distance, xp, alphabetic }
