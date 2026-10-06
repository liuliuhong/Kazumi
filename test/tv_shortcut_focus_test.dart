import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/tv_app_support.dart';
import 'package:kazumi/bean/widget/tv_input_support.dart';

void main() {
  testWidgets(
    'entering a full-page shortcut region focuses its controls and owner focus requests cannot trap the remote',
    (tester) async {
      final rail = FocusNode();
      final shortcuts = FocusNode();
      final category = FocusNode();
      final item = FocusNode();
      var opens = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => TvAppSupport(child: child!),
          home: Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: TextButton(
                    focusNode: rail,
                    autofocus: true,
                    onPressed: () {},
                    child: const Text('追番'),
                  ),
                ),
                Expanded(
                  child: TvShortcutFocus(
                    focusNode: shortcuts,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          focusNode: category,
                          onPressed: () => shortcuts.requestFocus(),
                          child: const Text('在看'),
                        ),
                        const SizedBox(height: 30),
                        TextButton(
                          focusNode: item,
                          onPressed: () => opens++,
                          child: const Text('番剧'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, anyOf(category, item));
      category.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(category.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(item.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(opens, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      rail.dispose();
      shortcuts.dispose();
      category.dispose();
      item.dispose();
    },
  );
}
