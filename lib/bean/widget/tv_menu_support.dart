import 'package:flutter/widgets.dart';

/// MenuAnchor is an overlay, not a Navigator route. Coordinate its Back
/// handling with route-level handlers so one Back cannot also leave the page.
class TvMenuSupport {
  static final _handlers = <bool Function()>[];
  static bool _backConsumed = false;
  static bool get isOpen => _handlers.isNotEmpty;

  static void register(bool Function() handler) => _handlers.add(handler);
  static void unregister(bool Function() handler) => _handlers.remove(handler);

  static bool closeForBack() {
    if (_backConsumed) return true;
    for (final handler in List<bool Function()>.of(_handlers).reversed) {
      if (handler()) {
        _backConsumed = true;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _backConsumed = false,
        );
        return true;
      }
    }
    return false;
  }
}
