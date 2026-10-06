import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// D-pad shortcuts are active only while the playback controls are hidden.
/// Visible controls and other routes keep normal Flutter focus navigation.
class TvPlayerControls extends StatefulWidget {
  const TvPlayerControls({
    super.key,
    required this.playerFocus,
    required this.playing,
    required this.position,
    required this.duration,
    required this.onPlayPause,
    required this.onSeek,
    required this.onNext,
    required this.onPrevious,
    required this.onDanmaku,
    required this.onBack,
    this.onEpisodes,
  });

  final FocusNode playerFocus;
  final bool playing;
  final Duration position;
  final Duration duration;
  final Future<void> Function() onPlayPause;
  final Future<void> Function(Duration) onSeek;
  final Future<void> Function() onNext;
  final Future<void> Function() onPrevious;
  final VoidCallback onDanmaku;
  final VoidCallback onBack;
  final VoidCallback? onEpisodes;

  @override
  State<TvPlayerControls> createState() => _TvPlayerControlsState();
}

class _TvPlayerControlsState extends State<TvPlayerControls> {
  final _playFocus = FocusNode(debugLabel: 'TV play pause');
  final _controlsFocus = FocusScopeNode(
    debugLabel: 'TV playback controls',
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    directionalTraversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );
  bool _visible = true;
  bool _seeking = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addEarlyKeyEventHandler(_handleKey);
    _show();
  }

  bool get _ownsFocus {
    final focused = FocusManager.instance.primaryFocus;
    return focused == widget.playerFocus ||
        (focused?.ancestors.contains(widget.playerFocus) ?? false);
  }

  void _show() {
    if (!_visible) setState(() => _visible = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _visible && (ModalRoute.of(context)?.isCurrent ?? true)) {
        _playFocus.requestFocus();
      }
    });
    _restartTimer();
  }

  void _restartTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 8), () {
      if (mounted &&
          _visible &&
          _ownsFocus &&
          (ModalRoute.of(context)?.isCurrent ?? true)) {
        _hide();
      }
    });
  }

  void _hide() {
    _hideTimer?.cancel();
    setState(() => _visible = false);
    widget.playerFocus.requestFocus();
  }

  void _exitPlayback() {
    _hide();
    // Let PopScope publish canPop=true before requesting the route pop.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onBack();
    });
  }

  Future<void> _seek(int seconds) async {
    if (_seeking || widget.duration <= Duration.zero) return;
    _seeking = true;
    try {
      final target = (widget.position.inMilliseconds + seconds * 1000).clamp(
        0,
        widget.duration.inMilliseconds,
      );
      await widget.onSeek(Duration(milliseconds: target));
    } finally {
      _seeking = false;
    }
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (!_ownsFocus ||
        !(ModalRoute.of(context)?.isCurrent ?? true) ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.mediaPlayPause) {
      if (event is KeyDownEvent) unawaited(widget.onPlayPause());
      return KeyEventResult.handled;
    }
    final isConfirm =
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.gameButtonA;
    // A held remote button must not toggle again after revealing the controls.
    if (isConfirm && event is KeyRepeatEvent) return KeyEventResult.handled;
    if (_visible) {
      _restartTimer();
      // System Back normally reaches PopScope; Escape helps desktop testing.
      if (key == LogicalKeyboardKey.escape) {
        _hide();
        return KeyEventResult.handled;
      }
      final focused = FocusManager.instance.primaryFocus;
      if (!(focused?.ancestors.contains(_controlsFocus) ?? false) &&
          (key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.arrowLeft ||
              key == LogicalKeyboardKey.arrowRight ||
              key == LogicalKeyboardKey.arrowUp ||
              key == LogicalKeyboardKey.arrowDown)) {
        _playFocus.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      unawaited(_seek(key == LogicalKeyboardKey.arrowLeft ? -10 : 10));
      return KeyEventResult.handled;
    }
    if (isConfirm) {
      unawaited(widget.onPlayPause());
      _show();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      if (event is KeyDownEvent) _show();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_handleKey);
    _hideTimer?.cancel();
    _playFocus.dispose();
    _controlsFocus.dispose();
    super.dispose();
  }

  String _time(Duration value) {
    final seconds = value.inSeconds.clamp(0, 1 << 31);
    final minutes = seconds ~/ 60;
    return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_visible,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && _visible) _hide();
    },
    child: _visible
        ? FocusScope(
            node: _controlsFocus,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                color: const Color(0xEE15281F),
                child: SafeArea(
                  minimum: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${_time(widget.position)} / ${_time(widget.duration)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: widget.duration.inMilliseconds > 0
                            ? (widget.position.inMilliseconds /
                                      widget.duration.inMilliseconds)
                                  .clamp(0, 1)
                            : 0,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            focusNode: _playFocus,
                            onPressed: () => unawaited(widget.onPlayPause()),
                            icon: Icon(
                              widget.playing ? Icons.pause : Icons.play_arrow,
                            ),
                            label: Text(widget.playing ? '暂停' : '播放'),
                          ),
                          FilledButton(
                            onPressed: () => unawaited(_seek(-10)),
                            child: const Text('快退 10 秒'),
                          ),
                          FilledButton(
                            onPressed: () => unawaited(_seek(10)),
                            child: const Text('快进 10 秒'),
                          ),
                          FilledButton(
                            onPressed: () => unawaited(widget.onPrevious()),
                            child: const Text('上一集'),
                          ),
                          FilledButton(
                            onPressed: () => unawaited(widget.onNext()),
                            child: const Text('下一集'),
                          ),
                          if (widget.onEpisodes != null)
                            FilledButton(
                              onPressed: () {
                                _hide();
                                widget.onEpisodes!();
                              },
                              child: const Text('选集 / 线路'),
                            ),
                          FilledButton(
                            onPressed: widget.onDanmaku,
                            child: const Text('开关弹幕'),
                          ),
                          FilledButton(
                            onPressed: _exitPlayback,
                            child: const Text('退出播放'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '方向键选择 · 确定执行 · 返回隐藏控制栏 · 隐藏后确定播放/暂停，左右快进快退',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        : const SizedBox.shrink(),
  );
}
