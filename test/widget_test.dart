import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:velza/main.dart';
import 'package:velza/viewmodels/auth_viewmodel.dart';
import 'package:velza/viewmodels/chat_viewmodel.dart';
import 'package:velza/viewmodels/settings_viewmodel.dart';

void main() {
  testWidgets('App splash screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthViewModel()),
          ChangeNotifierProvider(create: (_) => ChatViewModel()),
          ChangeNotifierProvider(create: (_) => SettingsViewModel()),
        ],
        child: const VelzaApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2600));
    for (int i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  });
}
