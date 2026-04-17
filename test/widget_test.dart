import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibe_orbit/main.dart';
import 'package:vibe_orbit/services/interaction_stats_service.dart';
import 'package:vibe_orbit/services/local_identity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('shows VibeOrbit title', (WidgetTester tester) async {
    await LocalIdentityService.instance.ensureInitialized();
    await InteractionStatsService.instance.load();
    await tester.pumpWidget(const VibeOrbitApp());
    await tester.pump();
    expect(find.text('VibeOrbit'), findsOneWidget);
  });
}
