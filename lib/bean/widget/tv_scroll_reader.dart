import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A reading target for long, lazily built text lists without action buttons.
class TvScrollReader extends StatefulWidget {
  const TvScrollReader({super.key, required this.controller});
  final ScrollController controller;
  @override
  State<TvScrollReader> createState() => _TvScrollReaderState();
}

class _TvScrollReaderState extends State<TvScrollReader> {
  final _focus = FocusNode(debugLabel: 'TV comment reader');
  KeyEventResult _handle(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final controller = widget.controller;
    if (!controller.hasClients) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      final position = controller.position;
      if (key == LogicalKeyboardKey.arrowUp &&
          position.pixels <= position.minScrollExtent) {
        node.focusInDirection(TraversalDirection.up);
      } else {
        final step = position.viewportDimension * .55;
        final offset =
            (position.pixels +
                    (key == LogicalKeyboardKey.arrowDown ? step : -step))
                .clamp(position.minScrollExtent, position.maxScrollExtent)
                .toDouble();
        controller.jumpTo(offset);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.gameButtonA) {
      // Move to a visible link/reply button when the reader wants to expand it.
      node.nextFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _focus,
    onKeyEvent: _handle,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text('阅读评论 · 上下滚动', style: Theme.of(context).textTheme.labelLarge),
    ),
  );
}
