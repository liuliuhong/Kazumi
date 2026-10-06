import 'package:flutter/material.dart';
import 'package:kazumi/services/platform/tv_service.dart';

/// Restores the complete introduction when navigation returns to its controls.
class TvScrollTopOnFocus extends StatelessWidget {
  const TvScrollTopOnFocus({
    super.key,
    required this.controller,
    required this.child,
  });
  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onFocusChange: (focused) {
      if (!focused || !TvService.isTelevision) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && controller.hasClients) {
          controller.jumpTo(controller.position.minScrollExtent);
        }
      });
    },
    child: child,
  );
}
