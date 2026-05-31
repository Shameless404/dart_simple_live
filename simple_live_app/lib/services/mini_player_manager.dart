import 'dart:io';

class MiniPlayerManager {
  static final MiniPlayerManager instance = MiniPlayerManager._();
  MiniPlayerManager._();

  final List<Process> _processes = [];

  void register(Process p) {
    _processes.add(p);
    p.exitCode.whenComplete(() => _processes.remove(p));
  }

  void killAll() {
    for (final p in List<Process>.from(_processes)) {
      try {
        p.kill();
      } catch (_) {}
    }
    _processes.clear();
  }
}
