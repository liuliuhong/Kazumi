import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/widget/tv_menu_support.dart';
import 'package:kazumi/services/platform/tv_service.dart';

/// TV sliders are navigation targets until Select explicitly starts editing.
class TvSettingsSlider extends StatefulWidget {
  const TvSettingsSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.label,
    this.padding,
  });
  final double value, min, max;
  final int? divisions;
  final String? label;
  final EdgeInsetsGeometry? padding;
  final ValueChanged<double> onChanged;
  @override
  State<TvSettingsSlider> createState() => TvSettingsSliderState();
}

class TvSettingsSliderState extends State<TvSettingsSlider> {
  final _focus = FocusNode(debugLabel: 'TV settings slider');
  bool _editing = false;
  bool _finish() {
    if (!_editing || !(ModalRoute.of(context)?.isCurrent ?? false)) {
      return false;
    }
    TvMenuSupport.unregister(_finish);
    setState(() => _editing = false);
    return true;
  }

  void _start() {
    if (_editing) return;
    _focus.requestFocus();
    TvMenuSupport.register(_finish);
    setState(() => _editing = true);
  }

  bool handleKey(KeyEvent event) {
    if (!_focus.hasPrimaryFocus) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.gameButtonA) {
      if (event is KeyDownEvent) _start();
      return true;
    }
    if (_editing) {
      if (key == LogicalKeyboardKey.escape) {
        _finish();
        return true;
      }
      if (key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight) {
        final step = (widget.max - widget.min) / (widget.divisions ?? 20);
        final value =
            (widget.value +
                    (key == LogicalKeyboardKey.arrowRight ? step : -step))
                .clamp(widget.min, widget.max)
                .toDouble();
        widget.onChanged(value);
        return true;
      }
      if (key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.arrowDown) {
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    TvMenuSupport.unregister(_finish);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slider = Slider(
      value: widget.value,
      min: widget.min,
      max: widget.max,
      divisions: widget.divisions,
      label: widget.label,
      showValueIndicator: ShowValueIndicator.never,
      padding: widget.padding,
      onChanged: widget.onChanged,
    );
    if (!TvService.isTelevision) return slider;
    return PopScope(
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _editing) TvMenuSupport.closeForBack();
      },
      child: Focus(
        focusNode: _focus,
        onFocusChange: (focused) {
          if (!focused && _editing) _finish();
        },
        child: GestureDetector(
          onTap: _start,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IgnorePointer(child: ExcludeFocus(child: slider)),
              Text(
                _editing ? '左右调整 · 返回结束调整' : '按确定调整',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _editing
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
