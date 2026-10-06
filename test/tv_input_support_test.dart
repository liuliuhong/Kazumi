import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/tv_app_support.dart';
import 'package:kazumi/bean/widget/tv_input_support.dart';

void main() {
  testWidgets('D-pad leaves text fields; native editing cancels without popping; Back leaves selected input first', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    final input = FocusNode();
    final button = FocusNode();
    final controller = TextEditingController(text: 'Fate');
    final response = Completer<String?>();
    var nativeCalls = 0;
    const channel = MethodChannel('com.predidit.kazumi/intent');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'showTvTextInput');
      nativeCalls++;
      return response.future;
    });
    await tester.pumpWidget(MaterialApp(navigatorKey: navigator,
      builder: (_, child) => TvAppSupport(child: child!),
      home: const Scaffold(body: Text('Home'))));
    navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => TvInputGuard(child: Scaffold(body: Column(children: [
      TextField(focusNode: input, controller: controller, autofocus: true),
      TextButton(focusNode: button, onPressed: () {}, child: const Text('Search')),
    ])))));
    await tester.pumpAndSettle();
    expect(input.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(button.hasFocus, isTrue);
    input.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(nativeCalls, 1);
    response.complete(null);
    await tester.pump();
    expect(controller.text, 'Fate');
    expect(find.text('Search'), findsOneWidget);
    expect(input.hasFocus, isFalse);
    input.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.goBack, physicalKey: PhysicalKeyboardKey.escape);
    await tester.pump();
    await navigator.currentState!.maybePop();
    await tester.pump();
    expect(input.hasFocus, isFalse);
    expect(navigator.currentState!.canPop(), isTrue);
    await navigator.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    input.dispose(); button.dispose(); controller.dispose();
  });
}
