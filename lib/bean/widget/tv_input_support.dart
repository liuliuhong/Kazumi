import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/services/platform/tv_service.dart';
import 'package:kazumi/bean/widget/tv_menu_support.dart';
import 'package:kazumi/bean/widget/tv_settings_slider.dart';

/// Retains a shortcut ancestor without making its full-page rectangle a TV
/// navigation target. Its buttons and inputs remain focusable.
class TvShortcutFocus extends StatelessWidget {
  const TvShortcutFocus({
    super.key,
    required this.focusNode,
    required this.child,
  });
  final FocusNode focusNode;
  final Widget child;

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: focusNode,
    canRequestFocus: !TvService.isTelevision,
    skipTraversal: TvService.isTelevision,
    autofocus: !TvService.isTelevision,
    child: child,
  );
}

/// Cross-pane navigation must also work across nested Navigator focus scopes.
class TvDirectionalScope extends InheritedWidget {
  const TvDirectionalScope({
    super.key,
    required this.onDirection,
    required super.child,
  });
  final bool Function(TraversalDirection) onDirection;
  @override
  bool updateShouldNotify(TvDirectionalScope oldWidget) =>
      onDirection != oldWidget.onDirection;
}

class TvInputSupport {
  static bool _opening = false;
  static EditableTextState? get focusedEditor => FocusManager
      .instance
      .primaryFocus
      ?.context
      ?.findAncestorStateOfType<EditableTextState>();

  static bool leaveInput() {
    final editor = focusedEditor;
    if (!TvService.isTelevision || editor == null) return false;
    editor.widget.focusNode.unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    return true;
  }

  static KeyEventResult handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final focused = FocusManager.instance.primaryFocus;
    final slider = focused?.context
        ?.findAncestorStateOfType<TvSettingsSliderState>();
    if (slider != null && slider.handleKey(event)) {
      return KeyEventResult.handled;
    }
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => TraversalDirection.up,
      LogicalKeyboardKey.arrowDown => TraversalDirection.down,
      LogicalKeyboardKey.arrowLeft => TraversalDirection.left,
      LogicalKeyboardKey.arrowRight => TraversalDirection.right,
      _ => null,
    };
    if (direction != null &&
        !TvMenuSupport.isOpen &&
        (focused?.context
                ?.findAncestorWidgetOfExactType<TvDirectionalScope>()
                ?.onDirection(direction) ??
            false)) {
      return KeyEventResult.handled;
    }
    final editor = focusedEditor;
    if (editor == null) return KeyEventResult.ignored;
    if (direction != null) {
      // EditableText normally consumes these to move its caret. On TV, the
      // caret belongs to the native input dialog opened with Select instead.
      focused!.focusInDirection(direction);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA) {
      if (event is KeyDownEvent && !_opening && !editor.widget.readOnly) {
        _edit(editor);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  static Future<void> _edit(EditableTextState editor) async {
    _opening = true;
    try {
      final field = editor.context.findAncestorWidgetOfExactType<TextField>();
      final value = await TvService.textInput(
        editor.widget.controller.text,
        title:
            field?.decoration?.labelText ??
            field?.decoration?.hintText ??
            '输入文本',
        obscure: editor.widget.obscureText,
        numeric: editor.widget.keyboardType == TextInputType.number,
      );
      if (!editor.mounted) return;
      if (value != null) {
        editor.widget.controller.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
        editor.widget.onChanged?.call(value);
        editor.widget.onSubmitted?.call(value);
      }
      // Cancelling editing returns to the same page, with no active input.
      if (editor.mounted) editor.widget.focusNode.unfocus();
    } finally {
      _opening = false;
    }
  }
}

/// The first system Back leaves a selected input; the next leaves its route.
class TvInputGuard extends StatefulWidget {
  const TvInputGuard({super.key, required this.child});
  final Widget child;
  @override
  State<TvInputGuard> createState() => _TvInputGuardState();
}

class _TvInputGuardState extends State<TvInputGuard> {
  bool _inputFocused = false;
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_focusChanged);
  }

  void _focusChanged() {
    final editor = TvInputSupport.focusedEditor;
    final focused =
        TvService.isTelevision &&
        editor != null &&
        editor.context.findAncestorStateOfType<_TvInputGuardState>() == this;
    if (mounted && focused != _inputFocused) {
      setState(() => _inputFocused = focused);
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_focusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_inputFocused,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && _inputFocused) TvInputSupport.leaveInput();
    },
    child: widget.child,
  );
}
