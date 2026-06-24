import 'dart:async';
import 'dart:convert';
import 'dart:ffi' hide Size;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import 'package:media_kit/media_kit.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/app/utils/listen_fourth_button.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/modules/other/debug_log_page.dart';
import 'package:simple_live_app/routes/app_pages.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/douyin_account_service.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/mini_player_manager.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_app/services/sync_service.dart';
import 'package:simple_live_app/widgets/status/app_loadding_widget.dart';
import 'package:simple_live_app/windows/mini_player_window.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:window_manager/window_manager.dart';

import 'package:path/path.dart' as p;
import 'package:dynamic_color/dynamic_color.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 捕获全局 hardError（Flutter 引擎关闭时 native 回调残留）
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (error.toString().contains('hardError')) return true;
    return false;
  };

  // Check for mini-player mode (launched as a separate process)
  final miniPlayerArgs = Platform.environment['SIMPLE_LIVE_MINIPLAYER'];
  if (miniPlayerArgs != null && miniPlayerArgs.isNotEmpty) {
    final args = MiniPlayerArguments.fromJson(jsonDecode(miniPlayerArgs));
    // For mini-player process: no Hive, no services, just the player
    CoreLog.enableLog = false;
    MediaKit.ensureInitialized();
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    windowManager.addListener(_MiniWindowCloseHandler());

    {
      final user32 = DynamicLibrary.open('user32.dll');
      final gsm = user32.lookupFunction<Int32 Function(Int32), int Function(int)>('GetSystemMetrics');
      final int screenW = gsm(0);
      final int screenH = gsm(1);
      const double initH = 360;
      const double initW = 640;
      const double step = 150;
      final int idx = args.cascadeIndex;
      final double dpr = ui.window.devicePixelRatio;
      double x = (step * idx).toDouble();
      double y = (step * idx).toDouble();
      if (x + initW > screenW / dpr || y + initH > screenH / dpr) {
        x = 0;
        y = 0;
      }
      await windowManager.setBounds(Rect.fromLTWH(x, y, initW, initH));

      // Remove OS title bar BEFORE runApp — C++ runner created the window before main()
      // Safe for SetWindowPos(SWP_FRAMECHANGED) because no swap chain yet
      final kernel32 = DynamicLibrary.open('kernel32.dll');
      final getCurrentProcessId = kernel32.lookupFunction<
          Uint32 Function(),
          int Function()
        >('GetCurrentProcessId');
      final ourPid = getCurrentProcessId();
      final findWindowW = user32.lookupFunction<
          IntPtr Function(Pointer<Utf16>, Pointer<Utf16>),
          int Function(Pointer<Utf16>, Pointer<Utf16>)
        >('FindWindowW');
      final findWindowExW = user32.lookupFunction<
          IntPtr Function(IntPtr, IntPtr, Pointer<Utf16>, Pointer<Utf16>),
          int Function(int, int, Pointer<Utf16>, Pointer<Utf16>)
        >('FindWindowExW');
      final getWindowThreadProcessId = user32.lookupFunction<
          Uint32 Function(IntPtr, Pointer<Uint32>),
          int Function(int, Pointer<Uint32>)
        >('GetWindowThreadProcessId');
      final getWindowLongPtrW = user32.lookupFunction<
          IntPtr Function(IntPtr, Int32),
          int Function(int, int)
        >('GetWindowLongPtrW');
      final setWindowLongPtrW = user32.lookupFunction<
          IntPtr Function(IntPtr, Int32, IntPtr),
          int Function(int, int, int)
        >('SetWindowLongPtrW');
      final setWindowPos = user32.lookupFunction<
          Int32 Function(IntPtr, IntPtr, Int32, Int32, Int32, Int32, Int32),
          int Function(int, int, int, int, int, int, int)
        >('SetWindowPos');

      const windowClass = 'FLUTTER_RUNNER_WIN32_WINDOW';
      final classNamePtr = windowClass.toNativeUtf16(allocator: malloc);
      final pidPtr = malloc<Uint32>();
      int hwnd = findWindowW(classNamePtr, nullptr);
      while (hwnd != 0) {
        pidPtr.value = 0;
        getWindowThreadProcessId(hwnd, pidPtr);
        if (pidPtr.value == ourPid) {
          const gwlStyle = -16;
          const removeMask = 0x00CB0000;
          final current = getWindowLongPtrW(hwnd, gwlStyle);
          if (current != 0) {
            setWindowLongPtrW(hwnd, gwlStyle, current & ~removeMask);
            setWindowPos(hwnd, 0, 0, 0, 0, 0, 0x0037);
          }
          break;
        }
        hwnd = findWindowExW(0, hwnd, classNamePtr, nullptr);
      }
      malloc.free(pidPtr);
      malloc.free(classNamePtr);
    }
    runApp(MiniPlayerApp(args: args));
    return;
  }

  await migrateData();
  await initWindow();
  MediaKit.ensureInitialized();
  await Hive.initFlutter(
    (!Platform.isAndroid && !Platform.isIOS)
        ? (await getApplicationSupportDirectory()).path
        : null,
  );
  //初始化服务
  await initServices();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  //设置状态栏为透明
  SystemUiOverlayStyle systemUiOverlayStyle = const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
  );
  SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
  runApp(const MyApp());
}

