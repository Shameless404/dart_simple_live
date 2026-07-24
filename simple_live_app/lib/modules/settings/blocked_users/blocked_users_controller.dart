import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/services/blocked_users_service.dart';

class BlockedUsersController extends BaseController {
  final AppSettingsController settingsController = Get.find<AppSettingsController>();

  final searchQuery = ''.obs;
  final currentPage = 1.obs;
  static const pageSize = 20;

  List<BlockedUserEntry> get _allEntries {
    final list = settingsController.blockedUsers.values.toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  List<BlockedUserEntry> get filteredEntries {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return _allEntries;
    return _allEntries.where((e) =>
      e.userName.toLowerCase().contains(query) ||
      e.anchorName.toLowerCase().contains(query)
    ).toList();
  }

  int get totalPages {
    final count = filteredEntries.length;
    if (count == 0) return 1;
    return (count - 1) ~/ pageSize + 1;
  }

  List<BlockedUserEntry> get paginatedEntries {
    final all = filteredEntries;
    final start = (currentPage.value - 1) * pageSize;
    if (start >= all.length) return [];
    return all.skip(start).take(pageSize).toList();
  }

  void search(String query) {
    searchQuery.value = query;
    currentPage.value = 1;
  }

  void nextPage() {
    if (currentPage.value < totalPages) currentPage.value++;
  }

  void prevPage() {
    if (currentPage.value > 1) currentPage.value--;
  }

  void unblock(String platform, String userName) {
    settingsController.unblockUser(platform, userName);
    final maxPage = totalPages;
    if (currentPage.value > maxPage) currentPage.value = maxPage;
  }
}
