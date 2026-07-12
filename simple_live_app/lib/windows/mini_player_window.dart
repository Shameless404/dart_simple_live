import 'dart:async';
import 'dart:convert';
import 'dart:io';


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_app/services/blocked_users_service.dart';
import 'package:window_manager/window_manager.dart';
import 'package:url_launcher/url_launcher_string.dart';


class MiniPlayerArguments {
  final String siteId;
  final String roomId;
  final String streamUrl;
  final Map<String, String>? streamHeaders;
  final String bilibiliCookie;
  final double danmuSize;
  final double danmuSpeed;
  final double danmuArea;
  final double danmuOpacity;
  final int danmuFontWeight;
  final double danmuStrokeWidth;
  final String danmakuSite;
  final String danmakuJson;
  final int cascadeIndex;
  final String userName;
  final double? mainDanmuSize;
  final String title;

  MiniPlayerArguments({
    required this.siteId,
    required this.roomId,
    required this.streamUrl,
    this.streamHeaders,
    required this.bilibiliCookie,
    required this.danmuSize,
    required this.danmuSpeed,
    required this.danmuArea,
    required this.danmuOpacity,
    required this.danmuFontWeight,
    required this.danmuStrokeWidth,
    required this.danmakuSite,
    required this.danmakuJson,
    this.cascadeIndex = 0,
    this.userName = '',
    this.title = '',
    this.mainDanmuSize,
  });

  Map<String, dynamic> toJson() => {
        'siteId': siteId,
        'roomId': roomId,
        'streamUrl': streamUrl,
        'streamHeaders': streamHeaders,
        'bilibiliCookie': bilibiliCookie,
        'danmuSize': danmuSize,
        'danmuSpeed': danmuSpeed,
        'danmuArea': danmuArea,
        'danmuOpacity': danmuOpacity,
        'danmuFontWeight': danmuFontWeight,
        'danmuStrokeWidth': danmuStrokeWidth,
        'danmakuSite': danmakuSite,
        'danmakuJson': danmakuJson,
        'cascadeIndex': cascadeIndex,
        'userName': userName,
        'title': title,
        'mainDanmuSize': mainDanmuSize,
      };

  factory MiniPlayerArguments.fromJson(Map<String, dynamic> json) =>
      MiniPlayerArguments(
        siteId: json['siteId'] as String,
        roomId: json['roomId'] as String,
        streamUrl: json['streamUrl'] as String? ?? '',
        streamHeaders: json['streamHeaders'] != null
            ? Map<String, String>.from(json['streamHeaders'] as Map)
            : null,
        bilibiliCookie: json['bilibiliCookie'] as String? ?? '',
        danmuSize: (json['danmuSize'] as num?)?.toDouble() ?? 14,
        danmuSpeed: (json['danmuSpeed'] as num?)?.toDouble() ?? 8,
        danmuArea: (json['danmuArea'] as num?)?.toDouble() ?? 0.3,
        danmuOpacity: (json['danmuOpacity'] as num?)?.toDouble() ?? 0.8,
        danmuFontWeight: (json['danmuFontWeight'] as int? ?? 4).clamp(0, 8),
        danmuStrokeWidth: (json['danmuStrokeWidth'] as num?)?.toDouble() ?? 0,
        danmakuSite: json['danmakuSite'] as String? ?? '',
        danmakuJson: json['danmakuJson'] as String? ?? '',
        cascadeIndex: (json['cascadeIndex'] as int? ?? 0).clamp(0, 999),
        userName: json['userName'] as String? ?? '',
        title: json['title'] as String? ?? '',
        mainDanmuSize: (json['mainDanmuSize'] as num?)?.toDouble(),
      );
}

class MiniPlayerApp extends StatelessWidget {
  final MiniPlayerArguments args;
  const MiniPlayerApp({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Live',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home: MiniPlayerPage(args: args),
    );
  }
}

Player? globalMiniPlayer;

void _logVf(String msg) {
  try {
    final f = File(r'D:\simple_live\minipayer_debug.log');
    f.writeAsStringSync('${DateTime.now().toIso8601String()} $msg\n', mode: FileMode.append);
  } catch (_) {}
}


