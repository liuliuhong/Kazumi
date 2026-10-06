import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/tv_app_support.dart';
import 'package:kazumi/bean/widget/tv_navigation_rail.dart';
import 'package:kazumi/bean/widget/tv_scroll_reader.dart';
import 'package:kazumi/bean/widget/tv_input_support.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

void main() {
  testWidgets(
    'settings categories stay bounded after scrolling; Right enters pane',
    (tester) async {
      final categories = List.generate(12, (_) => FocusNode());
      final pane = FocusNode();
      final scroll = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => TvAppSupport(child: child!),
          home: TvDirectionalScope(
            onDirection: (direction) {
              if (TvNavigationRail.moveWithin(categories, direction)) {
                return true;
              }
              if (direction == TraversalDirection.right &&
                  categories.any((n) => n.hasPrimaryFocus)) {
                pane.requestFocus();
                return true;
              }
              return false;
            },
            child: Scaffold(
              body: Row(
                children: [
                  SizedBox(
                    width: 200,
                    child: ListView(
                      controller: scroll,
                      scrollCacheExtent: const ScrollCacheExtent.pixels(10000),
                      children: [
                        for (var i = 0; i < categories.length; i++)
                          SizedBox(
                            height: 100,
                            child: TextButton(
                              focusNode: categories[i],
                              onPressed: () {},
                              child: Text(i == 11 ? '关于' : '设置 $i'),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: TextButton(
                        focusNode: pane,
                        onPressed: () {},
                        child: const Text('内容'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      categories.first.requestFocus();
      await tester.pumpAndSettle();
      for (var i = 0; i < 20; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      expect(categories.last.hasPrimaryFocus, isTrue);
      expect(scroll.offset, greaterThan(0));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(pane.hasPrimaryFocus, isTrue);
      categories.last.requestFocus();
      await tester.pumpAndSettle();
      for (var i = 0; i < 20; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
      }
      expect(categories.first.hasPrimaryFocus, isTrue);
      expect(scroll.offset, 0);
      await tester.pumpWidget(const SizedBox());
      for (final node in categories) {
        node.dispose();
      }
      pane.dispose();
      scroll.dispose();
    },
  );
  testWidgets('rail stops at its ends and crosses to content only with Right', (
    tester,
  ) async {
    final first = FocusNode();
    final last = FocusNode();
    final content = FocusNode();
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => TvAppSupport(child: child!),
        home: Scaffold(
          body: Row(
            children: [
              TvNavigationRail(
                child: SizedBox(
                  width: 100,
                  child: Column(
                    children: [
                      TextButton(
                        focusNode: first,
                        autofocus: true,
                        onPressed: () {},
                        child: const Text('Search'),
                      ),
                      TextButton(
                        focusNode: last,
                        onPressed: () {},
                        child: const Text('My'),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: TextButton(
                    focusNode: content,
                    onPressed: () {},
                    child: const Text('Content'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(first.hasPrimaryFocus, isTrue);
    for (var i = 0; i < 5; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    expect(last.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(content.hasPrimaryFocus, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    first.dispose();
    last.dispose();
    content.dispose();
  });
  testWidgets(
    'comment reader scrolls a lazy text list and Up at top returns to toolbar',
    (tester) async {
      final scroll = ScrollController();
      final toolbar = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => TvAppSupport(child: child!),
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 400,
              child: CustomScrollView(
                controller: scroll,
                slivers: [
                  SliverToBoxAdapter(
                    child: TextButton(
                      focusNode: toolbar,
                      autofocus: true,
                      onPressed: () {},
                      child: const Text('Refresh'),
                    ),
                  ),
                  SliverToBoxAdapter(child: TvScrollReader(controller: scroll)),
                  SliverList.builder(
                    itemCount: 30,
                    itemBuilder: (_, i) =>
                        SizedBox(height: 120, child: Text('Comment $i')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus!.debugLabel,
        'TV comment reader',
      );
      for (var i = 0; i < 30; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
      }
      expect(scroll.offset, scroll.position.maxScrollExtent);
      expect(find.text('Comment 29'), findsOneWidget);
      expect(
        FocusManager.instance.primaryFocus!.debugLabel,
        'TV comment reader',
      );
      for (var i = 0; i < 40; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
      }
      expect(scroll.offset, 0);
      expect(toolbar.hasPrimaryFocus, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      scroll.dispose();
      toolbar.dispose();
    },
  );
}
