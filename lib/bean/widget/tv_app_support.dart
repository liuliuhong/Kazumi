import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/widget/tv_input_support.dart';

/// Adds a visible focus ring to existing controls, including dialogs and menus.
class TvAppSupport extends StatefulWidget {
  const TvAppSupport({super.key, required this.child});
  final Widget child;

  @override
  State<TvAppSupport> createState() => _TvAppSupportState();
}

class _TvAppSupportState extends State<TvAppSupport> {
  final _surfaceKey = GlobalKey();
  Rect? _focusRect;
  bool _updateScheduled = false;
  late final FocusHighlightStrategy _previousStrategy;

  @override
  void initState() {
    super.initState();
    _previousStrategy = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    FocusManager.instance.addListener(_focusChanged);
    FocusManager.instance.addEarlyKeyEventHandler(TvInputSupport.handleKey);
    _scheduleUpdate();
  }

  void _focusChanged() {
    if (TvInputSupport.focusedEditor != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      });
    }
    final focused = FocusManager.instance.primaryFocus;
    final focusContext = focused?.context;
    if (focusContext != null &&
        focused is! FocusScopeNode &&
        focused?.debugLabel != 'Video player shortcut scope') {
      Scrollable.ensureVisible(
        focusContext,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
      final box = focusContext.findRenderObject();
      final scrollable = Scrollable.maybeOf(focusContext);
      if (box is! RenderBox ||
          scrollable == null ||
          box.size.height <= scrollable.position.viewportDimension) {
        Scrollable.ensureVisible(
          focusContext,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    }
    _scheduleUpdate();
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _scheduleUpdate() {
    if (_updateScheduled) return;
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (!mounted) return;
      final focused = FocusManager.instance.primaryFocus;
      final target = focused?.context?.findRenderObject();
      final surface = _surfaceKey.currentContext?.findRenderObject();
      Rect? rect;
      if (focused is! FocusScopeNode &&
          focused?.debugLabel != 'Video player shortcut scope' &&
          target is RenderBox &&
          target.attached &&
          target.hasSize &&
          surface is RenderBox &&
          surface.hasSize) {
        final offset = surface.globalToLocal(target.localToGlobal(Offset.zero));
        rect = (offset & target.size).intersect(Offset.zero & surface.size);
        if (rect.isEmpty) rect = null;
        // Native video surfaces can own a focus node covering the entire
        // screen. Only interactive controls should receive a visible ring.
        if (rect != null &&
            rect.width >= surface.size.width * .95 &&
            rect.height >= surface.size.height * .95) {
          rect = null;
        }
      }
      if (_focusRect != rect) setState(() => _focusRect = rect);
      // Observe existing animation frames without scheduling idle frames.
      _scheduleUpdate();
    });
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_focusChanged);
    FocusManager.instance.removeEarlyKeyEventHandler(TvInputSupport.handleKey);
    FocusManager.instance.highlightStrategy = _previousStrategy;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
    },
    child: NotificationListener<ScrollNotification>(
      onNotification: (_) {
        _scheduleUpdate();
        return false;
      },
      child: Stack(
        key: _surfaceKey,
        fit: StackFit.expand,
        children: [
          widget.child,
          if (_focusRect case final rect?)
            Positioned.fromRect(
              rect: rect,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF9CDBB2),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