class MiniPlayerPage extends StatefulWidget {
  final MiniPlayerArguments args;
  const MiniPlayerPage({super.key, required this.args});

  @override
  State<MiniPlayerPage> createState() => _MiniPlayerPageState();
}

class _MiniPlayerPageState extends State<MiniPlayerPage> {
  late final Player player;
  late final VideoController videoController;
  DanmakuController? danmakuController;
  LiveDanmaku? liveDanmaku;
  bool _danmakuSecondaryHit = false;
  bool _pendingSecondaryDown = false;
  bool _danmakuUserEnabled = false;
  bool _danmakuFrozen = false;
  bool? _showControls; // null = hidden, true = shown (null-form)
  bool _isFullscreen = false;
  bool _isPinned = true;
  bool _showMoreMenu = false;
  late double _danmuSize;
  late double _danmuSpeed;
  double _savedDanmuSize = 8.0;
  double _volume = 0.0;  // 滑块自身状态（0.0-1.0），不是 player.state.volume 的副本
  double _lastVolume = 0.5;  // 静音前音量，用于恢复
  bool _hwdec = false;
  Offset? _dragStart;
  Timer? _cleanupTimer;
  StreamSubscription? _playingSub;
  StreamSubscription? _volumeSub;

  @override
  void initState() {
    super.initState();
    _danmuSize = widget.args.danmuSize;
    _danmuSpeed = widget.args.danmuSpeed;
    _logVf('init: site=${widget.args.siteId} room=${widget.args.roomId} urlLen=${widget.args.streamUrl.length} userName=${widget.args.userName} cascade=${widget.args.cascadeIndex}');
    BlockedUsersService.instance.init();
    player = Player(
      configuration: const PlayerConfiguration(
        title: 'Simple Live Player',
        logLevel: MPVLogLevel.error,
      ),
    );
    (player.platform as dynamic).setProperty('hwdec', 'no');
    (player.platform as dynamic).setProperty('framedrop', 'vo');
    (player.platform as dynamic).setProperty('display-fps', '30');
    player.setVolume(0.0);
    _volume = 0.0;
    _logVf('init: player created, hwdec=no framedrop=vo volume=0.0');
    globalMiniPlayer = player;
    videoController = VideoController(player);
    _playingSub = player.stream.playing.listen((_) {
      if (mounted) setState(() {});
    });
    _volumeSub = player.stream.volume.listen((v) {
      _volume = v / 100.0;
      if (mounted) setState(() {});
    });
    windowManager.setTitle("${widget.args.userName} - ${widget.args.title}");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _play();
    });
  }

  @override
  void dispose() {
    _logVf('dispose: cleaning up');
    globalMiniPlayer = null;
    _cleanupTimer?.cancel();
    _showMoreMenu = false;
    _playingSub?.cancel();
    _volumeSub?.cancel();
    liveDanmaku?.stop();
    player.dispose();
    _logVf('dispose: done');
    super.dispose();
  }

  Future<void> _play() async {
    _logVf('_play: start');
    await windowManager.setAlwaysOnTop(true);
    if (mounted) setState(() => _isPinned = true);
    final sizeFuture = _waitForVideoSize();
    await _reloadStream();
    _logVf('_play: reloadStream done, waiting for video size');
    final size = await sizeFuture;
    if (size != null) _resizeWindow(size.$1, size.$2);
    _logVf('_play: done, size=$size');
  }

  LiveSite _createSite(String siteId) {
    switch (siteId) {
      case 'bilibili':
        final site = BiliBiliSite();
        if (widget.args.bilibiliCookie.isNotEmpty) {
          site.cookie = widget.args.bilibiliCookie;
        }
        return site;
      case 'douyu':
        return DouyuSite();
      case 'huya':
        return HuyaSite();
      default:
        return DouyinSite();
    }
  }

  Future<(int, int)?> _waitForVideoSize() async {
    try {
      final params = await player.stream.videoParams
          .firstWhere((p) => p.dw != null && p.dh != null && p.dw! > 0 && p.dh! > 0)
          .timeout(const Duration(seconds: 5));
      int w = params.dw!;
      int h = params.dh!;
      if (params.rotate == 90 || params.rotate == 270) {
        final tmp = w;
        w = h;
        h = tmp;
      }
      _logVf('videoSize: dw=$w dh=$h rotate=${params.rotate}');
      return (w, h);
    } catch (_) {
      _logVf('videoSize: timeout (5s, no valid size)');
      return null;
    }
  }

  Future<void> _resizeWindow(int w, int h) async {
    if (w <= 0 || h <= 0) { _logVf('resize: skip w=$w h=$h'); return; }
    final aspectRatio = w / h;
    double targetWidth, targetHeight;
    if (aspectRatio >= 1) {
      targetWidth = 640;
      targetHeight = (640 / aspectRatio).roundToDouble();
    } else {
      targetHeight = 540;
      targetWidth = (540 * aspectRatio).roundToDouble();
    }
    targetWidth = targetWidth.clamp(280, 900);
    targetHeight = targetHeight.clamp(200, 700);
    final pos = await windowManager.getPosition();
    _logVf('resize: src=${w}x$h ratio=$aspectRatio target=${targetWidth}x$targetHeight pos=${pos.dx.round()}x${pos.dy.round()}');
    await windowManager.setBounds(Rect.fromLTWH(pos.dx, pos.dy, targetWidth, targetHeight));
  }

  Future<void> _reloadStream() async {
    _logVf('=== reloadStream start ===');
    try {
      final site = _createSite(widget.args.siteId);
      _logVf('site: ${widget.args.siteId}');
      final detail = await site.getRoomDetail(roomId: widget.args.roomId);
      final qualities = await site.getPlayQualites(detail: detail);
      if (qualities.isEmpty) { _logVf('ABORT: no qualities'); return; }
      final qualityIdx = _hwdec ? 0 : qualities.length - 1;
      final playUrl = await site.getPlayUrls(detail: detail, quality: qualities[qualityIdx]);
      _logVf('qualities: ${qualities.length}, picked idx=$qualityIdx ${_hwdec ? "best" : "worst"}');
      if (playUrl.urls.isEmpty) { _logVf('ABORT: no urls'); return; }
      await player.stop();
      await Future.delayed(const Duration(milliseconds: 100));
      await player.open(Media(
        playUrl.urls[0],
        httpHeaders: playUrl.headers,
      ));
      await player.play();
      _logVf('reload done');
    } catch (e) {
      _logVf('RELOAD ERROR: $e');
    }
    _logVf('=== reloadStream end ===');
    if (mounted) setState(() {});
  }

  Future<void> _toggleHwdecAndReload() async {
    _hwdec = !_hwdec;
    _logVf('toggle mode=${_hwdec ? "hard" : "soft"}');
    if (_hwdec) {
      await (player.platform as dynamic).setProperty('hwdec', 'auto');
      await (player.platform as dynamic).setProperty('framedrop', 'no');
      await (player.platform as dynamic).setProperty('display-fps', '0');
    } else {
      await (player.platform as dynamic).setProperty('hwdec', 'no');
      await (player.platform as dynamic).setProperty('framedrop', 'vo');
      await (player.platform as dynamic).setProperty('display-fps', '30');
    }
    _reloadStream();
  }

  void _refreshStream() {
    _logVf('refreshStream');
    _reloadStream();
  }

  Future<void> _toggleFullscreen() async {
    final isFullscreen = await windowManager.isFullScreen();
    _logVf('toggleFullscreen: was=$isFullscreen going=${!isFullscreen}');
    if (!isFullscreen) {
      _savedDanmuSize = _danmuSize;
      _danmuSize = (widget.args.mainDanmuSize ?? _danmuSize).clamp(8.0, 50.0);
      _applyDanmuOption();
    } else {
      _danmuSize = _savedDanmuSize;
      _applyDanmuOption();
    }
    await windowManager.setFullScreen(!isFullscreen);
    _isFullscreen = !isFullscreen;
    if (_isFullscreen) {
      _showControls = null;
      _showMoreMenu = false;
      _cleanupTimer?.cancel();
    } else {
      _showControls = null;
    }
    if (mounted) setState(() {});
  }

  Future<void> _exitFullscreen() async {
    if (await windowManager.isFullScreen()) {
      _logVf('exitFullscreen');
      await windowManager.setFullScreen(false);
      _isFullscreen = false;
      _showControls = null;
      if (mounted) setState(() {});
    }
  }

  Future<void> _closeWindow() async {
    _logVf('closeWindow');
    await globalMiniPlayer?.dispose();
    globalMiniPlayer = null;
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  Future<void> _openInBrowser() async {
    final url = _getWebUrl();
    _logVf('openInBrowser: $url');
    if (url.isNotEmpty) {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    }
  }

  String _getWebUrl() {
    switch (widget.args.siteId) {
      case 'bilibili':
        return 'https://live.bilibili.com/${widget.args.roomId}';
      case 'douyin':
        try {
          final data = jsonDecode(widget.args.danmakuJson);
          final webRid = data['webRid'] as String?;
          if (webRid != null && webRid.isNotEmpty) {
            return 'https://live.douyin.com/$webRid';
          }
        } catch (_) {}
        return 'https://live.douyin.com/${widget.args.roomId}';
      case 'huya':
        return 'https://www.huya.com/${widget.args.roomId}';
      case 'douyu':
        return 'https://www.douyu.com/${widget.args.roomId}';
      default:
        return '';
    }
  }

  Future<void> _connectDanmaku() async {
    if (widget.args.danmakuJson.isEmpty) { _logVf('danmaku: skip (empty json)'); return; }
    _logVf('danmaku: connecting, site=${widget.args.danmakuSite}');
    try {
      switch (widget.args.danmakuSite) {
        case 'bilibili': {
          final data = jsonDecode(widget.args.danmakuJson);
          final args = BiliBiliDanmakuArgs(
            roomId: data['roomId'] as int,
            token: data['token'] as String,
            serverHost: data['serverHost'] as String,
            buvid: data['buvid'] as String,
            uid: data['uid'] as int,
            cookie: data['cookie'] as String,
          );
          liveDanmaku = BiliBiliDanmaku();
          _setupDanmakuHandlers();
          await liveDanmaku!.start(args);
          break;
        }
        case 'douyu': {
          liveDanmaku = DouyuDanmaku();
          _setupDanmakuHandlers();
          await liveDanmaku!.start(widget.args.danmakuJson);
          break;
        }
        case 'huya': {
          final data = jsonDecode(widget.args.danmakuJson);
          final args = HuyaDanmakuArgs(
            ayyuid: data['ayyuid'] as int,
            topSid: data['topSid'] as int,
            subSid: data['subSid'] as int,
          );
          liveDanmaku = HuyaDanmaku();
          _setupDanmakuHandlers();
          await liveDanmaku!.start(args);
          break;
        }
        case 'douyin': {
          final data = jsonDecode(widget.args.danmakuJson);
          final args = DouyinDanmakuArgs(
            webRid: data['webRid'] as String,
            roomId: data['roomId'] as String,
            userId: data['userId'] as String,
            cookie: data['cookie'] as String,
          );
          liveDanmaku = DouyinDanmaku();
          _setupDanmakuHandlers();
          await liveDanmaku!.start(args);
          break;
  }
}

      _logVf('danmaku: connected');
    } catch (e) { _logVf('danmaku ERROR: $e'); }
  }

  void _setupDanmakuHandlers() {
    liveDanmaku!.onMessage = (LiveMessage msg) {
      if (msg.type != LiveMessageType.chat) return;
      final siteId = widget.args.danmakuSite;
      if (BlockedUsersService.instance.isBlocked(siteId, msg.userName)) return;
      final c = msg.color;
      final color = Color.fromARGB(255, c.r, c.g, c.b);
      final item = DanmakuContentItem(
        msg.message,
        color: color,
        type: DanmakuItemType.scroll,
        userName: msg.userName,
      );
      danmakuController?.addDanmaku(item);
    };
  }

  void _onDanmakuSecondaryTap(DanmakuContentItem item, Offset globalPosition) {
    _logVf('danmakuSecondaryTap: user=${item.userName} pos=${globalPosition.dx.round()},${globalPosition.dy.round()}');
    if (item.userName == null || item.userName!.isEmpty) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry menuEntry;
    menuEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                menuEntry.remove();
              },
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: globalPosition.dx,
            top: globalPosition.dy,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: GestureDetector(
                  onTap: () {
                    BlockedUsersService.instance.block(
                      widget.args.danmakuSite,
                      item.userName!,
                      item.text,
                      anchorName: widget.args.userName,
                    );
                    showBlockUserToast(context, item.userName!);
                    menuEntry.remove();
                  },
                  child: Text(
                    "拉黑「${item.userName}」",
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(menuEntry);
  }

  void _toggleDanmaku() {
    _danmakuUserEnabled = !_danmakuUserEnabled;
    _logVf('danmakuToggle: ${_danmakuUserEnabled ? "ON" : "OFF"}');
    if (!_danmakuUserEnabled) {
      liveDanmaku?.stop();
      liveDanmaku = null;
      danmakuController = null;
    } else {
      _connectDanmaku();
    }
    setState(() {});
  }

  void _applyDanmuOption() {
    danmakuController?.updateOption(DanmakuOption(
      fontSize: _danmuSize,
      duration: _danmuSpeed.toInt(),
      area: widget.args.danmuArea,
      opacity: widget.args.danmuOpacity,
      fontWeight: widget.args.danmuFontWeight,
      showStroke: widget.args.danmuStrokeWidth > 0,
    ));
  }

  void _changeDanmuSize(double delta) {
    _danmuSize = (_danmuSize + delta).clamp(8.0, 50.0);
    _logVf('danmuSize: delta=$delta value=$_danmuSize');
    _applyDanmuOption();
    _saveDanmuCache();
    setState(() {});
  }

  void _changeDanmuSpeed(double delta) {
    _danmuSpeed = (_danmuSpeed + delta).clamp(1.0, 20.0);
    _logVf('danmuSpeed: delta=$delta value=$_danmuSpeed');
    _applyDanmuOption();
    _saveDanmuCache();
    setState(() {});
  }

  void _saveDanmuCache() {
    try {
      final cacheFile =
          File('${Directory.systemTemp.path}\\simple_live_mini_danmu.json');
      cacheFile.writeAsStringSync(jsonEncode({
        'danmuSize': _danmuSize,
        'danmuSpeed': _danmuSpeed,
      }));
    } catch (e) {
      debugPrint('MiniPlayer: save cache failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: MouseRegion(
        onEnter: (_) {
          _logVf('mouse: enter');
          if (_isFullscreen) return;
          _cleanupTimer?.cancel();
          _showControls = true;
          if (mounted) setState(() {});
        },
        onExit: (_) {
          _logVf('mouse: exit (scheduling hide in 3s)');
          if (_showControls == null) return;
          _cleanupTimer?.cancel();
          _cleanupTimer = Timer(const Duration(seconds: 3), () {
            if (_showControls == null) return;
            _logVf('cleanupTimer: full cleanup to null');
            _showControls = null;
            _showMoreMenu = false;
            if (mounted) setState(() {});
          });
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onDoubleTap: _toggleFullscreen,
          child: Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
                if (_isFullscreen) {
                  _exitFullscreen();
                  return KeyEventResult.handled;
                }
                if (_showMoreMenu) {
                  _showMoreMenu = false;
                  if (mounted) setState(() {});
                  return KeyEventResult.handled;
                }
              }
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.keyW &&
                  HardwareKeyboard.instance.isControlPressed) {
                _closeWindow();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Stack(
              children: [
                // Video player — no native controls overlay
                Positioned.fill(
                  key: const ValueKey('video'),
                  child: Video(
                    controller: videoController,
                    fill: Colors.black,
                    controls: null,
                    wakelock: false,
                  ),
                ),
                // Danmaku — behind controls/title/menu
                if (_danmakuUserEnabled)
                  Positioned(
                    key: const ValueKey('danmaku'),
                    top: _showControls == true ? 36 : 0,
                    left: 0,
                    right: 0,
                    bottom: _showControls == true ? 48 : 0,
                    child: Listener(
                      onPointerDown: (event) {
                        if (event.buttons == 2) {
                          _pendingSecondaryDown = true;
                        }
                      },
                      onPointerUp: (event) {
                        if (!_pendingSecondaryDown) return;
                        _pendingSecondaryDown = false;
                        WidgetsBinding.instance.addPostFrameCallback((__) {
                          final wasHit = _danmakuSecondaryHit;
                          _danmakuSecondaryHit = false;
                          if (wasHit) return;
                          if (!_danmakuUserEnabled) return;
                          if (!_danmakuFrozen) {
                            _danmakuFrozen = true;
                            danmakuController?.pause();
                            liveDanmaku?.stop();
                          } else {
                            _danmakuFrozen = false;
                            _connectDanmaku();
                            danmakuController?.clear();
                            danmakuController?.resume();
                          }
                        });
                        WidgetsBinding.instance.scheduleFrame();
                      },
                      behavior: HitTestBehavior.translucent,
                      child: DanmakuScreen(
                        createdController: (c) => danmakuController = c,
                        option: DanmakuOption(
                          fontSize: _danmuSize,
                          duration: _danmuSpeed.toInt(),
                          area: widget.args.danmuArea,
                          opacity: widget.args.danmuOpacity,
                          fontWeight: widget.args.danmuFontWeight,
                          showStroke: widget.args.danmuStrokeWidth > 0,
                        ),
                        onDanmakuSecondaryTap: (item, pos) {
                          _danmakuSecondaryHit = true;
                          _onDanmakuSecondaryTap(item, pos);
                        },
                      ),
                    ),
                  ),
                // Custom title bar — replaces OS title bar
                if (_showControls == true)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 36,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onPanDown: (details) {
                                _logVf('titleBar: startDragging');
                                windowManager.startDragging();
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  "${widget.args.userName} - ${widget.args.title}",
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          _TitleBarButton(Icons.more_horiz, _toggleMoreMenu),
                          _TitleBarCloseButton(),
                          ],
                        ),
                      ),
                  ),
                // Custom controls bar (null-form, only in tree on hover)
                if (_showControls == true)
                  _buildControlsBar(),
                // "更多"菜单 — null-form, 全屏时由 _toggleFullscreen 关
                if (_showMoreMenu)
                  Positioned(
                    top: 36,
                    right: 0,
                    child: GestureDetector(
                      onDoubleTap: () {},
                      child: Container(
                        width: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D2D2D),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white24, width: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _HoverItem(
                                onTap: _toggleHwdecAndReload,
                                child: Container(
                                  height: 30,
                                  alignment: Alignment.center,
                                  child: Text(
                                    _hwdec ? '软' : '硬',
                                  style: TextStyle(
                                    color: _hwdec ? Colors.amber : Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            _buildMoreMenuItem(Icons.refresh, _refreshStream),
                            _buildMoreMenuItem(Icons.arrow_left, () => _changeDanmuSpeed(1)),
                            _buildMoreMenuItem(Icons.arrow_right, () => _changeDanmuSpeed(-1)),
                            _buildMoreMenuItem(Icons.text_decrease, () => _changeDanmuSize(-1)),
                            _buildMoreMenuItem(Icons.text_increase, () => _changeDanmuSize(1)),
                            _buildMoreMenuItem(_danmakuUserEnabled ? Icons.visibility : Icons.visibility_off, _toggleDanmaku),
                            _buildMoreMenuItem(Icons.open_in_browser, _openInBrowser),
                            _buildMoreMenuItem(_isPinned ? Icons.push_pin : Icons.push_pin_outlined, _togglePin, color: _isPinned ? Colors.amber : null),
                            _buildMoreMenuItem(Icons.minimize, () => windowManager.minimize()),
                            _buildMoreMenuItem(Icons.fullscreen, _toggleFullscreen),
                          ],
                        ),
                      ),
                    ),
                    ),
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (e) {
                      if (e.buttons != 1) return;
                      if (_showControls == true) {
                        final h = context.size?.height ?? 0;
                        if (e.position.dy < 36 || e.position.dy >= h - 48) return;
                      }
                      _dragStart = e.position;
                    },
                    onPointerMove: (e) {
                      if (_dragStart == null) return;
                      if ((e.position - _dragStart!).distance > 10.0) {
                        _dragStart = null;
                        windowManager.startDragging();
                      }
                    },
                    onPointerUp: (_) => _dragStart = null,
                  ),
                ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
  void _toggleMoreMenu() {
    _logVf('toggleMoreMenu was=$_showMoreMenu');
    _showMoreMenu = !_showMoreMenu;
    if (mounted) setState(() {});
  }

  Future<void> _togglePin() async {
    final newVal = !_isPinned;
    await windowManager.setAlwaysOnTop(newVal);
    if (mounted) setState(() => _isPinned = newVal);
  }

  Widget _buildMoreMenuItem(IconData icon, VoidCallback onTap, {Color? color}) {
    return _HoverItem(
      onTap: onTap,
      child: Container(
        height: 30,
        alignment: Alignment.center,
        child: Icon(icon, color: color ?? Colors.white70, size: 16),
      ),
    );
  }

  Widget _buildControlsBar() {
    return Positioned(
      key: const ValueKey('controls_bar'),
      bottom: 0,
      left: 0,
      right: 0,
      height: 48,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 4),
            // Play/Pause button
            _HoverItem(
              onTap: () {
                _logVf('controls: playOrPause (playing=${player.state.playing})');
                player.playOrPause();
              },
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: Icon(
                  player.state.playing ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Volume icon (toggle mute)
            _HoverItem(
              onTap: () {
                _logVf('controls: volumeToggle from=${_volume.toStringAsFixed(2)} last=${_lastVolume.toStringAsFixed(2)}');
                if (_volume > 0) {
                  _lastVolume = _volume;
                  _volume = 0.0;
                } else {
                  _volume = _lastVolume;
                }
                _logVf('controls: volumeToggle to=${_volume.toStringAsFixed(2)}');
                player.setVolume(_volume * 100.0);
                setState(() {});
              },
              child: Container(
                width: 32,
                height: 40,
                alignment: Alignment.center,
                child: Icon(
                  _volume > 0 ? Icons.volume_up : Icons.volume_off,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ),
            // Volume slider
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white12,
                  trackHeight: 3,
                ),
                child: Slider(
                  value: _volume * 100,  // 滑块显示 0-100%
                  min: 0,
                  max: 100,
                  onChanged: (v) {
                    _logVf('controls: volumeSlider v=${v.round()}');
                    _volume = v / 100.0;  // 转换成 0.0-1.0
                    player.setVolume(v);  // 直接用 0-100 的值，media_kit 正确范围
                    setState(() {});
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _TitleBarButton(IconData icon, VoidCallback onTap, {Color color = Colors.white70}) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => onTap(),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _TitleBarCloseButton() {
    return _HoverItem(
      useTranslucent: true,
      hoverColor: Colors.red.withValues(alpha: 0.3),
      pressColor: Colors.red,
      onTap: _closeWindow,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        child: const Icon(Icons.close, color: Colors.white70, size: 20),
      ),
    );
  }

}

/// Lightweight hover/press feedback button — no animation controllers.
class _HoverItem extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool useTranslucent;
  final Color hoverColor;
  final Color pressColor;

  const _HoverItem({
    required this.child,
    required this.onTap,
    this.useTranslucent = false,
    this.hoverColor = const Color(0x1AFFFFFF),
    this.pressColor = const Color(0x3DFFFFFF),
  });

  @override
  State<_HoverItem> createState() => _HoverItemState();
}

class _HoverItemState extends State<_HoverItem> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    Color bg;
    if (_isPressed) {
      bg = widget.pressColor;
    } else if (_isHovered) {
      bg = widget.hoverColor;
    } else {
      bg = Colors.transparent;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: widget.useTranslucent
            ? HitTestBehavior.translucent
            : HitTestBehavior.deferToChild,
        onTapDown: (_) {
          setState(() => _isPressed = true);
          widget.onTap();
        },
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: Container(color: bg, child: widget.child),
      ),
    );
  }
}
