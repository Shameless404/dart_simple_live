import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/sync_client_info_model.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/sync_service.dart';
import 'package:simple_live_core/simple_live_core.dart';

/// APP页面跳转封装
/// * 需要参数的页面都应使用此类
/// * 如不需要参数，可以使用Get.toNamed
class AppNavigator {
  /// 跳转至分类详情
  static void toCategoryDetail(
      {required Site site, required LiveSubCategory category}) {
    Get.toNamed(RoutePath.kCategoryDetail, arguments: [site, category]);
  }

  /// 跳转至直播间
  static void toLiveRoomDetail(
      {required Site site, required String roomId}) async {
    if (site.id == Constant.kBiliBili) {
      var account = BiliBiliAccountService.instance;
      if (account.logined.value) {
        // 已登录：点进直播间时校验账号状态，异常则弹窗提示具体报错
        var check = await account.loadUserInfo();
        if (!check.isOk) {
          var goLogin = await Utils.showAlertDialog(
            "${check.message}，是否前往登录？",
            title: "哔哩哔哩登录异常",
            confirm: "前往登录",
            cancel: "取消",
          );
          if (goLogin) {
            await toBiliBiliLogin();
          }
        }
      } else if (AppSettingsController.instance.bilibiliLoginTip.value) {
        // 未登录
        var result = await Utils.showAlertDialog(
          "哔哩哔哩需要登录才能观看高清直播，是否前往登录？",
          title: "登录哔哩哔哩",
          actions: [
            TextButton(
              onPressed: () {
                AppSettingsController.instance.setBiliBiliLoginTip(false);
                Get.back(result: false);
              },
              child: const Text("不再提示"),
            ),
          ],
        );
        if (result == true) {
          await toBiliBiliLogin();
          if (!BiliBiliAccountService.instance.logined.value) {
            SmartDialog.showToast("未完成登录");
          }
        }
      }
    }

    Get.toNamed(RoutePath.kLiveRoomDetail, arguments: site, parameters: {
      "roomId": roomId,
    });
  }

  /// 跳转至哔哩哔哩登录（应用内浏览器登录）
  static Future toBiliBiliLogin() async {
    await Get.toNamed(RoutePath.kBiliBiliWebLogin);
  }

  /// 跳转至同步设备
  static Future toSyncDevice(
      SyncClinet client, SyncClientInfoModel info) async {
    await Get.toNamed(
      RoutePath.kLocalSyncDevice,
      arguments: {
        "client": client,
        "info": info,
      },
    );
  }
}
