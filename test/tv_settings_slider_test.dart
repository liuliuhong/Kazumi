import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/tv_app_support.dart';
import 'package:kazumi/bean/widget/tv_input_support.dart';
import 'package:kazumi/bean/widget/tv_menu_support.dart';
import 'package:kazumi/bean/widget/tv_settings_slider.dart';

void main() {
  testWidgets(
    'slider navigation does not change values; Select edits, Back stops editing before page Back',
    (tester) async {
      var value = 5.0;
      var pageBacks = 0;
      var railMoves = 0;
      final navigator = GlobalKey<NavigatorState>();
      final before = FocusNode();
      final after = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (_, child) => TvAppSupport(child: child!),
          home: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && !TvMenuSupport.closeForBack()) pageBacks++;
            },
            child: Scaffold(
              body: StatefulBuilder(
                builder: (_, setState) => TvDirectionalScope(
                  onDirection: (direction) {
                    if (direction == TraversalDirection.left) {
                      railMoves++;
                      before.requestFocus();
                      return true;
                    }
                    return false;
                  },
                  child: Column(
                    children: [
                      TextButton(
                        focusNode: before,
                        autofocus: true,
                        onPressed: () {},
                        child: const Text('Before'),
                      ),
                      TvSettingsSlider(
                        value: value,
                        min: 0,
                        max: 10,
                        divisions: 10,
                        onChanged: (v) => setState(() => value = v),
                      ),
                      TextButton(
                        focusNode: after,
                        onPressed: () {},
                        child: const Text('After'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> key(LogicalKeyboardKey key) async {
        await tester.sendKeyEvent(key);
        await tester.pump();
      }

      await key(LogicalKeyboardKey.arrowDown);
      expect(
        FocusManager.instance.primaryFocus!.debugLabel,
        'TV settings slider',
      );
      await key(LogicalKeyboardKey.arrowDown);
      expect(after.hasPrimaryFocus, isTrue);
      expect(value, 5);
      await key(LogicalKeyboardKey.arrowUp);
      await key(LogicalKeyboardKey.arrowLeft);
      expect(railMoves, 1);
      expect(value, 5);
      await key(LogicalKeyboardKey.arrowDown);
      await key(LogicalKeyboardKey.select);
      await key(LogicalKeyboardKey.arrowRight);
      expect(value, 6);
      await key(LogicalKeyboardKey.arrowLeft);
      expect(value, 5);
      expect(railMoves, 1);
      await key(LogicalKeyboardKey.arrowDown);
      expect(
        FocusManager.instance.primaryFocus!.debugLabel,
        'TV settings slider',
      );
      await navigator.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(pageBacks, 0);
      expect(find.text('按确定调整'), findsOneWidget);
      await key(LogicalKeyboardKey.arrowDown);
      expect(after.hasPrimaryFocus, isTrue);
      await navigator.currentState!.maybePop();
      await tester.pump();
      expect(pageBacks, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      before.dispose();
      after.dispose();
    },
  );
}
