import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/tv_app_support.dart';
import 'package:kazumi/pages/player/tv_player_controls.dart';

void main() {
  testWidgets(
    'hidden confirmation toggles both states once and reveals updated controls',
    (tester) async {
      final focus = FocusNode(debugLabel: 'Video player shortcut scope');
      var playing = true;
      var toggles = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => TvAppSupport(child: child!),
          home: StatefulBuilder(
            builder: (_, setState) => Scaffold(
              body: Focus(
                focusNode: focus,
                autofocus: true,
                child: TvPlayerControls(
                  playerFocus: focus,
                  playing: playing,
                  position: Duration.zero,
                  duration: const Duration(minutes: 1),
                  onPlayPause: () async {
                    setState(() {
                      playing = !playing;
                      toggles++;
                    });
                  },
                  onSeek: (_) async {},
                  onNext: () async {},
                  onPrevious: () async {},
                  onDanmaku: () {},
                  onBack: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      for (final key in [
        LogicalKeyboardKey.select,
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.gameButtonA,
      ]) {
        // Up/Down reveals controls without changing playback.
        final before = toggles;
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(toggles, before);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        await tester.sendKeyDownEvent(key);
        await tester.pump();
        expect(toggles, before + 1);
        expect(playing, toggles.isEven);
        expect(find.text(playing ? '暂停' : '播放'), findsOneWidget);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'TV play pause');
        await tester.sendKeyRepeatEvent(key);
        await tester.pump();
        await tester.sendKeyUpEvent(key);
        await tester.pump();
        expect(toggles, before + 1);
      }
      // Auto-hidden controls must also resume a paused video on confirmation.
      expect(playing, isFalse);
      await tester.pump(const Duration(seconds: 9));
      await tester.pump();
      expect(find.text('播放'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(playing, isTrue);
      expect(toggles, 4);
      expect(find.text('暂停'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      focus.dispose();
    },
  );

  testWidgets(
    'Exit playback button pops its route despite the visible-control Back guard',
    (tester) async {
      final focus = FocusNode(debugLabel: 'Video player shortcut scope');
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: Text('Home')),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: Focus(
              focusNode: focus,
              autofocus: true,
              child: TvPlayerControls(
                playerFocus: focus,
                playing: true,
                position: Duration.zero,
                duration: const Duration(minutes: 1),
                onPlayPause: () async {},
                onSeek: (_) async {},
                onNext: () async {},
                onPrevious: () async {},
                onDanmaku: () {},
                onBack: () {
                  navigator.currentState!.maybePop();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('退出播放'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      focus.dispose();
    },
  );

  testWidgets(
    'visible D-pad navigates controls; hidden select toggles and reveals',
    (tester) async {
      final focus = FocusNode(debugLabel: 'Video player shortcut scope');
      final seeks = <Duration>[];
      var toggles = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => TvAppSupport(child: child!),
          home: Scaffold(
            body: Focus(
              focusNode: focus,
              autofocus: true,
              child: TvPlayerControls(
                playerFocus: focus,
                playing: true,
                position: const Duration(seconds: 60),
                duration: const Duration(seconds: 65),
                onPlayPause: () async {
                  toggles++;
                },
                onSeek: (position) async {
                  seeks.add(position);
                },
                onNext: () async {},
                onPrevious: () async {},
                onDanmaku: () {},
                onBack: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(seeks, isEmpty);
      // A native video surface can return focus to the player after resume.
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'TV play pause');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNot(focus));
      expect(seeks, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('暂停'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(seeks.single, const Duration(seconds: 65));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(seeks.last, const Duration(seconds: 50));
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(find.text('暂停'), findsOneWidget);
      expect(toggles, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(toggles, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      focus.dispose();
    },
  );

  testWidgets(
    'Back hides controls before exiting and dialog keys do not affect playback',
    (tester) async {
      final focus = FocusNode(debugLabel: 'Video player shortcut scope');
      final navigator = GlobalKey<NavigatorState>();
      var toggles = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: Text('Home')),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: Focus(
              focusNode: focus,
              autofocus: true,
              child: TvPlayerControls(
                playerFocus: focus,
                playing: true,
                position: Duration.zero,
                duration: const Duration(minutes: 1),
                onPlayPause: () async {
                  toggles++;
                },
                onSeek: (_) async {},
                onNext: () async {},
                onPrevious: () async {},
                onDanmaku: () {},
                onBack: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Android can deliver KEYCODE_BACK before its separate route-pop request.
      // Handling both used to hide controls and then pop the video in one press.
      await tester.sendKeyEvent(
        LogicalKeyboardKey.goBack,
        physicalKey: PhysicalKeyboardKey.escape,
      );
      await tester.pump();
      expect(find.text('暂停'), findsOneWidget);
      await navigator.currentState!.maybePop();
      await tester.pump();
      expect(find.text('暂停'), findsNothing);
      expect(navigator.currentState!.canPop(), isTrue);
      showDialog<void>(
        context: focus.context!,
        builder: (_) => AlertDialog(
          title: const Text('Dialog'),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () {},
              child: const Text('OK'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
      await tester.pump();
      expect(toggles, 0);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await navigator.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      focus.dispose();
    },
  );
}
