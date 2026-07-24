import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/modules/settings/blocked_users/blocked_users_controller.dart';
import 'package:simple_live_app/services/blocked_users_service.dart';

class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({Key? key}) : super(key: key);

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  final controller = Get.put(BlockedUsersController());
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    BlockedUsersService.instance.reload();
    controller.settingsController.blockedUsers.value = Map.fromEntries(
      BlockedUsersService.instance.entries.map((e) => MapEntry(e.key, e)),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("拉黑管理"),
      ),
      body: Column(
        children: [
          Padding(
            padding: AppStyle.edgeInsetsA12,
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: "搜索用户名/主播名",
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: AppStyle.edgeInsetsA12,
              ),
              onChanged: controller.search,
            ),
          ),
          Expanded(
            child: Obx(() {
              final entries = controller.paginatedEntries;
              if (entries.isEmpty) {
                return Center(
                  child: Text(
                    controller.searchQuery.value.isEmpty
                        ? "暂无拉黑的用户"
                        : "没有匹配的结果",
                    style: Get.textTheme.bodyLarge,
                  ),
                );
              }
              return ListView.separated(
                padding: AppStyle.edgeInsetsA12.copyWith(top: 0),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return Padding(
                    padding: AppStyle.edgeInsetsH12,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("${entry.userName}  [${entry.platform}]  ${entry.anchorName}"),
                              if (entry.message.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 12, top: 2),
                                  child: Text(
                                    entry.message,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => controller.unblock(entry.platform, entry.userName),
                          child: const Text("移除"),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
          Obx(() {
            final total = controller.totalPages;
            final current = controller.currentPage.value;
            if (controller.filteredEntries.isEmpty) return const SizedBox.shrink();
            return Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: current > 1 ? controller.prevPage : null,
                    child: const Text("上一页"),
                  ),
                  Padding(
                    padding: AppStyle.edgeInsetsH12,
                    child: Text(
                      "第 $current / $total 页",
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  TextButton(
                    onPressed: current < total ? controller.nextPage : null,
                    child: const Text("下一页"),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
