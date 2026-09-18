import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:snapshot/app/app.dart';
import 'package:snapshot/features/auth/providers/auth_providers.dart';

void main() {
  setUpAll(() async {
    // DateFormat('vi') is used by some screens; initialize locale data.
    await initializeDateFormatting('vi');
  });

  testWidgets('shows sign-in screen when signed out', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Avoid touching real Firebase in tests.
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const App(),
      ),
    );
    await tester.pump();

    expect(find.text('Đăng nhập'), findsWidgets);
  });
}
