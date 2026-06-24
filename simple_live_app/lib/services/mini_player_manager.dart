import 'dart:io';

class MiniPlayerManager {
  static final MiniPlayerManager instance = MiniPlayerManager._();
  MiniPlayerManager._();

  final List<Process> _processes = [];
  int _nextIdx = 0;

  int nextIndex() {
    return _nextIdx++;
  }

  void register(Process p, int idx) {
    _processes.add(p);
  }

  void killAll() {
    for (final p in List<Process>.from(_processes)) {
      try {
        p.kill();
      } catch (_) {}
    }
    _processes.clear();
    _nextIdx = 0;
  }
}
