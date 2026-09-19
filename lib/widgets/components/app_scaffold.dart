import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';

/// Base screen scaffold: paints the single cobalt "stadium light" glow behind
/// every route (transparent Scaffold on top). Use instead of a bare Scaffold so
/// the depth background is consistent app-wide.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.topBar,
    this.bottomBar,
    this.floatingAction,
    this.extendBodyBehindTopBar = false,
  });

  final Widget body;
  final Widget? topBar;
  final Widget? bottomBar;
  final Widget? floatingAction;
  final bool extendBodyBehindTopBar;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: AppBackground.glow),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: floatingAction,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              ?topBar,
              Expanded(child: body),
            ],
          ),
        ),
        bottomNavigationBar: bottomBar,
      ),
    );
  }
}
