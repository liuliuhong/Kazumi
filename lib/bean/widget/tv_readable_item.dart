import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/services/platform/tv_service.dart';

/// One visible reading target, without selectable-text caret focus traps.
class TvReadableItem extends StatelessWidget {
  const TvReadableItem({super.key, required this.child});
  final Widget child;
  KeyEventResult _read(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final down = event.logicalKey == LogicalKeyboardKey.arrowDown;
    final up = event.logicalKey == LogicalKeyboardKey.arrowUp;
    if (!down && !up) return KeyEventResult.ignored;
    final context = node.context;
    final box = context?.findRenderObject();
    final scrollable = context == null ? null : Scrollable.maybeOf(context);
    if (box is! RenderBox || scrollable == null) return KeyEventResult.ignored;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return KeyEventResult.ignored;
    final position = scrollable.position;
    final edge = viewport
        .getOffsetToReveal(box, down ? 1 : 0)
        .offset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((down && edge > position.pixels + 1) ||
        (up && edge < position.pixels - 1)) {
      final step = position.viewportDimension * .55;
      position.jumpTo(
        down
            ? (position.pixels + step).clamp(position.pixels, edge)
            : (position.pixels - step).clamp(edge, position.pixels),
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => TvService.isTelevision
      ? Focus(
          onKeyEvent: _read,
          child: ExcludeFocus(child: child),
        )
      : child;
}
