import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/tv_app_support.dart';
import 'package:kazumi/bean/widget/kazumi_menu.dart';
import 'package:kazumi/bean/widget/tv_history_row_navigation.dart';

void main() {
  testWidgets(
    'history Down Up Down stays on rows; actions are entered sideways',
    (tester) async {
      final rows = <int, FocusNode>{};
      final plays = <int, FocusNode>{};
      final menus = <int, FocusNode>{};
      var played = -1;
      var opened = -1;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => TvAppSupport(child: child!),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  for (var index = 0; index < 4; index++)
                    TvHistoryRowNavigation(
                      builder: (row, play, more, delete) {
                        rows[index] = row;
                        plays[index] = play;
                        menus[index] = more;
                        // Match HistoryRecordTile's overlapping full-row InkWell
                        // and independently focusable action buttons in a Stack.
                        return SizedBox(
                          height: 140,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: InkWell(
                                  focusNode: row,
                                  onTap: () => played = index,
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      focusNode: play,
                                      onPressed: () => played = index,
                                      icon: const Icon(Icons.play_arrow),
                                    ),
                                    KazumiMenuButton(
                                      onOpen: () => opened = index,
                                      menuChildren: [
                                        KazumiMenuItem(
                                          label: 'Details',
                                          onPressed: () {},
                                        ),
                                      ],
                                      builder: (_, toggle) => IconButton(
                                        focusNode: more,
                                        onPressed: toggle,
                                        icon: const Icon(Icons.more_horiz),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      rows[0]!.requestFocus();
      await tester.pump();
      Future<void> press(LogicalKeyboardKey key) async {
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
      }

      for (var repeat = 0; repeat < 3; repeat++) {
        await press(LogicalKeyboardKey.arrowDown);
        expect(FocusManager.instance.primaryFocus, rows[1]);
        await press(LogicalKeyboardKey.arrowUp);
        expect(FocusManager.instance.primaryFocus, rows[0]);
      }
      await press(LogicalKeyboardKey.arrowDown);
      await press(LogicalKeyboardKey.select);
      expect(played, 1);
      await press(LogicalKeyboardKey.arrowRight);
      expect(FocusManager.instance.primaryFocus, plays[1]);
      await press(LogicalKeyboardKey.select);
      expect(played, 1);
      await press(LogicalKeyboardKey.arrowRight);
      expect(FocusManager.instance.primaryFocus, menus[1]);
      await press(LogicalKeyboardKey.select);
      expect(opened, 1);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, menus[1]);
      await press(LogicalKeyboardKey.arrowDown);
      expect(FocusManager.instance.primaryFocus, rows[2]);
      await press(LogicalKeyboardKey.arrowUp);
      expect(FocusManager.instance.primaryFocus, rows[1]);
      await press(LogicalKeyboardKey.arrowRight);
      expect(FocusManager.instance.primaryFocus, plays[1]);
      await press(LogicalKeyboardKey.arrowRight);
      expect(FocusManager.instance.primaryFocus, menus[1]);
      await press(LogicalKeyboardKey.arrowLeft);
      expect(FocusManager.instance.primaryFocus, plays[1]);
      await press(LogicalKeyboardKey.arrowLeft);
      expect(FocusManager.instance.primaryFocus, rows[1]);
      await press(LogicalKeyboardKey.arrowRight);
      await press(LogicalKeyboardKey.arrowUp);
      expect(FocusManager.instance.primaryFocus, rows[0]);
      await press(LogicalKeyboardKey.arrowDown);
      await press(LogicalKeyboardKey.arrowDown);
      await press(LogicalKeyboardKey.arrowDown);
      expect(FocusManager.instance.primaryFocus, rows[3]);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
