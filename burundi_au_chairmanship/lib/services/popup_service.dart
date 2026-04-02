import 'package:shared_preferences/shared_preferences.dart';
import '../models/popup_model.dart';
import 'api_service.dart';

class PopupService {
  static final PopupService _instance = PopupService._internal();
  factory PopupService() => _instance;
  PopupService._internal();

  final ApiService _apiService = ApiService();
  static const String _seenPopupsKey = 'seen_popups';

  /// Fetch active popups from the server
  Future<List<PopupModel>> fetchActivePopups() async {
    try {
      final data = await _apiService.getActivePopups();
      return data.map((json) => PopupModel.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get list of popup IDs that user has already seen
  Future<Set<int>> getSeenPopupIds() async {
    final prefs = await SharedPreferences.getInstance();
    final seenList = prefs.getStringList(_seenPopupsKey) ?? [];
    return seenList.map((id) => int.tryParse(id) ?? 0).toSet();
  }

  /// Mark a popup as seen
  Future<void> markPopupAsSeen(int popupId) async {
    final prefs = await SharedPreferences.getInstance();
    final seenList = prefs.getStringList(_seenPopupsKey) ?? [];
    if (!seenList.contains(popupId.toString())) {
      seenList.add(popupId.toString());
      await prefs.setStringList(_seenPopupsKey, seenList);
    }
  }

  /// Get popups that should be shown (not seen yet, or show_once=false)
  Future<List<PopupModel>> getPopupsToShow() async {
    final allPopups = await fetchActivePopups();
    final seenIds = await getSeenPopupIds();

    return allPopups.where((popup) {
      if (!popup.showOnce) {
        // If show_once is false, always show it
        return true;
      }
      // If show_once is true, only show if not seen
      return !seenIds.contains(popup.id);
    }).toList();
  }

  /// Clear all seen popups (for testing or reset)
  Future<void> clearSeenPopups() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_seenPopupsKey);
  }
}
