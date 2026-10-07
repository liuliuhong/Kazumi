import 'package:flutter/material.dart';
import 'package:kazumi/services/platform/tv_service.dart';

/// Restore introductory content when focus returns to the first control row.
/// This wrapper itself never becomes a navigation target.
class TvScrollBoundary extends StatefulWidget {
  const TvScrollBoundary({super.key, required this.child});
  final Widget child;
  @override
  State<TvScrollBoundary> createState() => _TvScrollBoundaryState();
}

class _TvScrollBoundaryState extends State<TvScrollBoundary> {
  final _boundary = FocusNode(skipTraversal: true, canRequestFocus: false);
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_changed);
  }

  void _changed() {
    if (!TvService.isTelevision) return;
    final focused = FocusManager.instance.primaryFocus;
    if (focused == null || !focused.ancestors.contains(_boundary)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || FocusManager.instance.primaryFocus != focused) return;
      final target = focused.context?.findRenderObject();
      final scrollable = focused.context == null
          ? null
          : Scrollable.maybeOf(focused.context!);
      if (target is! RenderBox || !target.attached || scrollable == null) {
        return;
      }
      final position = scrollable.position;
      if (position.pixels <= position.minScrollExtent) return;
      final targetY = target.localToGlobal(Offset.zero).dy;
      for (final node in _boundary.traversalDescendants) {
        if (node == focused || node is FocusScopeNode || node.context == null) {
          continue;
        }
        if (Scrollable.maybeOf(node.context!) != scrollable) continue;
        final box = node.context!.findRenderObject();
        if (box is RenderBox &&
            box.attached &&
            box.hasSize &&
            box.localToGlobal(Offset.zero).dy < targetY - 1) {
          return;
        }
      }
      position.jumpTo(position.minScrollExtent);
    });
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_changed);
    _boundary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Focus(focusNode: _boundary, child: widget.child);
}
