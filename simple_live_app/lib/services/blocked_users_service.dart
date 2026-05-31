import 'dart:convert';
import 'dart:io';

class BlockedUserEntry {
  final String key;
  final String userName;
  final String anchorName;
  final String platform;
  final String message;
  final int timestamp;

  BlockedUserEntry({
    String? key,
    required this.userName,
    required this.anchorName,
    required this.platform,
    required this.message,
    required this.timestamp,
  }) : key = key ?? '$platform:$userName';

  Map<String, dynamic> toJson() => {
        'key': key,
        'userName': userName,
        'anchorName': anchorName,
        'platform': platform,
        'message': message,
        'timestamp': timestamp,
      };

  factory BlockedUserEntry.fromJson(Map<String, dynamic> json) =>
      BlockedUserEntry(
        key: json['key'] as String?,
        userName: json['userName'] as String,
        anchorName: json['anchorName'] as String? ?? '',
        platform: json['platform'] as String,
        message: json['message'] as String? ?? '',
        timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      );
}

class BlockedUsersService {
  BlockedUsersService._();
  static final instance = BlockedUsersService._();

  Map<String, BlockedUserEntry> _entries = {};
  File? _file;

  String get _filePath {
    final exePath = Platform.resolvedExecutable;
    final dir = File(exePath).parent.path;
    return '$dir/blocked_users.json';
  }

  void init() {
    _file = File(_filePath);
    if (!_file!.existsSync()) {
      _file!.writeAsStringSync('');
    }
    _load();
  }

  void reload() {
    _load();
  }

  void _load() {
    try {
      if (_file == null || !_file!.existsSync()) {
        _entries = {};
        return;
      }
      final raw = _file!.readAsStringSync().trim();
      if (raw.isEmpty) {
        _entries = {};
        return;
      }
      _entries = {};
      for (final line in raw.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        try {
          final decoded = jsonDecode(trimmed) as Map<String, dynamic>;
          final entry = BlockedUserEntry.fromJson(decoded);
          _entries[entry.key] = entry;
        } catch (_) {}
      }
    } catch (_) {
      _entries = {};
    }
  }

  void _save() {
    try {
      final lines = _entries.values.map((e) => jsonEncode(e.toJson()));
      _file?.writeAsStringSync(lines.join('\n'));
    } catch (_) {}
  }

  bool isBlocked(String platform, String userName) {
    return _entries.containsKey('$platform:$userName');
  }

  void block(String platform, String userName, String message, {String anchorName = ''}) {
    final entry = BlockedUserEntry(
      userName: userName,
      anchorName: anchorName,
      platform: platform,
      message: message,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    _entries[entry.key] = entry;
    try {
      _file!.writeAsStringSync('\n${jsonEncode(entry.toJson())}',
          mode: FileMode.append);
    } catch (_) {}
  }

  void unblock(String platform, String userName) {
    _entries.remove('$platform:$userName');
    _save();
  }

  List<BlockedUserEntry> get entries => _entries.values.toList()
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  int get count => _entries.length;
}
