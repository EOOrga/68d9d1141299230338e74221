import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyer_gilles_ops/main.dart';

void main() {
  testWidgets('shows dashboard and opens work detail', (tester) async {
    final store = AppStore.sample();

    await tester.pumpWidget(MyApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Operations ready'), findsOneWidget);

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    expect(find.text('North Wing training room booking'), findsOneWidget);

    await tester.tap(find.text('North Wing training room booking'));
    await tester.pumpAndSettle();

    expect(find.text('Task detail'), findsOneWidget);
    expect(find.text('Facility booking'), findsWidgets);
  });

  testWidgets('creates a local operation record', (tester) async {
    final store = AppStore.sample();

    await tester.pumpWidget(MyApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addOperationFab')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('operationTitleField')),
      'Conference room booking',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Main office');
    await tester.enterText(find.byType(TextFormField).at(2), 'Facilities lead');
    await tester.ensureVisible(find.byKey(const Key('saveOperationButton')));
    await tester.tap(find.byKey(const Key('saveOperationButton')));
    await tester.pumpAndSettle();

    expect(find.text('Conference room booking'), findsOneWidget);
    expect(store.operations.first.title, 'Conference room booking');
  });
}
