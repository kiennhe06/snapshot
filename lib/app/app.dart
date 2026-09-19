import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/display_theme.dart';
import '../core/design/tokens.dart';
import '../core/i18n/i18n.dart';
import 'router.dart';
import 'theme.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final lang = ref.watch(localeProvider);
    final skin = ref.watch(displayThemeProvider);
    currentLang = lang; // keep the global in sync for tr()
    applyDisplayTheme(skin == DisplaySkin.dark); // set the live palette

    return MaterialApp.router(
      // Re-key on language OR skin change so the whole tree re-reads tokens.
      key: ValueKey('$lang-$skin'),
      title: 'Snapshot',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(),
      themeMode: skin == DisplaySkin.dark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      locale: localeOf(lang),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
