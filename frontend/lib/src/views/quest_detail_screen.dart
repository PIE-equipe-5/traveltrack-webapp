import 'package:flutter/material.dart';

import '../models/quest.dart';
import '../constants/app_colors.dart';
import '../services/quest_service.dart';
import '../widgets/quest_image.dart';

class QuestDetailScreen extends StatefulWidget {
  const QuestDetailScreen({super.key, required this.questId});

  final String questId;

  @override
  State<QuestDetailScreen> createState() => _QuestDetailScreenState();
}

class _QuestDetailScreenState extends State<QuestDetailScreen> {
  late Future<Quest> _quest;

  @override
  void initState() {
    super.initState();
    _quest = QuestService.fetchQuest(widget.questId);
  }

  @override
  void didUpdateWidget(QuestDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.questId != widget.questId) {
      _quest = QuestService.fetchQuest(widget.questId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Détail de la quête')),
      body: FutureBuilder<Quest>(
        future: _quest,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Impossible de charger la quête : ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: () => setState(
                      () => _quest = QuestService.fetchQuest(widget.questId),
                    ),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }
          final quest = snapshot.requireData;
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                QuestImage(
                  imageUrl: quest.imageUrl,
                  width: double.infinity,
                  height: 220,
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quest.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Chip(label: Text(quest.category.label)),
                      if (quest.description.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          quest.description,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(quest.startAddress)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 20,
                            color: AppColors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text('${quest.xp} XP'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
