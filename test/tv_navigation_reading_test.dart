import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/tv_app_support.dart';
import 'package:kazumi/bean/widget/tv_navigation_rail.dart';
import 'package:kazumi/bean/widget/tv_scroll_reader.dart';

void main() {
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
