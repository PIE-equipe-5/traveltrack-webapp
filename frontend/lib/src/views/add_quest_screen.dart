import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/quest.dart';
import '../services/quest_service.dart';

class AddQuestScreen extends StatefulWidget {
  const AddQuestScreen({super.key, this.createQuest});

  final Future<void> Function(NewQuest)? createQuest;

  @override
  State<AddQuestScreen> createState() => _AddQuestScreenState();
}

class _AddQuestScreenState extends State<AddQuestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _xp = TextEditingController(text: '0');
  final _imageUrl = TextEditingController();
  final _address = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _radius = TextEditingController(text: '100');
  QuestCategory _category = QuestCategory.histoire;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _title,
      _description,
      _xp,
      _imageUrl,
      _address,
      _latitude,
      _longitude,
      _radius,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? 'Ce champ est obligatoire.'
      : null;

  String? _coordinate(String? value, double min, double max) {
    final number = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
    if (number == null || !number.isFinite || number < min || number > max) {
      return 'Saisis un nombre entre $min et $max.';
    }
    return null;
  }

  String? _integer(String? value, {required int min}) {
    final number = int.tryParse((value ?? '').trim());
    if (number == null || number < min || number > 2147483647) {
      return 'Saisis un entier entre $min et 2147483647.';
    }
    return null;
  }

  String? _validateImageUrl(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      return 'Saisis une URL HTTP ou HTTPS valide.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    final description = _description.text.trim();
    final imageUrl = _imageUrl.text.trim();
    final quest = NewQuest(
      title: _title.text.trim(),
      category: _category,
      description: description.isEmpty ? null : description,
      xp: int.parse(_xp.text.trim()),
      imageUrl: imageUrl.isEmpty ? null : imageUrl,
      startAddress: _address.text.trim(),
      lat: double.parse(_latitude.text.trim().replaceAll(',', '.')),
      lng: double.parse(_longitude.text.trim().replaceAll(',', '.')),
      validationRadiusMeters: int.parse(_radius.text.trim()),
    );
    try {
      await (widget.createQuest ?? QuestService.createQuest)(quest);
    } catch (error, stackTrace) {
      debugPrint('Impossible de créer la quête : $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error =
              'Impossible d’ajouter la quête. Vérifie tes droits et réessaie.';
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => _isSaving = false);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Quête ajoutée avec succès.')));
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/quests');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Ajouter une quête')),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Titre *'),
                  validator: _required,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<QuestCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Catégorie *'),
                  items: QuestCategory.values
                      .where((category) => category != QuestCategory.all)
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category.label),
                        ),
                      )
                      .toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value != null) setState(() => _category = value);
                        },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(
                    labelText: 'Description (facultatif)',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _xp,
                  decoration: const InputDecoration(labelText: 'XP *'),
                  keyboardType: TextInputType.number,
                  validator: (value) => _integer(value, min: 0),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _imageUrl,
                  decoration: const InputDecoration(
                    labelText: 'URL de l’image (facultatif)',
                  ),
                  keyboardType: TextInputType.url,
                  validator: _validateImageUrl,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _address,
                  decoration: const InputDecoration(
                    labelText: 'Adresse de départ *',
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Les coordonnées servent à placer la quête sur la carte.',
                ),
                TextFormField(
                  controller: _latitude,
                  decoration: const InputDecoration(
                    labelText: 'Latitude *',
                    hintText: '48.8584',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: (value) => _coordinate(value, -90, 90),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _longitude,
                  decoration: const InputDecoration(
                    labelText: 'Longitude *',
                    hintText: '2.2945',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: (value) => _coordinate(value, -180, 180),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _radius,
                  decoration: const InputDecoration(
                    labelText: 'Rayon de validation en mètres *',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) => _integer(value, min: 1),
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: _isSaving ? null : _submit,
                  child: Text(
                    _isSaving ? 'Enregistrement...' : 'Ajouter la quête',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
