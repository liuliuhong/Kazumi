import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/kazumi_menu.dart';
import 'package:kazumi/bean/widget/tv_menu_support.dart';

void main() {
  testWidgets(
    'system Back closes an open overlay menu without also leaving its shell page',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      var pageBacks = 0;
      var closes = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && !TvMenuSupport.closeForBack()) pageBacks++;
            },
            child: Scaffold(
              body: KazumiMenuButton(
                onClose: () => closes++,
                builder: (_, toggle) =>
                    TextButton(onPressed: toggle, child: const Text('Status')),
                menuChildren: [
                  MenuItemButton(
                    onPressed: () {},
                    child: const Text('Watching'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Status'));
      await tester.pumpAndSettle();
      expect(find.text('Watching'), findsOneWidget);
      expect(
        FocusManager.instance.primaryFocus!.context!
            .findAncestorWidgetOfExactType<MenuItemButton>(),
        isNotNull,
      );
      await tester.sendKeyEvent(
        LogicalKeyboardKey.goBack,
        physicalKey: PhysicalKeyboardKey.escape,
      );
      await tester.pump();
      await navigator.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('Watching'), findsNothing);
      expect(closes, 1);
      expect(pageBacks, 0);
      await navigator.currentState!.maybePop();
      await tester.pump();
      expect(pageBacks, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
