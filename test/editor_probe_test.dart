import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbito/data/local/app_database.dart' show Note;
import 'package:orbito/features/notes/note_editor.dart';

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

  Note note({String body = '', String? content}) => Note(
    id: 'n',
    userId: 'u',
    title: 'T',
    body: body,
    content: content,
    createdAt: '',
    updatedAt: '',
  );

  test('an old note opens as paragraphs; content round-trips', () {
    final old = documentOf(note(body: 'Visa\nFlights'));
    expect(old.root.children.map((n) => n.delta!.toPlainText()), [
      'Visa',
      'Flights',
    ]);
    expect(plainTextOf(old), 'Visa\nFlights');

    old.insert([2], [toggleNode()..insert(paragraphNode(text: 'Inside'))]);
    final saved = documentOf(note(content: encodeDocument(old)));
    expect(saved.root.children.last.type, NoteBlocks.toggle);
    expect(plainTextOf(saved), 'Visa\nFlights\n\nInside');

    // Unreadable content falls back to the text.
    expect(
      plainTextOf(documentOf(note(body: 'Kept', content: '{oops'))),
      'Kept',
    );
  });

  test('a block moves above or below another block', () async {
    List<String> texts(EditorState editor) => [
      for (final n in editor.document.root.children) n.delta!.toPlainText(),
    ];
    final editor = EditorState(
      document: Document.blank()
        ..insert(
          [0],
          [
            paragraphNode(text: 'a'),
            paragraphNode(text: 'b'),
            paragraphNode(text: 'c'),
          ],
        ),
    );
    Node at(int i) => editor.document.root.children[i];

    await moveBlock(editor, at(0), at(2), below: true);
    expect(texts(editor), ['b', 'c', 'a']);
    await moveBlock(editor, at(2), at(0), below: false);
    expect(texts(editor), ['a', 'b', 'c']);
    await moveBlock(editor, at(2), at(1), below: false);
    expect(texts(editor), ['a', 'c', 'b']);
    // Onto itself: nothing happens.
    await moveBlock(editor, at(1), at(1), below: true);
    expect(texts(editor), ['a', 'c', 'b']);
  });
}
