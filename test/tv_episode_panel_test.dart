import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/tv_app_support.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/pages/video/episode_selection_panel.dart';
import 'package:kazumi/pages/video/video_side_panel.dart';

List<Road> roads(int count) => List.generate(
  count,
  (i) => Road(
    name: '线路 ${i + 1}',
    data: List.generate(24, (j) => '$i:$j'),
    identifier: List.generate(24, (j) => '第${j + 1}集'),
  ),
);
Widget panel(int count) => EpisodeSelectionPanel(
  title: '番剧完整标题',
  roads: roads(count),
  selectedRoad: 0,
  selectedEpisode: 18,
  onEpisodeSelected: (_, _) {},
  downloads: const {},
  disableAnimations: true,
);
Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('selecting another road switches playback of the same episode', (
    tester,
  ) async {
    final calls = <(int, int)>[];
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => TvAppSupport(child: child!),
        home: Scaffold(
          body: SizedBox(
            width: 380,
            child: EpisodeSelectionPanel(
              title: '线路切换',
              roads: roads(3),
              selectedRoad: 0,
              selectedEpisode: 18,
              downloads: const {},
              disableAnimations: true,
              onEpisodeSelected: (episode, road) => calls.add((episode, road)),
            ),
          ),
        ),
      ),
    );
    tester
        .widget<OutlinedButton>(find.byType(OutlinedButton))
        .focusNode!
        .requestFocus();
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.select);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.select);
    expect(calls, [(18, 1)]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'roads are reachable after locating and scrolling; menu selects and returns',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => TvAppSupport(child: child!),
          home: Scaffold(body: SizedBox(width: 380, child: panel(3))),
        ),
      );
      final selector = tester.widget<OutlinedButton>(
        find.byType(OutlinedButton),
      );
      selector.focusNode!.requestFocus();
      await tester.pumpAndSettle();
      for (var i = 0; i < 18; i++) {
        await press(tester, LogicalKeyboardKey.arrowDown);
      }
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(scroll.pixels, greaterThan(0));
      for (var i = 0; i < 26; i++) {
        await press(tester, LogicalKeyboardKey.arrowUp);
      }
      expect(selector.focusNode!.hasPrimaryFocus, isTrue);
      expect(scroll.pixels, 0);
      await press(tester, LogicalKeyboardKey.select);
      expect(
        FocusManager.instance.primaryFocus!.context!
            .findAncestorWidgetOfExactType<MenuItemButton>(),
        isNotNull,
      );
      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.select);
      expect(selector.focusNode!.hasPrimaryFocus, isTrue);
      expect(
        find.descendant(
          of: find.byType(OutlinedButton),
          matching: find.text('线路 2'),
        ),
        findsOneWidget,
      );
      expect(scroll.pixels, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'single road can be inspected; Back closes dropdown before panel',
    (tester) async {
      final nav = GlobalKey<NavigatorState>();
      final side = GlobalKey<VideoSidePanelState>();
      var closed = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          builder: (_, child) => TvAppSupport(child: child!),
          home: Scaffold(
            body: VideoSidePanel(
              key: side,
              fullscreen: true,
              disableAnimations: true,
              onClosed: () => closed++,
              child: panel(1),
            ),
          ),
        ),
      );
      side.currentState!.toggle();
      await tester.pumpAndSettle();
      final selector = tester.widget<OutlinedButton>(
        find.byType(OutlinedButton),
      );
      selector.focusNode!.requestFocus();
      await tester.pumpAndSettle();
      await press(tester, LogicalKeyboardKey.select);
      expect(find.byType(MenuItemButton), findsOneWidget);
      await nav.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      expect(closed, 0);
      expect(selector.focusNode!.hasPrimaryFocus, isTrue);
      await nav.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(closed, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
