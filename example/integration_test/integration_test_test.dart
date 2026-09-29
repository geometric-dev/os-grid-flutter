import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:os_grid_flutter_example/demos/community_features/community_features_demo.dart';

/// Minimal integration-test runner so `flutter test integration_test/`
/// (from `example/`) has a fast, always-runnable smoke test in addition to
/// the full end-to-end flow in `app_e2e_test.dart`.
///
/// Verifies the harness boots the real demo app and the first page renders.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('smoke: community features demo boots and renders', (
    tester,
  ) async {
    await tester.pumpWidget(const CommunityFeaturesDemoApp());
    await tester.pumpAndSettle();

    expect(find.byType(CommunityFeaturesDemoApp), findsOneWidget);
    expect(find.text("What's New"), findsWidgets);

    // Best-effort screenshot — the driver side is only present when running
    // against a device; on host runs this silently times out.
    try {
      await binding
          .takeScreenshot('smoke-boot')
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Screenshot skipped (no driver attached).
    }
  });
}
