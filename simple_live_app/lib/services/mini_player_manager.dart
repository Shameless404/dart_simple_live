import 'dart:collection';
import 'dart:io';

class MiniPlayerManager {
  static final MiniPlayerManager instance = MiniPlayerManager._();
  MiniPlayerManager._();

  final List<Process> _processes = [];
  final Queue<int> _freed = Queue<int>();
  int _nextIdx = 0;

  int nextIndex() {
    if (_freed.isNotEmpty) return _freed.removeFirst();
    return _nextIdx++;
  }

  void register(Process p, int idx) {
    _processes.add(p);
    p.exitCode.whenComplete(() => _freed.add(idx));
  }

  void killAll() {
    for (final p in List<Process>.from(_processes)) {
      try {
        p.kill();
      } catch (_) {}
    }
    _processes.clear();
    _freed.clear();
    _nextIdx = 0;
  }
}
