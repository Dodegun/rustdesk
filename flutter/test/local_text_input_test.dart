import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/mobile/widgets/local_text_input.dart';

void main() {
  testWidgets('opening over a focused session opens the local keyboard',
      (tester) async {
    late BuildContext sessionContext;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      sessionContext = context;
      return const Scaffold(body: TextField(autofocus: true));
    })));
    await tester.pumpAndSettle();
    tester.testTextInput.hide();
    final entry = OverlayEntry(builder: (_) => LocalTextInput(
      canSend: () => true,
      send: (_) async {},
      close: () {},
    ));
    Overlay.of(sessionContext).insert(entry);
    await tester.pumpAndSettle();
    final draft = tester.widget<TextField>(
        find.byKey(const ValueKey('local-text-draft')));
    expect(draft.focusNode!.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    entry.remove();
    await tester.pumpAndSettle();
    entry.dispose();
  });

  testWidgets('sends Korean composition, mixed text, newline and emoji once',
      (tester) async {
    final sent = <String>[];
    final pending = Completer<void>();
    var closed = false;
    await tester.pumpWidget(MaterialApp(home: LocalTextInput(
      canSend: () => true,
      send: (text) { sent.add(text); return pending.future; },
      close: () => closed = true,
    )));
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byType(TextField));
    const text = '안녕 값 닭 괜찮아요 왜 웨 의 RustDesk 123\n😀👨‍👩‍👧 한';
    tester.testTextInput.updateEditingValue(TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange(start: text.length - 1, end: text.length),
    ));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('local-text-send')));
    await tester.tap(find.byKey(const ValueKey('local-text-send')));
    expect(sent, [text]);
    expect(closed, isFalse);
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
    expect(closed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('revoked permission is checked even before the next rebuild',
      (tester) async {
    var allowed = true;
    final sent = <String>[];
    await tester.pumpWidget(MaterialApp(home: LocalTextInput(
      canSend: () => allowed,
      send: (text) async { sent.add(text); },
      close: () {},
    )));
    await tester.enterText(find.byType(TextField), '보내지 마세요');
    await tester.pump();
    allowed = false;
    await tester.tap(find.byKey(const ValueKey('local-text-send')));
    await tester.pump();
    expect(sent, isEmpty);
    expect(find.text('연결 상태와 키보드 제어 권한을 확인하세요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing during send discards draft without a late state update',
      (tester) async {
    final pending = Completer<void>();
    Widget dialog() => MaterialApp(home: LocalTextInput(
      canSend: () => true,
      send: (_) => pending.future,
      close: () {},
    ));
    await tester.pumpWidget(dialog());
    await tester.enterText(find.byType(TextField), '임시 초안');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('local-text-send')));
    await tester.pumpWidget(const SizedBox());
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(dialog());
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
  });

  testWidgets('view-only disables sending; failed send retains draft',
      (tester) async {
    var allowed = false;
    Widget dialog() => MaterialApp(home: LocalTextInput(
      canSend: () => allowed,
      send: (_) async { throw StateError('disconnected'); },
      close: () {},
    ));
    await tester.pumpWidget(dialog());
    await tester.enterText(find.byType(TextField), '남겨 둘 초안');
    await tester.pump();
    expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('local-text-send'))).onPressed, isNull);
    allowed = true;
    await tester.pumpWidget(dialog());
    await tester.tap(find.byKey(const ValueKey('local-text-send')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '남겨 둘 초안');
    expect(find.text('전송 결과를 확인할 수 없습니다. PC를 확인한 뒤 다시 시도하세요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
