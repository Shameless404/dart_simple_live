import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/mini_player_manager.dart';
import 'package:simple_live_app/windows/mini_player_window.dart';
import 'package:simple_live_core/simple_live_core.dart';

Future<void> openMiniWindow(FollowUser item,
    {int cascadeIndex = 0, bool skipConfirm = false}) async {
  if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    return;
  }

  if (!skipConfirm) {
    var confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text("新窗口播放"),
        content:
            Text("是否在新窗口中打开「${item.userName}」的直播间？"),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text("确定"),
          ),
        ],
      ),
    );
    if (confirm != true) return;
  }

  var bilibiliCookie = '';
  if (item.siteId == Constant.kBiliBili) {
    bilibiliCookie = BiliBiliAccountService.instance.cookie;
  }

  var streamUrl = '';
  Map<String, String>? streamHeaders;
  var danmakuSite = item.siteId;
  var danmakuJson = '';
  var userName = item.userName;
  var title = '';
  try {
    if (item.siteId == Constant.kDouyin) {
      final site = Sites.allSites[Constant.kDouyin]!.liveSite;
      final detail = await site.getRoomDetail(roomId: item.roomId);
      userName = detail.userName;
      title = detail.title;
      if (detail.danmakuData != null) {
        danmakuJson = detail.danmakuData.toString();
      }
    } else {
      final site = Sites.allSites[item.siteId]?.liveSite;
      if (site != null) {
        if (site is BiliBiliSite && bilibiliCookie.isNotEmpty) {
          site.cookie = bilibiliCookie;
        }
        final detail = await site.getRoomDetail(roomId: item.roomId);
        userName = detail.userName;
        title = detail.title;
        if (detail.danmakuData != null) {
          if (item.siteId == 'douyu') {
            danmakuJson = detail.danmakuData as String;
          } else {
            danmakuJson = detail.danmakuData.toString();
          }
        }
        final qualities = await site.getPlayQualites(detail: detail);
        if (qualities.isNotEmpty) {
          final playUrl =
              await site.getPlayUrls(detail: detail, quality: qualities[0]);
          if (playUrl.urls.isNotEmpty) {
            streamUrl = playUrl.urls[0];
            streamHeaders = playUrl.headers;
          }
        }
      }
    }
  } catch (e) {
    Log.logPrint(e);
  }

  var settings = AppSettingsController.instance;
  var danmuSize = settings.danmuSize.value;
  try {
    final cacheFile =
        File('${Directory.systemTemp.path}\\simple_live_mini_danmu.json');
    if (cacheFile.existsSync()) {
      final cacheData = jsonDecode(cacheFile.readAsStringSync());
      danmuSize = ((cacheData['danmuSize'] as num?)?.toDouble() ?? danmuSize)
          .clamp(8.0, 48.0);
    }
  } catch (e) {
    debugPrint('MiniPlayer: read cache failed: $e');
  }
  var args = MiniPlayerArguments(
    roomId: item.roomId,
    siteId: item.siteId,
    streamUrl: streamUrl,
    streamHeaders: streamHeaders,
    bilibiliCookie: bilibiliCookie,
    danmuSize: danmuSize,
    danmuSpeed: settings.danmuSpeed.value,
    danmuArea: settings.danmuArea.value,
    danmuOpacity: settings.danmuOpacity.value,
    danmuFontWeight: settings.danmuFontWeight.value,
    danmuStrokeWidth: settings.danmuStrokeWidth.value,
    danmakuSite: danmakuSite,
    danmakuJson: danmakuJson,
    cascadeIndex: cascadeIndex,
    userName: userName,
    title: title,
  );

  final env = Map<String, String>.from(Platform.environment);
  env['SIMPLE_LIVE_MINIPLAYER'] = jsonEncode(args.toJson());
  final proc = await Process.start(Platform.executable, [],
      environment: env, mode: ProcessStartMode.detached);
  MiniPlayerManager.instance.register(proc);
}
