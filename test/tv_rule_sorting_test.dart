import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/card/rule_card.dart';
import 'package:kazumi/bean/widget/kazumi_menu.dart';
import 'package:kazumi/bean/widget/tv_app_support.dart';
import 'package:kazumi/bean/widget/tv_rule_row_navigation.dart';

void main() {
  testWidgets(
    'pending order save cannot overlap and Back can finish before it completes',
    (tester) async {
      final pending = Completer<void>();
      var moves = 0;
      var active = false;
      late FocusNode sortNode;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvRuleRowNavigation(
              canSort: true,
              onMove: (_) async {
                moves++;
                await pending.future;
              },
              builder: (row, more, sort, sorting, toggle) {
                sortNode = sort;
                active = sorting;
                return IconButton(
                  focusNode: sort,
                  onPressed: toggle,
                  icon: const Icon(Icons.swap_vert),
                );
              },
            ),
          ),
        ),
      );
      sortNode.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(active, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(moves, 1);
      await tester.sendKeyEvent(
        LogicalKeyboardKey.goBack,
        physicalKey: PhysicalKeyboardKey.escape,
      );
      await tester.pumpAndSettle();
      expect(active, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(active, isFalse);
      pending.complete();
      await tester.pumpAndSettle();
      expect(active, isFalse);
      expect(moves, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'rule actions and sorting keep rule identity, Back ends only sorting',
    (tester) async {
      final names = ['A', 'B', 'C', 'D'];
      final rows = <String, FocusNode>{};
      final more = <String, FocusNode>{};
      final sorts = <String, FocusNode>{};
      final sorting = <String, bool>{};
      var canSort = true;
      var edited = '';
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => TvAppSupport(child: child!),
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return Scaffold(
                body: ReorderableListView.builder(
                  scrollCacheExtent: const ScrollCacheExtent.pixels(10000),
                  buildDefaultDragHandles: false,
                  onReorderItem: (_, _) {},
                  itemCount: names.length,
                  itemBuilder: (_, index) {
                    final name = names[index];
                    return TvRuleRowNavigation(
                      key: ValueKey(name),
                      canSort: canSort,
                      onMove: (delta) async {
                        final old = names.indexOf(name);
                        final next = old + delta;
                        if (next < 0 || next >= names.length) return;
                        setState(() {
                          names.removeAt(old);
                          names.insert(next, name);
                        });
                      },
                      builder: (row, menu, sort, active, toggle) {
                        rows[name] = row;
                        more[name] = menu;
                        sorts[name] = sort;
                        sorting[name] = active;
                        return RuleCard(
                          title: name,
                          focusNode: row,
                          selected: active,
                          caption: active ? '排序中' : null,
                          onTap: () => edited = name,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              KazumiMenuButton(
                                builder: (_, open) => IconButton(
                                  focusNode: menu,
                                  onPressed: open,
                                  icon: const Icon(Icons.more_horiz),
                                ),
                                menuChildren: [
                                  KazumiMenuItem(
                                    label: '编辑',
                                    onPressed: () => edited = name,
                                  ),
                                  KazumiMenuItem(label: '测试', onPressed: () {}),
                                ],
                              ),
                              if (canSort)
                                IconButton(
                                  focusNode: sort,
                                  onPressed: toggle,
                                  icon: const Icon(Icons.drag_indicator),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      );
      Future<void> press(LogicalKeyboardKey key) async {
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
      }

      rows['A']!.requestFocus();
      await tester.pumpAndSettle();
      await press(LogicalKeyboardKey.select);
      expect(edited, 'A');
      await press(LogicalKeyboardKey.arrowRight);
      expect(more['A']!.hasPrimaryFocus, isTrue);
      await press(LogicalKeyboardKey.select);
      await press(LogicalKeyboardKey.arrowDown);
      expect(find.text('测试'), findsOneWidget);
      expect(FocusManager.instance.primaryFocus, isNot(more['A']));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(more['A']!.hasPrimaryFocus, isTrue);
      await press(LogicalKeyboardKey.arrowDown);
      expect(rows['B']!.hasPrimaryFocus, isTrue);
      await press(LogicalKeyboardKey.arrowUp);
      expect(rows['A']!.hasPrimaryFocus, isTrue);
      await press(LogicalKeyboardKey.arrowRight);
      await press(LogicalKeyboardKey.arrowRight);
      expect(sorts['A']!.hasPrimaryFocus, isTrue);
      final originalSort = sorts['A'];
      await press(LogicalKeyboardKey.select);
      expect(sorting['A'], isTrue);
      await press(LogicalKeyboardKey.arrowDown);
      expect(names, ['B', 'A', 'C', 'D']);
      expect(sorts['A'], same(originalSort));
      expect(sorts['A']!.hasPrimaryFocus, isTrue);
      await press(LogicalKeyboardKey.arrowDown);
      expect(names, ['B', 'C', 'A', 'D']);
      await press(LogicalKeyboardKey.arrowUp);
      expect(names, ['B', 'A', 'C', 'D']);
      await press(LogicalKeyboardKey.arrowLeft);
      expect(sorts['A']!.hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(
        LogicalKeyboardKey.goBack,
        physicalKey: PhysicalKeyboardKey.escape,
      );
      await tester.pumpAndSettle();
      expect(sorting['A'], isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(sorting['A'], isFalse);
      expect(find.byType(ReorderableListView), findsOneWidget);
      await press(LogicalKeyboardKey.arrowDown);
      expect(rows['C']!.hasPrimaryFocus, isTrue);
      await press(LogicalKeyboardKey.arrowUp);
      await press(LogicalKeyboardKey.arrowRight);
      await press(LogicalKeyboardKey.arrowRight);
      await press(LogicalKeyboardKey.select);
      await press(LogicalKeyboardKey.arrowUp);
      await press(LogicalKeyboardKey.arrowUp);
      expect(names, ['A', 'B', 'C', 'D']);
      await press(LogicalKeyboardKey.select);
      expect(sorting['A'], isFalse);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(sorting['A'], isTrue);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(sorting['A'], isTrue);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      rebuild(() => canSort = false);
      await tester.pumpAndSettle();
      expect(sorting['A'], isFalse);
      rows['A']!.requestFocus();
      await tester.pumpAndSettle();
      await press(LogicalKeyboardKey.arrowRight);
      await press(LogicalKeyboardKey.arrowRight);
      expect(more['A']!.hasPrimaryFocus, isTrue);
      await press(LogicalKeyboardKey.arrowLeft);
      expect(rows['A']!.hasPrimaryFocus, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
