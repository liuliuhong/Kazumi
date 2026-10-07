import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/tv_app_support.dart';
import 'package:kazumi/bean/widget/tv_scroll_boundary.dart';
import 'package:kazumi/bean/widget/tv_content_action_navigation.dart';
import 'package:kazumi/bean/widget/tv_readable_item.dart';
import 'package:kazumi/pages/collect/collect_sync_dialog.dart';
import 'package:kazumi/modules/collect/collect_sync_plan.dart';
import 'package:kazumi/modules/bangumi/sync_priority.dart';

Widget app(Widget body) => MaterialApp(
  builder: (_, child) => TvAppSupport(child: child!),
  home: Scaffold(body: body),
);
Future<void> key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'scrolling settings restore introduction across repeated round trips',
    (tester) async {
      final scroll = ScrollController();
      final nodes = List.generate(15, (_) => FocusNode());
      await tester.pumpWidget(
        app(
          TvScrollBoundary(
            child: ListView(
              controller: scroll,
              scrollCacheExtent: const ScrollCacheExtent.pixels(10000),
              children: [
                const SizedBox(height: 160, child: Text('完整顶部介绍')),
                for (var i = 0; i < nodes.length; i++)
                  SizedBox(
                    height: 90,
                    child: TextButton(
                      focusNode: nodes[i],
                      onPressed: () {},
                      child: Text('设置 $i'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      for (var round = 0; round < 3; round++) {
        nodes.first.requestFocus();
        await tester.pumpAndSettle();
        for (var i = 1; i < nodes.length; i++) {
          await key(tester, LogicalKeyboardKey.arrowDown);
        }
        expect(nodes.last.hasPrimaryFocus, isTrue);
        expect(scroll.offset, greaterThan(0));
        for (var i = 1; i < nodes.length; i++) {
          await key(tester, LogicalKeyboardKey.arrowUp);
        }
        expect(nodes.first.hasPrimaryFocus, isTrue);
        expect(scroll.offset, 0);
      }
      await tester.pumpWidget(const SizedBox());
      scroll.dispose();
      for (final node in nodes) {
        node.dispose();
      }
    },
  );

  testWidgets('Up reveals offscreen controls even without a top boundary', (
    tester,
  ) async {
    final scroll = ScrollController();
    final first = FocusNode();
    final last = FocusNode();
    await tester.pumpWidget(
      app(
        ListView(
          controller: scroll,
          scrollCacheExtent: const ScrollCacheExtent.pixels(10000),
          children: [
            TextButton(
              focusNode: first,
              onPressed: () {},
              child: const Text('第一项'),
            ),
            const SizedBox(height: 1500),
            TextButton(
              focusNode: last,
              onPressed: () {},
              child: const Text('最后一项'),
            ),
          ],
        ),
      ),
    );
    last.requestFocus();
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    first.requestFocus();
    await tester.pumpAndSettle();
    expect(scroll.offset, lessThanOrEqualTo(4));
    await tester.pumpWidget(const SizedBox());
    scroll.dispose();
    first.dispose();
    last.dispose();
  });

  testWidgets(
    'Right preserves grid navigation then enters fixed action; Left restores row',
    (tester) async {
      final navigation = TvContentActionNavigation();
      final left = FocusNode();
      final right = FocusNode();
      await tester.pumpWidget(
        app(
          Stack(
            children: [
              navigation.content(
                Row(
                  children: [
                    TextButton(
                      focusNode: left,
                      onPressed: () {},
                      child: const Text('关联一'),
                    ),
                    TextButton(
                      focusNode: right,
                      onPressed: () {},
                      child: const Text('关联二'),
                    ),
                  ],
                ),
                onlyAtRightEdge: true,
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: navigation.fixedAction(
                  FloatingActionButton(
                    focusNode: navigation.action,
                    onPressed: () {},
                    child: const Icon(Icons.play_arrow),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      left.requestFocus();
      await tester.pumpAndSettle();
      await key(tester, LogicalKeyboardKey.arrowRight);
      expect(right.hasPrimaryFocus, isTrue);
      await key(tester, LogicalKeyboardKey.arrowRight);
      expect(navigation.action.hasPrimaryFocus, isTrue);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(right.hasPrimaryFocus, isTrue);
      await tester.pumpWidget(const SizedBox());
      navigation.dispose();
      left.dispose();
      right.dispose();
    },
  );

  testWidgets(
    'fixed toolbar watch action preserves the full list and returns to its row',
    (tester) async {
      final navigation = TvContentActionNavigation();
      final row = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => TvAppSupport(child: child!),
          home: Scaffold(
            appBar: AppBar(
              actions: [
                navigation.fixedAction(
                  FilledButton(
                    focusNode: navigation.action,
                    onPressed: () {},
                    child: const Text('开始观看'),
                  ),
                ),
              ],
            ),
            body: navigation.content(
              ListView(
                children: [
                  TextButton(
                    focusNode: row,
                    onPressed: () {},
                    child: const Text('制作人员'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      row.requestFocus();
      await tester.pumpAndSettle();
      await key(tester, LogicalKeyboardKey.arrowRight);
      expect(navigation.action.hasPrimaryFocus, isTrue);
      expect(
        tester.getRect(find.text('开始观看')).bottom,
        lessThan(tester.getRect(find.text('制作人员')).top),
      );
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(row.hasPrimaryFocus, isTrue);
      await tester.pumpWidget(const SizedBox());
      navigation.dispose();
      row.dispose();
    },
  );

  testWidgets('reading rows exclude selection focus and Down reaches next row', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        ListView(
          children: const [
            TvReadableItem(
              child: SizedBox(height: 120, child: SelectableText('评论一')),
            ),
            TvReadableItem(
              child: SizedBox(height: 120, child: SelectableText('评论二')),
            ),
          ],
        ),
      ),
    );
    final reading = tester
        .widgetList<Focus>(find.byType(Focus))
        .where((w) => w.onKeyEvent != null)
        .toList();
    final first = Focus.of(tester.element(find.text('评论一')), scopeOk: true);
    // SelectableText's focus is excluded; request the visible reading wrapper.
    final wrappers = find.byType(TvReadableItem);
    final node = tester.element(wrappers.first).findRenderObject();
    expect(node, isNotNull);
    expect(reading, isNotEmpty);
    expect(first.canRequestFocus, isFalse);
    final targets = FocusManager.instance.rootScope.traversalDescendants
        .where(
          (n) =>
              n.context?.findAncestorWidgetOfExactType<TvReadableItem>() !=
              null,
        )
        .toList();
    expect(targets.length, 2);
    targets.first.requestFocus();
    await tester.pumpAndSettle();
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(targets.last.hasPrimaryFocus, isTrue);
  });

  testWidgets(
    'long comments scroll within a row before moving to next comment',
    (tester) async {
      final scroll = ScrollController();
      await tester.pumpWidget(
        app(
          ListView(
            controller: scroll,
            scrollCacheExtent: const ScrollCacheExtent.pixels(10000),
            children: const [
              TvReadableItem(child: SizedBox(height: 1300, child: Text('长评论'))),
              TvReadableItem(
                child: SizedBox(height: 100, child: Text('下一条评论')),
              ),
            ],
          ),
        ),
      );
      final targets = FocusManager.instance.rootScope.traversalDescendants
          .where(
            (n) =>
                n.context?.findAncestorWidgetOfExactType<TvReadableItem>() !=
                null,
          )
          .toList();
      targets.first.requestFocus();
      await tester.pumpAndSettle();
      final before = scroll.offset;
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(scroll.offset, greaterThan(before));
      expect(targets.first.hasPrimaryFocus, isTrue);
      for (var i = 0; i < 6; i++) {
        await key(tester, LogicalKeyboardKey.arrowDown);
      }
      expect(targets.last.hasPrimaryFocus, isTrue);
      await tester.pumpWidget(const SizedBox());
      scroll.dispose();
    },
  );

  testWidgets(
    'sync dialog takes focus and reaches setup rows without starting sync',
    (tester) async {
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => CollectSyncDialog(
                  plan: const CollectSyncPlan(
                    webDavEnabled: false,
                    webDavCollectiblesEnabled: false,
                    bangumiEnabled: false,
                  ),
                  priority: BangumiSyncPriority.localFirst,
                  onSync:
                      (step, {required onError, required onProgress}) async =>
                          throw StateError('must not sync'),
                ),
              ),
              child: const Text('同步'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('同步'));
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<AlertDialog>(),
        isNotNull,
      );
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<AlertDialog>(),
        isNotNull,
      );
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<ListTile>(),
        isNotNull,
      );
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<AlertDialog>(),
        isNotNull,
      );
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<ListTile>(),
        isNotNull,
      );
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(find.byType(CollectSyncDialog), findsNothing);
    },
  );
}
