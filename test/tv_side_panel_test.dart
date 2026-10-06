import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/video/video_side_panel.dart';
import 'package:kazumi/services/platform/tv_service.dart';

void main() {
  testWidgets(
    'TV episode panel takes focus; Back closes it and restores player focus',
    (tester) async {
      // This test is also valid in the ordinary suite, without a TV build define.
      if (!TvService.isTelevision) return;
      final panel = GlobalKey<VideoSidePanelState>();
      final playerFocus = FocusNode(debugLabel: 'Video player shortcut scope');
      final episodeFocus = FocusNode();
      final navigator = GlobalKey<NavigatorState>();
      var closed = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: Scaffold(
            body: Stack(
              children: [
                Focus(
                  focusNode: playerFocus,
                  autofocus: true,
                  child: const SizedBox.expand(),
                ),
                VideoSidePanel(
                  key: panel,
                  fullscreen: false,
                  onClosed: () {
                    closed++;
                    playerFocus.requestFocus();
                  },
                  child: Center(
                    child: FilledButton(
                      focusNode: episodeFocus,
                      onPressed: () {},
                      child: const Text('Episode 1'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      panel.currentState!.toggle();
      await tester.pumpAndSettle();
      expect(episodeFocus.hasPrimaryFocus, isTrue);
      await navigator.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(closed, 1);
      expect(find.text('Episode 1'), findsNothing);
      expect(playerFocus.hasPrimaryFocus, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      playerFocus.dispose();
      episodeFocus.dispose();
    },
  );
}