/// 将Hive数据迁移到Application Support
Future migrateData() async {
  if (Platform.isAndroid || Platform.isIOS) {
    return;
  }
  var hiveFileList = [
    "followuser",
    //旧版本写错成hostiry了
    "hostiry",
    "followusertag",
    "localstorage",
    "danmushield",
  ];
  try {
    var newDir = await getApplicationSupportDirectory();
    var hiveFile = File(p.join(newDir.path, "followuser.hive"));
    if (await hiveFile.exists()) {
      return;
    }

    var oldDir = await getApplicationDocumentsDirectory();
    for (var element in hiveFileList) {
      var oldFile = File(p.join(oldDir.path, "$element.hive"));
      if (await oldFile.exists()) {
        var fileName = "$element.hive";
        if (element == "hostiry") {
          fileName = "history.hive";
        }
        await oldFile.copy(p.join(newDir.path, fileName));
        await oldFile.delete();
      }
      var lockFile = File(p.join(oldDir.path, "$element.lock"));
      if (await lockFile.exists()) {
        await lockFile.delete();
      }
    }
  } catch (e) {
    Log.logPrint(e);
  }
}

Future initWindow() async {
  if (!(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    return;
  }
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);
  windowManager.addListener(_MainWindowCloseHandler());
  WindowOptions windowOptions = const WindowOptions(
    minimumSize: Size(280, 280),
    center: true,
    title: "Simple Live",
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

class _MainWindowCloseHandler extends WindowListener {
  @override
  void onWindowClose() {
    Future(() async {
      String? action;
      try {
        action = await Get.dialog<String>(
          AlertDialog(
            title: const Text('退出确认'),
            content: const Text('是否同时关闭所有子窗口？'),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: 'cancel'),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Get.back(result: 'current'),
                child: const Text('关闭当前'),
              ),
              TextButton(
                onPressed: () => Get.back(result: 'all'),
                child: const Text('关闭全部'),
              ),
            ],
          ),
        );
      } catch (_) {
        action = 'all';
      }

      if (action == 'cancel' || action == null) return;

      // 有序清理：触发所有 GetX Controller 的 onClose() → 包括 player.dispose()
      try {
        if (action == 'all') {
          MiniPlayerManager.instance.killAll();
        }
        await Get.deleteAll(force: true);
      } catch (e) { Log.logPrint(e); }
      // 强制销毁窗口，跳过 Flutter 引擎的正常关闭序列，防止 hardError
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    });
  }
}

class _MiniWindowCloseHandler extends WindowListener {
  @override
  void onWindowClose() {
    Future(() async {
      await globalMiniPlayer?.dispose();
      globalMiniPlayer = null;
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    });
  }
}

Future initServices() async {
  Hive.registerAdapter(FollowUserAdapter());
  Hive.registerAdapter(HistoryAdapter());
  Hive.registerAdapter(FollowUserTagAdapter());

  //包信息
  Utils.packageInfo = await PackageInfo.fromPlatform();
  //本地存储
  Log.d("Init LocalStorage Service");
  await Get.put(LocalStorageService()).init();
  await Get.put(DBService()).init();
  //初始化设置控制器
  Get.put(AppSettingsController());

  Get.put(BiliBiliAccountService());

  Get.put(DouyinAccountService());

  Get.put(SyncService());

  Get.put(FollowService());

  initCoreLog();
}

