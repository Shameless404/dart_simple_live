import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/models/account/bilibili_user_info_page.dart';
import 'package:simple_live_app/requests/http_client.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_core/simple_live_core.dart';

/// 哔哩哔哩账号状态检查结果
class BiliLoginCheckResult {
  /// 0 = 正常；-101 = 登录失效；其他非0 = 异常
  final int code;

  /// 具体报错信息，供弹窗展示
  final String message;
  const BiliLoginCheckResult(this.code, this.message);

  bool get isOk => code == 0;
}

class BiliBiliAccountService extends GetxService {
  static BiliBiliAccountService get instance =>
      Get.find<BiliBiliAccountService>();

  var logined = false.obs;

  var cookie = "";
  var uid = 0;
  var name = "未登录".obs;

  static const int kCheckCacheMs = 5 * 60 * 1000;
  BiliLoginCheckResult? _lastCheck;
  int _lastCheckTime = 0;

  @override
  void onInit() {
    cookie = LocalStorageService.instance
        .getValue(LocalStorageService.kBilibiliCookie, "");
    logined.value = cookie.isNotEmpty;
    loadUserInfo();
    super.onInit();
  }

  /// 检查哔哩哔哩账号状态（带 5 分钟缓存）
  /// - 不自动登出，任何异常都保留 cookie
  Future<BiliLoginCheckResult> loadUserInfo({bool force = false}) async {
    var now = DateTime.now().millisecondsSinceEpoch;
    if (!force &&
        _lastCheck != null &&
        now - _lastCheckTime < kCheckCacheMs) {
      return _lastCheck!;
    }
    if (cookie.isEmpty) {
      return const BiliLoginCheckResult(-101, "未登录");
    }
    BiliLoginCheckResult result;
    try {
      var response = await HttpClient.instance.get(
        "https://api.bilibili.com/x/member/web/account",
        header: {
          "Cookie": cookie,
        },
      );
      var code = response.data["code"] ?? -1;
      if (code == 0) {
        var info = BiliBiliUserInfoModel.fromJson(response.data["data"]);
        name.value = info.uname ?? "未登录";
        uid = info.mid ?? 0;
        setSite();

        var setCookieHeaders = response.headers["set-cookie"];
        if (setCookieHeaders != null && setCookieHeaders.isNotEmpty) {
          var newCookie = <String>{};
          for (var part in cookie.split(";")) {
            var trimmed = part.trim();
            if (trimmed.isNotEmpty) {
              newCookie.add(trimmed);
            }
          }
          for (var header in setCookieHeaders) {
            var cookiePair = header.split(";")[0].trim();
            var key = cookiePair.split("=")[0];
            newCookie.removeWhere((c) => c.startsWith("$key="));
            newCookie.add(cookiePair);
          }
          var merged = newCookie.join("; ");
          if (merged != cookie) {
            setCookie(merged);
          }
        }
        result = const BiliLoginCheckResult(0, "正常");
      } else {
        var message = response.data["message"]?.toString();
        if (message == null || message.isEmpty) {
          message = "哔哩哔哩接口返回异常($code)";
        }
        result = BiliLoginCheckResult(code, message);
      }
    } catch (e) {
      result = BiliLoginCheckResult(-1, "网络异常，请检查网络后重试");
    }
    _lastCheck = result;
    _lastCheckTime = DateTime.now().millisecondsSinceEpoch;
    return result;
  }

  /// 校验指定 cookie 是否有效（登录入库前的预校验）
  /// - 只调接口判定，不保存 cookie、不更新任何状态
  Future<BiliLoginCheckResult> validateCookie(String cookieStr) async {
    try {
      var response = await HttpClient.instance.get(
        "https://api.bilibili.com/x/member/web/account",
        header: {
          "Cookie": cookieStr,
        },
      );
      var code = response.data["code"] ?? -1;
      if (code == 0) {
        return const BiliLoginCheckResult(0, "正常");
      }
      var message = response.data["message"]?.toString();
      if (message == null || message.isEmpty) {
        message = "哔哩哔哩接口返回异常($code)";
      }
      return BiliLoginCheckResult(code, message);
    } catch (e) {
      return const BiliLoginCheckResult(-1, "网络异常，请检查网络后重试");
    }
  }

  void setSite() {
    var site = (Sites.allSites[Constant.kBiliBili]!.liveSite as BiliBiliSite);
    site.userId = uid;
    site.cookie = cookie;
  }

  void setCookie(String cookie) {
    this.cookie = cookie;
    _lastCheck = null;
    _lastCheckTime = 0;
    LocalStorageService.instance
        .setValue(LocalStorageService.kBilibiliCookie, cookie);
    logined.value = cookie.isNotEmpty;
  }

  void logout() async {
    cookie = "";
    uid = 0;
    name.value = "未登录";
    setSite();
    LocalStorageService.instance
        .setValue(LocalStorageService.kBilibiliCookie, "");
    logined.value = false;
    _lastCheck = null;
    _lastCheckTime = 0;

    if (Platform.isAndroid || Platform.isIOS) {
      CookieManager cookieManager = CookieManager.instance();
      await cookieManager.deleteAllCookies();
    }
  }
}
