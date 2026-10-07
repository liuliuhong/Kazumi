import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/tv_input_support.dart';
import 'package:kazumi/services/platform/tv_service.dart';

/// Connects scrolling content to its fixed action without losing the last row.
class TvContentActionNavigation {
  final action = FocusNode(debugLabel: 'TV fixed action');
  final _content = FocusNode(canRequestFocus: false, skipTraversal: true);
  FocusNode? _previous;

  void focusTopContent() {
    _previous = null;
    final nodes =
        _content.traversalDescendants
            .where((n) => n is! FocusScopeNode)
            .toList()
          ..sort(
            (a, b) => a.rect.top == b.rect.top
                ? a.rect.left.compareTo(b.rect.left)
                : a.rect.top.compareTo(b.rect.top),
          );
    if (nodes.isNotEmpty) nodes.first.requestFocus();
  }

  Widget content(Widget child, {bool onlyAtRightEdge = false}) => Focus(
    focusNode: _content,
    child: TvDirectionalScope(
      onDirection: (direction) {
        if (!TvService.isTelevision || direction != TraversalDirection.right) {
          return false;
        }
        final current = FocusManager.instance.primaryFocus;
        if (current == null || current is FocusScopeNode) return false;
        if (onlyAtRightEdge && _hasRightNeighbour(current)) return false;
        _previous = current;
        action.requestFocus();
        return true;
      },
      child: child,
    ),
  );

  bool _hasRightNeighbour(FocusNode current) {
    final box = current.context?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final center = box.localToGlobal(box.size.center(Offset.zero));
    for (final node in _content.traversalDescendants) {
      if (node == current || node is FocusScopeNode) continue;
      final other = node.context?.findRenderObject();
      if (other is! RenderBox || !other.attached || !other.hasSize) continue;
      final point = other.localToGlobal(other.size.center(Offset.zero));
      if (point.dx > center.dx + 1 &&
          (point.dy - center.dy).abs() < box.size.height / 2) {
        return true;
      }
    }
    return false;
  }

  Widget fixedAction(Widget child) => TvDirectionalScope(
    onDirection: (direction) {
      if (!TvService.isTelevision || direction != TraversalDirection.left) {
        return false;
      }
      if (_previous?.context != null && _previous!.canRequestFocus) {
        _previous!.requestFocus();
      } else {
        final nodes = _content.traversalDescendants.where(
          (n) => n is! FocusScopeNode,
        );
        if (nodes.isNotEmpty) nodes.first.requestFocus();
      }
      return true;
    },
    child: child,
  );

  void dispose() {
    action.dispose();
    _content.dispose();
  }
}
