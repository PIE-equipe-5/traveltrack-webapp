import 'package:flutter/foundation.dart';

import '../models/quest.dart';
import 'supabase_client.dart';

class QuestService {
  static final ValueNotifier<int> _revision = ValueNotifier(0);
  static ValueListenable<int> get changes => _revision;

  static void _requireSession() {
    if (supabase.auth.currentSession == null) {
      throw StateError('Connectez-vous pour accéder aux quêtes.');
    }
  }

  static Future<List<Quest>> fetchQuests() async {
    _requireSession();
    final rows = await supabase.from('quests').select();
    return rows.map(Quest.fromJson).toList();
  }

  static Future<Quest> fetchQuest(String id) async {
    _requireSession();
    final row = await supabase
        .from('quests')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw StateError('Cette quête est introuvable ou inaccessible.');
    }
    return Quest.fromJson(row);
  }

  static Future<void> createQuest(NewQuest quest) async {
    _requireSession();
    if (supabase.auth.currentUser?.appMetadata['role'] != 'admin') {
      throw StateError(
        'La création de quêtes est réservée aux administrateurs.',
      );
    }
    await supabase.from('quests').insert(quest.toJson());
    _revision.value++;
  }
}
