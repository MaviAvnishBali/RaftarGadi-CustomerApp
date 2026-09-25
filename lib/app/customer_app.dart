import 'package:customer_app/app/router/app_router.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localization/localization.dart';

/// Root of the customer app: the router-driven [MaterialApp] with the brand
/// theme and localization (English + Hindi) wired in.
class RaftarCustomerApp extends ConsumerWidget {
  const RaftarCustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Raftar Gaddi',
      debugShowCheckedModeBanner: false,
      theme: RaftarTheme.light,
      routerConfig: ref.watch(appRouterProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
