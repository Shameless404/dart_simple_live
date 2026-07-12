import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/services/mini_player_manager.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/modules/live_room/player/player_controls.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/mini_player_launcher.dart';
import 'package:simple_live_app/services/blocked_users_service.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/widgets/desktop_refresh_button.dart';
import 'package:simple_live_app/widgets/filter_button.dart';
import 'package:simple_live_app/widgets/follow_user_item.dart';
import 'package:simple_live_app/widgets/keep_alive_wrapper.dart';
import 'package:simple_live_app/widgets/net_image.dart';
import 'package:simple_live_app/widgets/settings/settings_action.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';
import 'package:simple_live_app/widgets/settings/settings_number.dart';
import 'package:simple_live_app/widgets/settings/settings_switch.dart';
import 'package:simple_live_app/widgets/superchat_card.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/modules/follow_user/follow_user_page.dart';
import 'package:simple_live_app/windows/mini_player_window.dart';
import 'package:simple_live_core/simple_live_core.dart';

class LiveRoomPage extends GetView<LiveRoomController> {
  const LiveRoomPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final page = Obx(
      () {
        if (controller.loadError.value) {
          return Scaffold(
            appBar: AppBar(
              title: const Text("直播间加载失败"),
            ),
            body: Padding(
              padding: AppStyle.edgeInsetsA12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LottieBuilder.asset(
                    'assets/lotties/error.json',
                    height: 140,
                    repeat: false,
                  ),
                  const Text(
                    "直播间加载失败",
                    textAlign: TextAlign.center,
                  ),
                  AppStyle.vGap4,
                  Text(
                    controller.error?.toString() ?? "未知错误",
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  AppStyle.vGap4,
                  Text(
                    "${controller.rxSite.value.id} - ${controller.rxRoomId.value}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: controller.copyErrorDetail,
                        icon: const Icon(Remix.file_copy_line),
                        label: const Text("复制信息"),
                      ),
                      TextButton.icon(
                        onPressed: controller.refreshRoom,
                        icon: const Icon(Remix.refresh_line),
                        label: const Text("刷新"),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        }
        if (controller.fullScreenState.value) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (e, r) {
              controller.exitFull();
            },
            child: Scaffold(
              body: buildMediaPlayer(),
            ),
          );
        } else {
          return buildPageUI();
        }
      },
    );
    if (!Platform.isAndroid) {
      return page;
    }
    return PiPSwitcher(
      floating: controller.pip,
      childWhenDisabled: page,
      childWhenEnabled: buildMediaPlayer(),
    );
  }

  Widget buildPageUI() {
    return OrientationBuilder(
      builder: (context, orientation) {
        return Scaffold(
          appBar: AppBar(
            title: Obx(
              () => Text(controller.detail.value?.title ?? "直播间"),
            ),
            actions: buildAppbarActions(context),
          ),
          body: orientation == Orientation.portrait
              ? buildPhoneUI(context)
              : buildTabletUI(context),
        );
      },
    );
  }

  Widget buildPhoneUI(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: buildMediaPlayer(),
        ),
        buildUserProfile(context),
        buildMessageArea(),
        buildBottomActions(context),
      ],
    );
  }

  Widget buildTabletUI(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: buildMediaPlayer(),
              ),
              SizedBox(
                width: 300,
                child: Column(
                  children: [
                    buildUserProfile(context),
                    buildMessageArea(),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              top: BorderSide(
                color: Colors.grey.withAlpha(25),
              ),
            ),
          ),
          padding: AppStyle.edgeInsetsV4.copyWith(
            bottom: AppStyle.bottomBarHeight + 4,
          ),
          child: Row(
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 14),
                ),
                onPressed: controller.refreshRoom,
                icon: const Icon(Remix.refresh_line),
                label: const Text("刷新"),
              ),
              AppStyle.hGap4,
              Obx(
                () => controller.followed.value
                    ? TextButton.icon(
                        style: TextButton.styleFrom(
                          textStyle: const TextStyle(fontSize: 14),
                        ),
                        onPressed: controller.removeFollowUser,
                        icon: const Icon(Remix.heart_fill),
                        label: const Text("取消关注"),
                      )
                    : TextButton.icon(
                        style: TextButton.styleFrom(
                          textStyle: const TextStyle(fontSize: 14),
                        ),
                        onPressed: controller.followUser,
                        icon: const Icon(Remix.heart_line),
                        label: const Text("关注"),
                      ),
              ),
              const Expanded(child: Center()),
              TextButton.icon(
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 14),
                ),
                onPressed: controller.share,
                icon: const Icon(Remix.share_line),
                label: const Text("分享"),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 14),
                ),
                onPressed: controller.copyUrl,
                icon: const Icon(Remix.file_copy_line),
                label: const Text("复制链接"),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 14),
                ),
                onPressed: controller.copyPlayUrl,
                icon: const Icon(Remix.file_copy_line),
                label: const Text("复制播放直链"),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildMediaPlayer() {
    var boxFit = BoxFit.contain;
    double? aspectRatio;
    if (AppSettingsController.instance.scaleMode.value == 0) {
      boxFit = BoxFit.contain;
    } else if (AppSettingsController.instance.scaleMode.value == 1) {
      boxFit = BoxFit.fill;
    } else if (AppSettingsController.instance.scaleMode.value == 2) {
      boxFit = BoxFit.cover;
    } else if (AppSettingsController.instance.scaleMode.value == 3) {
      boxFit = BoxFit.contain;
      aspectRatio = 16 / 9;
    } else if (AppSettingsController.instance.scaleMode.value == 4) {
      boxFit = BoxFit.contain;
      aspectRatio = 4 / 3;
    }
    return Stack(
      children: [
        Video(
          key: controller.globalPlayerKey,
          controller: controller.videoController,
          pauseUponEnteringBackgroundMode:
              AppSettingsController.instance.playerAutoPause.value,
          resumeUponEnteringForegroundMode:
              AppSettingsController.instance.playerAutoPause.value,
          controls: (state) {
            return playerControls(state, controller);
          },
          aspectRatio: aspectRatio,
          fit: boxFit,
          // 自己实现
          wakelock: false,
        ),
        Obx(
          () {
            if (!controller.liveStatus.value) {
              return const Center(
                child: Text(
                  "未开播",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget buildUserProfile(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: Colors.grey.withAlpha(25),
          ),
          bottom: BorderSide(
            color: Colors.grey.withAlpha(25),
          ),
        ),
      ),
      padding: AppStyle.edgeInsetsA8.copyWith(
        left: 12,
        right: 12,
      ),
      child: Obx(
        () => Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withAlpha(50)),
                borderRadius: AppStyle.radius24,
              ),
              child: NetImage(
                controller.detail.value?.userAvatar ?? "",
                width: 48,
                height: 48,
                borderRadius: 24,
              ),
            ),
            AppStyle.hGap12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.detail.value?.userName ?? "",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  AppStyle.vGap4,
                  Row(
                    children: [
                      Image.asset(
                        controller.site.logo,
                        width: 20,
                      ),
                      AppStyle.hGap4,
                      Text(
                        controller.site.name,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            AppStyle.hGap12,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Remix.fire_fill,
                  size: 20,
                  color: Colors.orange,
                ),
                AppStyle.hGap4,
                Text(
                  Utils.onlineToString(
                    controller.detail.value?.online ?? 0,
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBottomActions(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: Colors.grey.withAlpha(25),
          ),
        ),
      ),
      padding: EdgeInsets.only(bottom: AppStyle.bottomBarHeight),
      child: Row(
        children: [
          Expanded(
            child: Obx(
              () => controller.followed.value
                  ? TextButton.icon(
                      style: TextButton.styleFrom(
                        textStyle: const TextStyle(fontSize: 14),
                      ),
                      onPressed: controller.removeFollowUser,
                      icon: const Icon(Remix.heart_fill),
                      label: const Text("取消关注"),
                    )
                  : TextButton.icon(
                      style: TextButton.styleFrom(
                        textStyle: const TextStyle(fontSize: 14),
                      ),
                      onPressed: controller.followUser,
                      icon: const Icon(Remix.heart_line),
                      label: const Text("关注"),
                    ),
            ),
          ),
          Expanded(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                textStyle: const TextStyle(fontSize: 14),
              ),
              onPressed: controller.refreshRoom,
              icon: const Icon(Remix.refresh_line),
              label: const Text("刷新"),
            ),
          ),
          Expanded(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                textStyle: const TextStyle(fontSize: 14),
              ),
              onPressed: controller.share,
              icon: const Icon(Remix.share_line),
              label: const Text("分享"),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMessageArea() {
    final isBili = controller.site.id == Constant.kBiliBili;
    final tabCount = isBili ? 4 : 3;
    return Expanded(
      child: DefaultTabController(
        length: tabCount,
        child: Column(
          children: [
            TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              labelPadding: EdgeInsets.zero,
              indicatorWeight: 1.0,
              tabs: [
                const Tab(text: "聊天"),
                if (isBili)
                  Tab(
                    child: Obx(
                      () => Text(
                        controller.superChats.isNotEmpty
                            ? "SC(${controller.superChats.length})"
                            : "SC",
                      ),
                    ),
                  ),
                const Tab(text: "关注"),
                const Tab(text: "设置"),
              ],
            ),
            Expanded(
              child: _TabContent(
                tabs: [
                  _ChatTab(
                    key: ValueKey(
                      'chat_${controller.site.id}_${controller.roomId}',
                    ),
                    stream: controller.chatMessageStream.stream,
                    statusNotifier: controller.chatStatusNotifier,
                    buildItem: buildMessageItem,
                  ),
                  if (isBili) buildSuperChats(),
                  buildFollowList(),
                  buildSettings(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildMessageItem(LiveMessage message, BuildContext context) {
    if (message.userName == "LiveSysMessage") {
      return Obx(
        () => Text(
          message.message,
          style: TextStyle(
            color: Colors.grey,
            fontSize: AppSettingsController.instance.chatTextSize.value,
          ),
        ),
      );
    }

    return GestureDetector(
      onSecondaryTapDown: (details) {
        showMenu(
          context: context,
          position: RelativeRect.fromLTRB(
            details.globalPosition.dx, details.globalPosition.dy,
            details.globalPosition.dx, details.globalPosition.dy,
          ),
          items: [
            buildBlockUserMenuItem(message.userName, () {
              BlockedUsersService.instance.block(
                controller.site.id,
                message.userName,
                message.message,
                anchorName: controller.detail.value?.userName ?? '',
              );
              showBlockUserToast(context, message.userName);
            }),
          ],
        );
      },
      child: Obx(
        () => AppSettingsController.instance.chatBubbleStyle.value
            ? Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.withAlpha(25),
                      //borderRadius: AppStyle.radius8,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    padding:
                        AppStyle.edgeInsetsA4.copyWith(left: 12, right: 12),
                    child: Text.rich(
                      TextSpan(
                        text: "${message.userName}：",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize:
                              AppSettingsController.instance.chatTextSize.value,
                        ),
                        children: [
                          TextSpan(
                            text: message.message,
                            style: TextStyle(
                              color: Get.isDarkMode
                                  ? Colors.white
                                  : AppColors.black333,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Text.rich(
              TextSpan(
                text: "${message.userName}：",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: AppSettingsController.instance.chatTextSize.value,
                ),
                children: [
                  TextSpan(
                    text: message.message,
                    style: TextStyle(
                      color: Get.isDarkMode ? Colors.white : AppColors.black333,
                    ),
                  )
                ],
              ),
            ),
          ),
    );
  }

  Widget buildSuperChats() {
    return KeepAliveWrapper(
      child: Obx(
        () => ListView.separated(
          padding: AppStyle.edgeInsetsA12,
          itemCount: controller.superChats.length,
          separatorBuilder: (_, i) => AppStyle.vGap12,
          itemBuilder: (_, i) {
            var item = controller.superChats[i];
            return SuperChatCard(
              item,
              onExpire: () {
                controller.removeSuperChats();
              },
            );
          },
        ),
      ),
    );
  }

  Widget buildSettings() {
    return ListView(
      padding: AppStyle.edgeInsetsA12,
      children: [
        Obx(
          () => Visibility(
            visible: controller.autoExitEnable.value,
            child: ListTile(
              leading: const Icon(Icons.timer_outlined),
              visualDensity: VisualDensity.compact,
              title: Text("${parseDuration(controller.countdown.value)}后自动关闭"),
            ),
          ),
        ),
        Padding(
          padding: AppStyle.edgeInsetsA12,
          child: Text(
            "聊天区",
            style: Get.textTheme.titleSmall,
          ),
        ),
        SettingsCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(
                () => SettingsNumber(
                  title: "文字大小",
                  value:
                      AppSettingsController.instance.chatTextSize.value.toInt(),
                  min: 8,
                  max: 36,
                  onChanged: (e) {
                    AppSettingsController.instance
                        .setChatTextSize(e.toDouble());
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsNumber(
                  title: "上下间隔",
                  value:
                      AppSettingsController.instance.chatTextGap.value.toInt(),
                  min: 0,
                  max: 12,
                  onChanged: (e) {
                    AppSettingsController.instance.setChatTextGap(e.toDouble());
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsSwitch(
                  title: "气泡样式",
                  value: AppSettingsController.instance.chatBubbleStyle.value,
                  onChanged: (e) {
                    AppSettingsController.instance.setChatBubbleStyle(e);
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsSwitch(
                  title: "播放器中显示SC",
                  value:
                      AppSettingsController.instance.playershowSuperChat.value,
                  onChanged: (e) {
                    AppSettingsController.instance.setPlayerShowSuperChat(e);
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: AppStyle.edgeInsetsA12,
          child: Text(
            "更多设置",
            style: Get.textTheme.titleSmall,
          ),
        ),
        SettingsCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SettingsAction(
                title: "关键词屏蔽",
                onTap: controller.showDanmuShield,
              ),
              AppStyle.divider,
              SettingsAction(
                title: "弹幕设置",
                onTap: controller.showDanmuSettingsSheet,
              ),
              AppStyle.divider,
              SettingsAction(
                title: "定时关闭",
                onTap: controller.showAutoExitSheet,
              ),
              AppStyle.divider,
              SettingsAction(
                title: "画面尺寸",
                onTap: controller.showPlayerSettingsSheet,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildFollowList() {
    return _FollowListWithSearch(
      controller: controller,
      onRightClick: (item) => _openMiniWindow(item, skipConfirm: true),
    );
  }

  List<Widget> buildAppbarActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () {
          showMore();
        },
        icon: const Icon(Icons.more_horiz),
      ),
    ];
  }

  void showMore() {
    showModalBottomSheet(
      context: Get.context!,
      constraints: const BoxConstraints(
        maxWidth: 600,
      ),
      isScrollControlled: true,
      builder: (_) => Container(
        padding: EdgeInsets.only(
          bottom: AppStyle.bottomBarHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text("刷新"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                controller.refreshRoom();
              },
            ),
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              trailing: const Icon(Icons.chevron_right),
              title: const Text("切换清晰度"),
              onTap: () {
                Get.back();
                controller.showQualitySheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.switch_video_outlined),
              title: const Text("切换线路"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.showPlayUrlsSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.aspect_ratio_outlined),
              title: const Text("画面尺寸"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.showPlayerSettingsSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text("截图"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                controller.saveScreenshot();
              },
            ),
            if (Platform.isAndroid)
              ListTile(
                leading: const Icon(Icons.picture_in_picture),
                title: const Text("小窗播放"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Get.back();
                  controller.enablePIP();
                },
              ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text("定时关闭"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.showAutoExitSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_sharp),
              title: const Text("分享直播间"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.share();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text("复制链接"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.copyUrl();
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text("APP中打开"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.openNaviteAPP();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text("播放信息"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.showDebugInfo();
              },
            ),
          ],
        ),
      ),
    );
  }

  String parseDuration(int sec) {
    // 转为时分秒
    var h = sec ~/ 3600;
    var m = (sec % 3600) ~/ 60;
    var s = sec % 60;
    if (h > 0) {
      return "${h.toString().padLeft(2, '0')}小时${m.toString().padLeft(2, '0')}分钟${s.toString().padLeft(2, '0')}秒";
    }
    if (m > 0) {
      return "${m.toString().padLeft(2, '0')}分钟${s.toString().padLeft(2, '0')}秒";
    }
    return "${s.toString().padLeft(2, '0')}秒";
  }

  void _openMiniWindow(FollowUser item, {bool skipConfirm = false}) async {
    await openMiniWindow(item, cascadeIndex: MiniPlayerManager.instance.nextIndex(), skipConfirm: skipConfirm);
  }
}

class _FollowListWithSearch extends StatefulWidget {
  final LiveRoomController controller;
  final void Function(FollowUser item) onRightClick;

  const _FollowListWithSearch({
    required this.controller,
    required this.onRightClick,
  });

  @override
  State<_FollowListWithSearch> createState() => _FollowListWithSearchState();
}

class _FollowListWithSearchState extends State<_FollowListWithSearch> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _selectedTagId;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeepAliveWrapper(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: "搜索主播...",
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Obx(
            () {
              final tags = FollowService.instance.followTagList;
              if (tags.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 32,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: tags.length,
                  itemBuilder: (_, i) {
                    final tag = tags[i];
                    final selected = _selectedTagId == tag.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterButton(
                        text: tag.tag,
                        selected: selected,
                        onTap: () {
                          setState(() {
                            _selectedTagId = selected ? null : tag.id;
                          });
                        },
                      ),
                    );
                  },
                ),
              );
            },
          ),
          Expanded(
            child: Obx(
              () {
                final allUsers = _query.isEmpty
                    ? FollowService.instance.followList
                    : FollowService.instance.followList
                        .where((u) => u.userName
                            .toLowerCase()
                            .contains(_query.toLowerCase()))
                        .toList()
                        .obs;
                FollowUserTag? selectedTag;
                if (_selectedTagId != null) {
                  try {
                    selectedTag = FollowService
                        .instance.followTagList
                        .firstWhere((t) => t.id == _selectedTagId);
                  } catch (_) {}
                }
                final list = _query.isNotEmpty
                    ? allUsers.toList()
                    : selectedTag == null
                        ? allUsers.toList()
                        : allUsers
                            .where((u) => selectedTag!.userId.contains(u.id))
                            .toList();
                return Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: FollowService.instance.loadData,
                      child: ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          var item = list[i];
                          return Obx(
                            () => FollowUserItem(
                              item: item,
                              playing: widget.controller.rxSite.value.id ==
                                      item.siteId &&
                                  widget.controller.rxRoomId.value ==
                                      item.roomId,
                              onTap: () {
                                widget.controller.resetRoom(
                                  Sites.allSites[item.siteId]!,
                                  item.roomId,
                                );
                              },
                              onLongPress: () => showFollowTagDialog(item),
                              onRightClick: () => widget.onRightClick(item),
                            ),
                          );
                        },
                      ),
                    ),
                    if (Platform.isLinux ||
                        Platform.isWindows ||
                        Platform.isMacOS)
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Obx(
                          () => DesktopRefreshButton(
                            refreshing: FollowService.instance.updating.value,
                            onPressed: FollowService.instance.loadData,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Tab 内容切换器（IndexedStack 常驻所有 tab）
class _TabContent extends StatefulWidget {
  final List<Widget> tabs;
  const _TabContent({required this.tabs});

  @override
  State<_TabContent> createState() => _TabContentState();
}

class _TabContentState extends State<_TabContent> {
  TabController? _tc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tc = DefaultTabController.of(context);
    if (tc != _tc) {
      _tc?.removeListener(_onChanged);
      _tc = tc;
      _tc?.addListener(_onChanged);
    }
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _tc?.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(index: _tc?.index ?? 0, children: widget.tabs);
  }
}

/// 聊天 tab：消息列表 + 流订阅 + 系统消息横幅（常驻，永不自动清理）
class _ChatTab extends StatefulWidget {
  final Stream<LiveMessage> stream;
  final ValueNotifier<String?> statusNotifier;
  final Widget Function(LiveMessage message, BuildContext context) buildItem;

  const _ChatTab({
    super.key,
    required this.stream,
    required this.statusNotifier,
    required this.buildItem,
  });

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  final List<LiveMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _disableAutoScroll = false;
  double _lastScrollPos = 0;
  StreamSubscription<LiveMessage>? _subscription;
  VoidCallback? _statusListener;
  String? _statusMsg;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _subscription = widget.stream.listen(_onMessage);
    _statusMsg = widget.statusNotifier.value;
    _statusListener = () {
      if (mounted) setState(() => _statusMsg = widget.statusNotifier.value);
      _statusTimer?.cancel();
      _statusTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _statusMsg = null);
      });
    };
    widget.statusNotifier.addListener(_statusListener!);
  }

  void _onScroll() {
    final pos = _scrollController.position.pixels;
    final maxPos = _scrollController.position.maxScrollExtent;
    if (pos >= maxPos - 1) {
      _disableAutoScroll = false;
    } else if (pos < _lastScrollPos) {
      _disableAutoScroll = true;
    }
    _lastScrollPos = pos;
    if (mounted) setState(() {});
  }

  void _onMessage(LiveMessage msg) {
    if (_messages.length > 200) _messages.removeAt(0);
    _messages.add(msg);
    if (mounted) setState(() {});
    if (!_disableAutoScroll) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    if (_statusListener != null) widget.statusNotifier.removeListener(_statusListener!);
    _statusTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            if (_statusMsg != null)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                color: Colors.blue.withAlpha(25),
                child: Text(
                  _statusMsg!,
                  style: const TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ),
            Expanded(
              child: ListView.separated(
                controller: _scrollController,
                separatorBuilder: (_, i) => SizedBox(
                  height:
                      AppSettingsController.instance.chatTextGap.value * 2,
                ),
                padding: AppStyle.edgeInsetsA12,
                itemCount: _messages.length,
                itemBuilder: (ctx, i) =>
                    widget.buildItem(_messages[i], ctx),
              ),
            ),
          ],
        ),
        if (_disableAutoScroll)
          Positioned(
            right: 12,
            bottom: 12,
            child: ElevatedButton.icon(
              onPressed: () {
                _disableAutoScroll = false;
                _scrollToBottom();
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.expand_more),
              label: const Text("最新"),
            ),
          ),
      ],
    );
  }
}
