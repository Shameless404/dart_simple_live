import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:simple_live_core/simple_live_core.dart';
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
  bool _isPinned = false;

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
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.push_pin,
          color: _isPinned ? Colors.amber : Colors.white70,
          size: 20,
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
  bool _danmakuVisible = false;
  bool _controlsVisible = false;
  bool _isPlaying = false;
  double _volume = 100;
  bool _isFullscreen = false;
  late double _danmuSize;

  @override
  void initState() {
    super.initState();
    _danmuSize = widget.args.danmuSize;
    player = Player(
      configuration: const PlayerConfiguration(
        title: 'Simple Live Player',
        logLevel: MPVLogLevel.error,
      ),
    );
    globalMiniPlayer = player;
    videoController = VideoController(player);
    _volume = player.state.volume;
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  @override
  void dispose() {
    globalMiniPlayer = null;
    liveDanmaku?.stop();
    player.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    if (widget.args.streamUrl.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 100));
      await player.open(Media(
        widget.args.streamUrl,
        httpHeaders: widget.args.streamHeaders,
      ));
      await player.play();
      _isPlaying = true;
      if (mounted) setState(() {});
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
      await player.open(Media(
        playUrl.urls[0],
        httpHeaders: playUrl.headers,
      ));
      await player.play();
      _isPlaying = true;
      if (mounted) setState(() {});
    } catch (e) { debugPrint('MiniPlayer: _resolveDouyinAndPlay error: $e'); }
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
      final c = msg.color;
      final color = Color.fromARGB(255, c.r, c.g, c.b);
      final item = DanmakuContentItem(
        msg.message,
        color: color,
        type: DanmakuItemType.scroll,
      );
      danmakuController?.addDanmaku(item);
    };
  }

  void _toggleDanmaku() {
    if (liveDanmaku != null) {
      liveDanmaku!.stop();
      liveDanmaku = null;
      danmakuController = null;
      setState(() => _danmakuVisible = false);
    } else {
      setState(() => _danmakuVisible = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _danmakuVisible) _connectDanmaku();
      });
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      player.pause();
      setState(() => _isPlaying = false);
    } else {
      player.play();
      setState(() => _isPlaying = true);
    }
  }

  void _toggleFullscreen() {
    _isFullscreen = !_isFullscreen;
    windowManager.setFullScreen(_isFullscreen);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: MouseRegion(
        onEnter: (_) {
          if (mounted) setState(() => _controlsVisible = true);
        },
        onExit: (_) {
          if (mounted) setState(() => _controlsVisible = false);
        },
        child: Stack(
          children: [
            Video(
              controller: videoController,
              fill: Colors.black,
              controls: null,
              wakelock: false,
            ),
            if (_danmakuVisible)
              Positioned.fill(
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
                ),
              ),
            if (_controlsVisible)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildControlsBar(),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDanmakuToggle(),
                  const SizedBox(width: 8),
                  const _PinToggleButton(),
                ],
              ),
            ),
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
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _danmakuVisible ? Icons.visibility : Icons.visibility_off,
          color: Colors.white70,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildControlsBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 24,
            ),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
            onPressed: _togglePlayPause,
          ),
          _buildVolumeControl(),
          const Spacer(),
          IconButton(
            icon: Icon(
              _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
              color: Colors.white,
              size: 24,
            ),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
            onPressed: _toggleFullscreen,
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeControl() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            _volume > 0 ? Icons.volume_up : Icons.volume_off,
            color: Colors.white,
            size: 20,
          ),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
          onPressed: () {
            final newVol = _volume > 0 ? 0.0 : 100.0;
            player.setVolume(newVol);
            setState(() => _volume = newVol);
          },
        ),
        SizedBox(
          width: 100,
          child: SliderTheme(
            data: const SliderThemeData(
              trackHeight: 3,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white38,
              thumbColor: Colors.white,
              overlayColor: Colors.white24,
            ),
            child: Slider(
              value: _volume,
              min: 0,
              max: 100,
              onChanged: (v) {
                player.setVolume(v);
                setState(() => _volume = v);
              },
            ),
          ),
        ),
      ],
    );
  }
}