void initCoreLog() {
  //日志信息
  CoreLog.enableLog =
      !kReleaseMode || AppSettingsController.instance.logEnable.value;
  CoreLog.requestLogType = RequestLogType.short;
  CoreLog.onPrintLog = (level, msg) {
    switch (level) {
      case Level.debug:
        Log.d(msg);
        break;
      case Level.error:
        Log.e(msg, StackTrace.current);
        break;
      case Level.info:
        Log.i(msg);
        break;
      case Level.warning:
        Log.w(msg);
        break;
      default:
        Log.logPrint(msg);
    }
  };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    bool isDynamicColor = AppSettingsController.instance.isDynamic.value;
    Color styleColor = Color(AppSettingsController.instance.styleColor.value);
    return DynamicColorBuilder(
        builder: ((ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
      ColorScheme? lightColorScheme;
      ColorScheme? darkColorScheme;
      if (lightDynamic != null && darkDynamic != null && isDynamicColor) {
        lightColorScheme = lightDynamic;
        darkColorScheme = darkDynamic;
      } else {
        lightColorScheme = ColorScheme.fromSeed(
          seedColor: styleColor,
          brightness: Brightness.light,
        );
        darkColorScheme = ColorScheme.fromSeed(
            seedColor: styleColor, brightness: Brightness.dark);
      }
      return GetMaterialApp(
        title: "Simple Live",
        theme: AppStyle.lightTheme.copyWith(colorScheme: lightColorScheme),
        darkTheme: AppStyle.darkTheme.copyWith(colorScheme: darkColorScheme),
        themeMode:
            ThemeMode.values[Get.find<AppSettingsController>().themeMode.value],
        initialRoute: RoutePath.kIndex,
        getPages: AppPages.routes,
        //国际化
        locale: const Locale("zh", "CN"),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale("zh", "CN")],
        logWriterCallback: (text, {bool? isError}) {
          Log.addDebugLog(text, (isError ?? false) ? Colors.red : Colors.grey);
          Log.writeLog(text, (isError ?? false) ? Level.error : Level.info);
        },
        // 升级后Android页面过渡动画似乎有BUG
        defaultTransition: Platform.isAndroid ? Transition.cupertino : null,
        //debugShowCheckedModeBanner: false,
        navigatorObservers: [FlutterSmartDialog.observer],
        builder: FlutterSmartDialog.init(
          loadingBuilder: ((msg) => const AppLoaddingWidget()),
          //字体大小不跟随系统变化
          builder: (context, child) {
            // Fix for HyperOS windowed-mode Flutter bug:
            // - Values > 50 indicate the bug (windowed mode on HyperOS)
            // - Values == 0 are valid for fullscreen/immersive mode and must NOT be treated as abnormal
            const fallbackPadding = EdgeInsets.only(top: 25, bottom: 35);
            const maxNormalPadding = 50.0;

            final mediaQueryData = MediaQuery.of(context);
            final hasAbnormalPadding = mediaQueryData.viewPadding.top > maxNormalPadding;

            final fixedMediaQueryData = hasAbnormalPadding
                ? mediaQueryData.copyWith(
                    viewPadding: fallbackPadding,
                    padding: fallbackPadding,
                    textScaler: const TextScaler.linear(1.0),
                  )
                : mediaQueryData.copyWith(textScaler: const TextScaler.linear(1.0));

            return MediaQuery(
              data: fixedMediaQueryData,
              child: Stack(
              children: [
                //侧键返回
                RawGestureDetector(
                  excludeFromSemantics: true,
                  gestures: <Type, GestureRecognizerFactory>{
                    FourthButtonTapGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                            FourthButtonTapGestureRecognizer>(
                      () => FourthButtonTapGestureRecognizer(),
                      (FourthButtonTapGestureRecognizer instance) {
                        instance.onTapDown = (TapDownDetails details) async {
                          //如果处于全屏状态，退出全屏
                          if (!Platform.isAndroid && !Platform.isIOS) {
                            if (await windowManager.isFullScreen()) {
                              await windowManager.setFullScreen(false);
                              return;
                            }
                          }
                          Get.back();
                        };
                      },
                    ),
                  },
                  child: KeyboardListener(
                    focusNode: FocusNode(),
                    onKeyEvent: (KeyEvent event) async {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.escape) {
                        // ESC退出全屏
                        // 如果处于全屏状态，退出全屏
                        if (!Platform.isAndroid && !Platform.isIOS) {
                          if (await windowManager.isFullScreen()) {
                            await windowManager.setFullScreen(false);
                            return;
                          }
                        }
                      }
                    },
                    child: child!,
                  ),
                ),

                //查看DEBUG日志按钮
                //只在Debug、Profile模式显示
                Visibility(
                  visible: !kReleaseMode,
                  child: Positioned(
                    right: 12,
                    bottom: 100 + context.mediaQueryViewPadding.bottom,
                    child: Opacity(
                      opacity: 0.4,
                      child: ElevatedButton(
                        child: const Text("DEBUG LOG"),
                        onPressed: () {
                          Get.bottomSheet(
                            const DebugLogPage(),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            );
          },
        ),
      );
    }));
  }
}
