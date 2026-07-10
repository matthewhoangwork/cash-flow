import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:money_tracking/widgets/glass.dart';

/// Regression test for the "Failed to interpolate TextStyles with different
/// inherit values" crash: on iOS the Cupertino nav bars in
/// [AdaptiveSliverScaffold] used to hero-animate their title across a route
/// push/pop, lerping a Material-derived title style (inherit: true) against a
/// Cupertino one (inherit: false). Pushing then popping must complete without
/// throwing. Runs across platforms via the variant so the fix is exercised on
/// iOS/macOS (where the nav bars are Cupertino).
void main() {
  testWidgets(
    'pushing and popping adaptive screens does not throw',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveSliverScaffold(
            title: 'Home',
            slivers: [
              SliverToBoxAdapter(
                child: Builder(
                  builder: (context) => Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdaptiveSliverScaffold(
                            title: 'Detail',
                            largeTitle: false,
                            slivers: [SliverToBoxAdapter(child: SizedBox(height: 400))],
                          ),
                        ),
                      ),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsWidgets);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsWidgets);

      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.all(),
  );
}
