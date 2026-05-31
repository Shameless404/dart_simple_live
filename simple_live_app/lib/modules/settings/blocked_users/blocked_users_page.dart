import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/modules/settings/blocked_users/blocked_users_controller.dart';
import 'package:simple_live_app/services/blocked_users_service.dart';

class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({Key? key}) : super(key: key);

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  final controller = Get.put(BlockedUsersController());

  @override
  void initState() {
    super.initState();
    BlockedUsersService.instance.reload();
    controller.settingsController.blockedUsers.value = Map.fromEntries(
      BlockedUsersService.instance.entries.map((e) => MapEntry(e.key, e)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("拉黑管理"),
      ),
      body: Obx(
        () {
          final entries = controller.settingsController.blockedUsers.entries.toList();
          if (entries.isEmpty) {
            return Center(
              child: Text(
                "暂无拉黑的用户",
                style: Get.textTheme.bodyLarge,
              ),
            );
          }
          return ListView.separated(
            padding: AppStyle.edgeInsetsA12,
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final entry = entries[index].value;
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
        },
      ),
    );
  }
}
