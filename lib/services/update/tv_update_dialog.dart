import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tv_update_controller.dart';

/// All actions stay inside this dialog's route and restore the opener on close.
class TvUpdateDialog extends StatefulWidget {
  const TvUpdateDialog({
    super.key,
    required this.controller,
    required this.onClose,
    required this.onSkip,
  });
  final TvUpdateController controller;
  final VoidCallback onClose;
  final Future<void> Function(int) onSkip;
  @override
  State<TvUpdateDialog> createState() => _TvUpdateDialogState();
}

class _TvUpdateDialogState extends State<TvUpdateDialog> {
  final _safeAction = FocusNode(debugLabel: 'TV update safe action');
  final _notes = ScrollController();
  bool _confirmingCancel = false;
  TvUpdateStage? _previous;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _changed();
  }

  void _changed() {
    if (!mounted) return;
    final stage = widget.controller.stage;
    setState(() {});
    if (stage != _previous) {
      _previous = stage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _safeAction.context != null &&
            _safeAction.canRequestFocus) {
          _safeAction.requestFocus();
        }
      });
    }
  }

  Future<void> _close() async {
    final stage = widget.controller.stage;
    if (stage == TvUpdateStage.installing) return;
    if (stage != TvUpdateStage.downloading &&
        stage != TvUpdateStage.verifying) {
      widget.onClose();
      return;
    }
    if (_confirmingCancel) return;
    _confirmingCancel = true;
    final cancel = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('取消更新下载？'),
        content: const Text('尚未下载完成的文件会清理，之后可以重新下载。'),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续下载'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('取消下载'),
          ),
        ],
      ),
    );
    _confirmingCancel = false;
    if (mounted &&
        cancel == true &&
        (widget.controller.stage == TvUpdateStage.downloading ||
            widget.controller.stage == TvUpdateStage.verifying)) {
      widget.controller.cancelDownload();
    }
  }

  KeyEventResult _readNotes(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.arrowUp &&
        event.logicalKey != LogicalKeyboardKey.arrowDown) {
      return KeyEventResult.ignored;
    }
    if (!_notes.hasClients) return KeyEventResult.ignored;
    final down = event.logicalKey == LogicalKeyboardKey.arrowDown;
    final position = _notes.position;
    if ((!down && position.pixels <= 0) ||
        (down && position.pixels >= position.maxScrollExtent)) {
      _safeAction.requestFocus();
    } else {
      _notes.jumpTo(
        (position.pixels + (down ? 120 : -120))
            .clamp(0, position.maxScrollExtent)
            .toDouble(),
      );
    }
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _safeAction.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final update = c.update;
    final content = <Widget>[
      if (c.current != null) Text('当前版本：${c.current!.name}'),
      if (update != null) ...[
        Text('新版本：${update.versionName}'),
        Text('安装包：${(update.size / 1048576).toStringAsFixed(1)} MB'),
      ],
      const SizedBox(height: 12),
    ];
    final actions = <Widget>[];
    switch (c.stage) {
      case TvUpdateStage.checking:
        content.add(const LinearProgressIndicator());
        content.add(const Text('正在检查社区 TV 正式版…'));
        actions.add(
          TextButton(
            focusNode: _safeAction,
            onPressed: widget.onClose,
            child: const Text('取消'),
          ),
        );
      case TvUpdateStage.current:
        content.add(
          Text(
            c.checkedFromCache ? '当前无需更新（使用最近 5 分钟内的检查结果）。' : '当前已经是最新 TV 版本。',
          ),
        );
        actions.add(
          TextButton(
            focusNode: _safeAction,
            onPressed: widget.onClose,
            child: const Text('关闭'),
          ),
        );
      case TvUpdateStage.offer:
        content.add(const Text('更新说明 · 聚焦后上下滚动'));
        content.add(
          Focus(
            onKeyEvent: _readNotes,
            child: SizedBox(
              height: 150,
              child: SingleChildScrollView(
                controller: _notes,
                child: Text(
                  update!.notes.isEmpty ? '维护者未提供更新说明。' : update.notes,
                ),
              ),
            ),
          ),
        );
        actions.addAll([
          TextButton(
            onPressed: () async {
              await widget.onSkip(update.versionCode);
              if (mounted) widget.onClose();
            },
            child: const Text('跳过此版本'),
          ),
          TextButton(
            focusNode: _safeAction,
            onPressed: widget.onClose,
            child: const Text('稍后提醒'),
          ),
          FilledButton(onPressed: c.download, child: const Text('下载更新')),
        ]);
      case TvUpdateStage.downloading:
      case TvUpdateStage.verifying:
        content.add(
          LinearProgressIndicator(
            value:
                c.stage == TvUpdateStage.verifying || c.received >= update!.size
                ? null
                : (c.received / update.size).clamp(0, 1).toDouble(),
          ),
        );
        content.add(
          Text(
            c.stage == TvUpdateStage.verifying
                ? '正在验证 APK 包名、版本、签名和 CPU 架构…'
                : c.received >= update!.size
                ? '下载完成，正在校验文件 SHA-256…'
                : '已下载 ${(c.received / 1048576).toStringAsFixed(1)} MB / ${(update.size / 1048576).toStringAsFixed(1)} MB',
          ),
        );
        actions.add(
          TextButton(
            focusNode: _safeAction,
            onPressed: _close,
            child: const Text('取消下载'),
          ),
        );
      case TvUpdateStage.ready:
        content.add(const Text('下载与校验完成。确认后进入系统安装界面，覆盖安装会保留应用数据。'));
        actions.addAll([
          TextButton(
            focusNode: _safeAction,
            onPressed: widget.onClose,
            child: const Text('稍后安装'),
          ),
          FilledButton(onPressed: c.install, child: const Text('立即安装')),
        ]);
      case TvUpdateStage.permission:
        content.add(
          const Text('请在系统设置中允许 Kazumi TV 安装未知来源应用。返回后再次选择安装；取消授权不会删除安装包。'),
        );
        actions.addAll([
          TextButton(
            focusNode: _safeAction,
            onPressed: widget.onClose,
            child: const Text('稍后安装'),
          ),
          TextButton(onPressed: c.openPermission, child: const Text('去授权')),
          FilledButton(onPressed: c.install, child: const Text('已授权，继续安装')),
        ]);
      case TvUpdateStage.installing:
        content.add(const LinearProgressIndicator());
        content.add(const Text('正在复核安装包并打开系统安装界面…'));
      case TvUpdateStage.error:
        content.add(Text(c.error ?? '更新失败，请重试'));
        actions.addAll([
          TextButton(
            focusNode: _safeAction,
            onPressed: widget.onClose,
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: c.update == null
                ? c.check
                : c.path == null
                ? c.download
                : c.install,
            child: const Text('重试'),
          ),
        ]);
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: AlertDialog(
        title: const Text('Kazumi TV 应用更新'),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: content,
            ),
          ),
        ),
        actions: actions,
      ),
    );
  }
}
