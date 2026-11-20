import '../models/quest.dart';
import 'supabase_client.dart';

class QuestService {
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
}
