import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/tv_input_support.dart';
import 'package:kazumi/services/platform/tv_service.dart';

/// Up/Down stays within the rail, including at its first and last controls.
class TvNavigationRail extends StatefulWidget {
  const TvNavigationRail({super.key, required this.child});
  final Widget child;
  @override
  State<TvNavigationRail> createState() => _TvNavigationRailState();
}

class _TvNavigationRailState extends State<TvNavigationRail> {
  final _scope = FocusScopeNode(
    debugLabel: 'TV navigation rail',
    directionalTraversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
  );
  bool _move(TraversalDirection direction) {
    if (!TvService.isTelevision ||
        !_scope.hasFocus ||
        (direction != TraversalDirection.up &&
            direction != TraversalDirection.down)) {
      return false;
    }
    final nodes =
        _scope.traversalDescendants.where((n) => n is! FocusScopeNode).toList()
          ..sort((a, b) => a.rect.top.compareTo(b.rect.top));
    final index = nodes.indexOf(FocusManager.instance.primaryFocus!);
    if (index >= 0) {
      final next = (index + (direction == TraversalDirection.down ? 1 : -1))
          .clamp(0, nodes.length - 1);
      nodes[next].requestFocus();
    }
    return true;
  }

  @override
  void dispose() {
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusScope(
    node: _scope,
    child: TvDirectionalScope(onDirection: _move, child: widget.child),
  );
}
