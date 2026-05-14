import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pdf_viewer_app/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build app
    await tester.pumpWidget(const PdfViewerApp());

    // Wait for UI
    await tester.pumpAndSettle();

    // Check if MaterialApp loaded
    expect(find.byType(MaterialApp), findsOneWidget);

    // Check login page elements
    expect(find.textContaining('Login'), findsWidgets);
  });
}
