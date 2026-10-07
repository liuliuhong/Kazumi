import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/card/rule_card.dart';
import 'package:kazumi/bean/widget/tv_app_support.dart';
import 'package:kazumi/bean/widget/tv_scroll_top_on_focus.dart';
import 'package:kazumi/pages/plugin_editor/rule_management_widgets.dart';
import 'package:kazumi/pages/plugin_editor/editor_form_widgets.dart';

void main() {
  testWidgets('catalog rows have one TV action when returning from start button', (
    tester,
  ) async {
    final first = FocusNode();
    final finish = FocusNode();
    final activations = <int>[0, 0, 0];
    final buttonNodes = List.generate(3, (_) => FocusNode());
    await tester.pumpWidget(MaterialApp(
      builder: (_, child) => TvAppSupport(child: child!),
      home: Scaffold(body: Column(children: [
        for (var index = 0; index < 3; index++)
          RuleCard(
            title: '安装规则 $index',
            focusNode: index == 0 ? first : null,
            singleTvAction: true,
            onTap: () => activations[index]++,
            trailing: FilledButton(
              focusNode: buttonNodes[index],
              onPressed: () => activations[index]++,
              child: const Text('+ 安装'),
            ),
          ),
        Align(alignment: Alignment.centerRight, child: FilledButton(
          focusNode: finish,
          onPressed: () {},
          child: const Text('开始使用'),
        )),
      ])),
    ));
    first.requestFocus();
    await tester.pumpAndSettle();
    for (var cycle = 0; cycle < 3; cycle++) {
      for (var index = 0; index < 3; index++) {
        expect(FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<RuleCard>()?.title, '安装规则 $index');
        expect(buttonNodes.any((node) => node.hasFocus), isFalse);
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(activations[index], cycle * 2 + 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      expect(finish.hasFocus, isTrue);
      for (var index = 2; index >= 0; index--) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<RuleCard>()?.title, '安装规则 $index');
        expect(buttonNodes.any((node) => node.hasFocus), isFalse);
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(activations[index], cycle * 2 + 2);
      }
    }
    await tester.pumpWidget(const SizedBox());
    first.dispose();
    finish.dispose();
    for (final node in buttonNodes) { node.dispose(); }
  });

  testWidgets('editor upward navigation restores intro before tabs and toolbar', (
    tester,
  ) async {
    final scroll = ScrollController();
    final form = FocusNode();
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => TvAppSupport(child: child!),
        home: Scaffold(
          appBar: AppBar(
            leading: TvScrollTopOnFocus(
              controller: scroll,
              child: BackButton(onPressed: () {}),
            ),
          ),
          body: SingleChildScrollView(
            controller: scroll,
            child: Column(
              children: [
                const RulePageIntro(
                  title: '7sefun',
                  description: '规则介绍',
                  icon: Icons.edit_note,
                ),
                TvScrollTopOnFocus(
                  controller: scroll,
                  child: EditorChoiceGroup<int>(
                    value: 0,
                    segments: const [
                      ButtonSegment(value: 0, label: Text('基本')),
                      ButtonSegment(value: 1, label: Text('搜索')),
                      ButtonSegment(value: 2, label: Text('选集')),
                      ButtonSegment(value: 3, label: Text('高级')),
                    ],
                    onChanged: (_) {},
                  ),
                ),
                const SizedBox(height: 400),
                TextButton(
                  focusNode: form,
                  onPressed: () {},
                  child: const Text('表单'),
                ),
                const SizedBox(height: 600),
              ],
            ),
          ),
        ),
      ),
    );
    for (var cycle = 0; cycle < 2; cycle++) {
      form.requestFocus();
      scroll.jumpTo(400);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
      expect(
        tester.getTopLeft(find.byType(RulePageIntro)).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.byType(AppBar)).dy),
      );
      // Toolbar focus lies outside the scroller; it must restore the intro too.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<BackButton>(),
        isNotNull,
      );
      expect(scroll.offset, 0);
    }
    await tester.pumpWidget(const SizedBox());
    form.dispose();
    scroll.dispose();
  });

  testWidgets('catalog installed rows remain reachable below a tall header', (
    tester,
  ) async {
    final sort = FocusNode();
    final scroll = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => TvAppSupport(child: child!),
        home: Scaffold(
          body: CustomScrollView(
            controller: scroll,
            scrollCacheExtent: const ScrollCacheExtent.pixels(10000),
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 700,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: TextButton(
                      focusNode: sort,
                      onPressed: () {},
                      child: const Text('最近更新'),
                    ),
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: 20,
                itemBuilder: (_, index) => RuleCard(
                  title: '规则 $index',
                  installed: true,
                  trailing: const Text('已安装'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    sort.requestFocus();
    await tester.pumpAndSettle();
    for (var index = 0; index < 8; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      final focusedCard = FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<RuleCard>();
      expect(focusedCard?.title, '规则 $index');
    }
    expect(scroll.offset, greaterThan(700));
    await tester.pumpWidget(const SizedBox());
    sort.dispose();
    scroll.dispose();
  });

  testWidgets(
    'returning to introduction or toolbar restores complete rule header',
    (tester) async {
      final scroll = ScrollController();
      final add = FocusNode();
      final toolbar = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => TvAppSupport(child: child!),
          home: Scaffold(
            appBar: AppBar(
              actions: [
                TvScrollTopOnFocus(
                  controller: scroll,
                  child: IconButton(
                    focusNode: toolbar,
                    onPressed: () {},
                    icon: const Icon(Icons.checklist),
                  ),
                ),
              ],
            ),
            body: ReorderableListView.builder(
              scrollController: scroll,
              onReorderItem: (_, _) {},
              header: TvScrollTopOnFocus(
                controller: scroll,
                child: RulePageIntro(
                  title: '我的规则',
                  description: '说明',
                  icon: Icons.extension,
                  actions: [
                    TextButton(
                      focusNode: add,
                      onPressed: () {},
                      child: const Text('添加规则'),
                    ),
                  ],
                ),
              ),
              itemCount: 20,
              itemBuilder: (_, index) => RuleCard(
                key: ValueKey(index),
                title: '规则 $index',
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      scroll.jumpTo(900);
      await tester.pumpAndSettle();
      add.requestFocus();
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
      toolbar.requestFocus();
      await tester.pumpAndSettle();
      add.requestFocus();
      await tester.pumpAndSettle();
      scroll.jumpTo(900);
      await tester.pumpAndSettle();
      toolbar.requestFocus();
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
      await tester.pumpWidget(const SizedBox());
      add.dispose();
      toolbar.dispose();
      scroll.dispose();
    },
  );
}
