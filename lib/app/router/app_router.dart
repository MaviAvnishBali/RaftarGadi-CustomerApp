import 'package:customer_app/app/router/routes.dart';
import 'package:customer_app/features/auth/otp_screen.dart';
import 'package:customer_app/features/auth/phone_screen.dart';
import 'package:customer_app/features/auth/register_screen.dart';
import 'package:customer_app/features/booking/address_select_screen.dart';
import 'package:customer_app/features/booking/booking_confirmed_screen.dart';
import 'package:customer_app/features/booking/booking_review_screen.dart';
import 'package:customer_app/features/booking/vehicle_select_screen.dart';
import 'package:customer_app/features/bookings/bookings_screen.dart';
import 'package:customer_app/features/home/home_screen.dart';
import 'package:customer_app/features/profile/profile_screen.dart';
import 'package:customer_app/features/shell/home_shell.dart';
import 'package:customer_app/features/splash/splash_screen.dart';
import 'package:customer_app/features/wallet/wallet_screen.dart';
import 'package:customer_app/session/session_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// The app's [GoRouter]. Redirects are driven by [sessionControllerProvider]:
/// unknown → splash, unauthenticated → login, authenticated → the tab shell.
/// A [ValueNotifier] bumped on session changes triggers re-evaluation.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref
    ..onDispose(refresh.dispose)
    ..listen(sessionControllerProvider, (_, _) => refresh.value++);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final status = ref.read(sessionControllerProvider).status;
      final location = state.matchedLocation;

      if (status == SessionStatus.unknown) {
        return location == Routes.splash ? null : Routes.splash;
      }

      final inAuthFlow =
          location.startsWith(Routes.login) || location == Routes.register;
      final atSplash = location == Routes.splash;

      if (status == SessionStatus.unauthenticated) {
        return inAuthFlow ? null : Routes.login;
      }

      // Authenticated: keep them out of splash/login.
      if (inAuthFlow || atSplash) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const PhoneScreen(),
      ),
      GoRoute(
        path: Routes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: Routes.otp,
        builder: (context, state) => OtpScreen(
          phone: state.uri.queryParameters['phone'] ?? '',
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.bookings,
                builder: (context, state) => const BookingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.wallet,
                builder: (context, state) => const WalletScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.bookingAddress,
        builder: (context, state) => const AddressSelectScreen(),
      ),
      GoRoute(
        path: Routes.bookingVehicle,
        builder: (context, state) => const VehicleSelectScreen(),
      ),
      GoRoute(
        path: Routes.bookingReview,
        builder: (context, state) => const BookingReviewScreen(),
      ),
      GoRoute(
        path: Routes.bookingConfirmed,
        builder: (context, state) => BookingConfirmedScreen(
          bookingId: state.uri.queryParameters['id'] ?? '',
        ),
      ),
    ],
  );
});
