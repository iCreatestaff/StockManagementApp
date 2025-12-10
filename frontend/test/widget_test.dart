// Basic widget test for Stock Management App
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('App launches with login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: StockManagementApp()));
    
    // Verify login screen is shown
    expect(find.text('Stock Management'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
