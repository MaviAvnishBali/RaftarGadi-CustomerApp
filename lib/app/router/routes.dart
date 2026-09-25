/// Route path constants for the customer app. Referenced everywhere instead of
/// raw strings so navigation targets are typo-safe and discoverable.
abstract final class Routes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String otp = '/login/otp';
  static const String home = '/home';
  static const String bookings = '/bookings';
  static const String wallet = '/wallet';
  static const String profile = '/profile';

  // Booking flow (full-screen, over the tab shell).
  static const String bookingAddress = '/booking';
  static const String bookingVehicle = '/booking/vehicle';
  static const String bookingReview = '/booking/review';
  static const String bookingConfirmed = '/booking/confirmed';
}
