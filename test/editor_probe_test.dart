import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proves the block editor package runs in Orbito's tests: it shows a
/// document, takes a change, and its JSON can be read back.
void main() {
  testWidgets('the block editor shows and changes a document', (tester) async {
    final document = Document.blank()
      ..insert([0], [paragraphNode(text: 'Hello')]);
    final editor = EditorState(document: document);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppFlowyEditorLocalizations.delegate],
        home: Scaffold(body: AppFlowyEditor(editorState: editor)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hello', findRichText: true), findsOneWidget);

    final transaction = editor.transaction
      ..insertNode([1], todoListNode(checked: false, text: 'Buy milk'));
    await editor.apply(transaction);
    await tester.pumpAndSettle();
    expect(find.text('Buy milk', findRichText: true), findsOneWidget);

    final again = Document.fromJson(editor.document.toJson());
    expect(again.root.children, hasLength(2));
    expect(again.root.children.last.type, TodoListBlockKeys.type);
  });
}
