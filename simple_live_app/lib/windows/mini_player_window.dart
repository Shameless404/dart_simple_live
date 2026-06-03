import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_app/services/blocked_users_service.dart';
import 'package:window_manager/window_manager.dart';

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

class _PinToggleButton extends StatefulWidget {
  const _PinToggleButton();

  @override
  State<_PinToggleButton> createState() => _PinToggleButtonState();
}

class _PinToggleButtonState extends State<_PinToggleButton> {
  bool _isPinned = true;

  @override
  void initState() {
    super.initState();
    _initPinned();
  }

  Future<void> _initPinned() async {
    final pinned = await windowManager.isAlwaysOnTop();
    if (mounted) setState(() => _isPinned = pinned);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final newValue = !_isPinned;
        await windowManager.setAlwaysOnTop(newValue);
        if (mounted) setState(() => _isPinned = newValue);
      },
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: Icon(
          Icons.push_pin,
          color: _isPinned ? Colors.amber : Colors.white70,
          size: 18,
        ),
      ),
    );
  }
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
  bool _isOverlayActive = false;
  bool _danmakuUserEnabled = false;
  bool _showControls = false;
  bool _isMaximized = false;
  late double _danmuSize;
  double _volume = 0.0;  // 滑块自身状态（0.0-1.0），不是 player.state.volume 的副本
  double _lastVolume = 0.5;  // 静音前音量，用于恢复
  Timer? _cleanupTimer;
  StreamSubscription? _playingSub;
  StreamSubscription? _volumeSub;

  @override
  void initState() {
    super.initState();
    _danmuSize = widget.args.danmuSize;
    BlockedUsersService.instance.init();
    player = Player(
      configuration: const PlayerConfiguration(
        title: 'Simple Live Player',
        logLevel: MPVLogLevel.error,
      ),
    );
    player.setVolume(0.0);  // 默认静音（media_kit范围：0.0-100.0）
    _volume = 0.0;
    globalMiniPlayer = player;
    videoController = VideoController(player);
    _playingSub = player.stream.playing.listen((_) {
      if (mounted) setState(() {});
    });
    _volumeSub = player.stream.volume.listen((v) {
      _volume = v / 100.0;  // media_kit 发 0.0-100.0，_volume 用 0.0-1.0
      if (mounted) setState(() {});
    });
    windowManager.setTitle("${widget.args.userName} - ${widget.args.title}");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _play();
    });
  }

  @override
  void dispose() {
    globalMiniPlayer = null;
    _cleanupTimer?.cancel();
    _playingSub?.cancel();
    _volumeSub?.cancel();
    liveDanmaku?.stop();
    player.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    await windowManager.setAlwaysOnTop(true);
    if (widget.args.streamUrl.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 100));
      final sizeFuture = _waitForVideoSize();
      await player.open(Media(
        widget.args.streamUrl,
        httpHeaders: widget.args.streamHeaders,
      ));
      await player.play();
      if (mounted) setState(() {});
      final size = await sizeFuture;
      if (size != null) _resizeWindow(size.$1, size.$2);
      return;
    }
    if (widget.args.siteId == 'douyin') {
      await _resolveDouyinAndPlay();
    }
  }

  Future<void> _resolveDouyinAndPlay() async {
    try {
      final site = DouyinSite();
      final detail = await site.getRoomDetail(roomId: widget.args.roomId);
      final qualities = await site.getPlayQualites(detail: detail);
      if (qualities.isEmpty) return;
      final playUrl = await site.getPlayUrls(detail: detail, quality: qualities[0]);
      if (playUrl.urls.isEmpty) return;
      await Future.delayed(const Duration(milliseconds: 100));
      final sizeFuture = _waitForVideoSize();
      await player.open(Media(
        playUrl.urls[0],
        httpHeaders: playUrl.headers,
      ));
      await player.play();
      if (mounted) setState(() {});
      final size = await sizeFuture;
      if (size != null) _resizeWindow(size.$1, size.$2);
    } catch (e) { debugPrint('MiniPlayer: _resolveDouyinAndPlay error: $e'); }
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
      return (w, h);
    } catch (_) {
      return null;
    }
  }

  Future<void> _resizeWindow(int w, int h) async {
    if (w <= 0 || h <= 0) return;
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
    await windowManager.setSize(Size(targetWidth, targetHeight));
  }

  Future<void> _connectDanmaku() async {
    if (widget.args.danmakuJson.isEmpty) return;
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
    } catch (e) { debugPrint('MiniPlayer: _connectDanmaku error: $e'); }
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
    if (item.userName == null || item.userName!.isEmpty) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    _isOverlayActive = true;
    late OverlayEntry menuEntry;
    menuEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                menuEntry.remove();
                _isOverlayActive = false;
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
                    _isOverlayActive = false;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      danmakuController?.pause();
    });
  }

  void _toggleDanmaku() {
    _danmakuUserEnabled = !_danmakuUserEnabled;
    if (!_danmakuUserEnabled) {
      liveDanmaku?.stop();
      liveDanmaku = null;
      danmakuController = null;
    } else {
      _connectDanmaku();
    }
    setState(() {});
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: MouseRegion(
        onEnter: (_) {
          _cleanupTimer?.cancel();
          danmakuController?.pause();
          _showControls = true;
          if (mounted) setState(() {});
        },
        onExit: (_) {
          if (!_isOverlayActive) {
            danmakuController?.resume();
          }
          _cleanupTimer?.cancel();
          _cleanupTimer = Timer(const Duration(seconds: 3), () {
            if (!_isOverlayActive) {
              _showControls = false;
            }
            if (mounted) setState(() {});
          });
        },
          child: Stack(
            children: [
              // Video player — no native controls overlay (CPU optimization)
              Positioned.fill(
                key: const ValueKey('video'),
                child: Video(
                  controller: videoController,
                  fill: Colors.black,
                  controls: null,
                  wakelock: false,
                ),
              ),
              // Custom title bar (visible on hover) — replaces OS title bar
              if (_showControls)
                Positioned(
                  key: const ValueKey('title_bar'),
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 36,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.black87, Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 200,
                        bottom: 0,
                        child: DragToMoveArea(
                          child: SizedBox.expand(
                            child: Align(
                              alignment: Alignment.centerLeft,
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
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        bottom: 0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildDanmakuToggle(),
                            const _PinToggleButton(),
                            _TitleBarButton(Icons.minimize, () => windowManager.minimize()),
                            _TitleBarButton(
                              _isMaximized ? Icons.filter_none : Icons.crop_square,
                              _toggleMaximize,
                            ),
                            _TitleBarCloseButton(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              // Custom controls bar (null-form, only in tree on hover)
              if (_showControls)
                _buildControlsBar(),
              // Danmaku — always in tree when enabled, avoids title bar & controls bar on hover
              if (_danmakuUserEnabled)
                Positioned(
                  key: const ValueKey('danmaku'),
                  top: _showControls ? 36 : 0,
                  left: 0,
                  right: 0,
                  bottom: _showControls ? 48 : 0,
                  child: DanmakuScreen(
                    createdController: (c) => danmakuController = c,
                    option: DanmakuOption(
                      fontSize: _danmuSize,
                      duration: widget.args.danmuSpeed.toInt(),
                      area: widget.args.danmuArea,
                      opacity: widget.args.danmuOpacity,
                      fontWeight: widget.args.danmuFontWeight,
                      showStroke: widget.args.danmuStrokeWidth > 0,
                    ),
                    onDanmakuSecondaryTap: (item, pos) => _onDanmakuSecondaryTap(item, pos),
                  ),
                ),
            ],
          ),
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
            GestureDetector(
              onTap: () => player.playOrPause(),
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
            GestureDetector(
              onTap: () {
                if (_volume > 0) {
                  _lastVolume = _volume;  // 保存当前音量
                  _volume = 0.0;  // 静音
                } else {
                  _volume = _lastVolume;  // 恢复静音前音量
                }
                player.setVolume(_volume * 100.0);  // 转换成 media_kit 范围
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

  Widget _buildDanmakuToggle() {
    return GestureDetector(
      onTap: _toggleDanmaku,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: Icon(
          _danmakuUserEnabled ? Icons.visibility : Icons.visibility_off,
          color: Colors.white70,
          size: 18,
        ),
      ),
    );
  }

  Widget _TitleBarButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white70, size: 16),
      ),
    );
  }

  Widget _TitleBarCloseButton() {
    return GestureDetector(
      onTap: () async {
        await globalMiniPlayer?.dispose();
        globalMiniPlayer = null;
        await windowManager.setPreventClose(false);
        await windowManager.destroy();
      },
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: const Icon(Icons.close, color: Colors.white70, size: 18),
      ),
    );
  }

  void _toggleMaximize() {
    if (_isMaximized) {
      windowManager.unmaximize();
      _isMaximized = false;
    } else {
      windowManager.maximize();
      _isMaximized = true;
    }
    if (mounted) setState(() {});
  }
}
