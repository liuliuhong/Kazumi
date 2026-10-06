import 'package:flutter/material.dart';
import 'package:kazumi/services/platform/tv_service.dart';
import 'package:kazumi/bean/widget/tv_menu_support.dart';

typedef KazumiMenuBuilder =
    Widget Function(BuildContext context, VoidCallback? toggle);

const _menuItemStyle = ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size(144, 48)),
  padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
  alignment: AlignmentDirectional.centerStart,
  visualDensity: VisualDensity.standard,
);

class KazumiMenuButton extends StatefulWidget {
  const KazumiMenuButton({
    super.key,
    required this.builder,
    required this.menuChildren,
    this.controller,
    this.enabled = true,
    this.animated = false,
    this.crossAxisUnconstrained = true,
    this.onOpen,
    this.onClose,
    this.style,
  });

  final KazumiMenuBuilder builder;
  final List<Widget> menuChildren;
  final MenuController? controller;
  final bool enabled;

  /// Opt in only for menus that previously animated.
  final bool animated;
  final bool crossAxisUnconstrained;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;
  final MenuStyle? style;

  @override
  State<KazumiMenuButton> createState() => _KazumiMenuButtonState();
}

class _KazumiMenuButtonState extends State<KazumiMenuButton> {
  final _ownedController = MenuController();
  final _menuFocus = FocusScopeNode(debugLabel: 'TV popup menu');
  FocusNode? _opener;
  bool _open = false;
  MenuController get _controller => widget.controller ?? _ownedController;

  bool _closeForBack() {
    if (!_open || !(ModalRoute.of(context)?.isCurrent ?? false)) return false;
    _controller.close();
    return true;
  }

  void _onOpen() {
    if (TvService.isTelevision && !_open) {
      _opener = FocusManager.instance.primaryFocus;
      TvMenuSupport.register(_closeForBack);
      setState(() => _open = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_open) return;
        final items = _menuFocus.traversalDescendants.where(
          (node) => node is! FocusScopeNode,
        );
        if (items.isNotEmpty) items.first.requestFocus();
      });
    }
    widget.onOpen?.call();
  }

  void _onClose() {
    TvMenuSupport.unregister(_closeForBack);
    if (mounted && _open) setState(() => _open = false);
    if (TvService.isTelevision && _opener?.context != null) {
      _opener!.requestFocus();
    }
    widget.onClose?.call();
  }

  @override
  void dispose() {
    TvMenuSupport.unregister(_closeForBack);
    _menuFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !TvService.isTelevision || !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _open) TvMenuSupport.closeForBack();
      },
      child: MenuButtonTheme(
        data: MenuButtonThemeData(
          // Submenu entries must use the same inset as ordinary menu items.
          style: _menuItemStyle.merge(MenuButtonTheme.of(context).style),
        ),
        child: MenuAnchor(
          controller: _controller,
          consumeOutsideTap: true,
          crossAxisUnconstrained: widget.crossAxisUnconstrained,
          animated: widget.animated && !MediaQuery.disableAnimationsOf(context),
          onOpen: _onOpen,
          onClose: _onClose,
          style: widget.style,
          menuChildren: TvService.isTelevision
              ? [
                  FocusScope(
                    node: _menuFocus,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: widget.menuChildren,
                    ),
                  ),
                ]
              : widget.menuChildren,
          builder: (context, controller, _) => widget.builder(
            context,
            widget.enabled && widget.menuChildren.isNotEmpty
                ? () =>
                      controller.isOpen ? controller.close() : controller.open()
                : null,
          ),
        ),
      ),
    );
  }
}

class KazumiMenuItem extends StatelessWidget {
  const KazumiMenuItem({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.selected,
    this.destructive = false,
    this.requestFocusOnHover = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leadingIcon;

  /// Null for actions; a bool exposes single-choice selection semantics.
  final bool? selected;
  final bool destructive;
  final bool requestFocusOnHover;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = destructive
        ? colors.error
        : selected == true
        ? colors.primary
        : null;
    final foregroundColor = color == null
        ? null
        : WidgetStateProperty.resolveWith<Color?>(
            (states) => states.contains(WidgetState.disabled) ? null : color,
          );
    return MenuItemButton(
      onPressed: onPressed,
      requestFocusOnHover: requestFocusOnHover,
      style: ButtonStyle(
        foregroundColor: foregroundColor,
        iconColor: foregroundColor,
      ),
      leadingIcon: leadingIcon,
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: selected == null ? null : true,
        child: Text(label, textAlign: TextAlign.start),
      ),
    );
  }
}
