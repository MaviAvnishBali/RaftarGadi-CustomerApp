import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repositories/repositories.dart';
import 'package:shared_models/shared_models.dart';

/// The in-progress booking as the user moves through the flow (address →
/// vehicle → review). Held in a [Notifier] so it survives across the
/// full-screen route steps.
class BookingDraft {
  const BookingDraft({
    this.pickup,
    this.drop,
    this.vehicleType,
    this.selectedVehicle,
    this.fare,
  });

  final Address? pickup;
  final Address? drop;
  final VehicleType? vehicleType;
  final DynamicVehicleType? selectedVehicle;
  final FareEstimate? fare;

  bool get hasRoute => pickup != null && drop != null;
  bool get isPriced => (selectedVehicle != null || vehicleType != null) && fare != null;

  BookingDraft copyWith({
    Address? pickup,
    Address? drop,
    VehicleType? vehicleType,
    DynamicVehicleType? selectedVehicle,
    FareEstimate? fare,
  }) {
    return BookingDraft(
      pickup: pickup ?? this.pickup,
      drop: drop ?? this.drop,
      vehicleType: vehicleType ?? this.vehicleType,
      selectedVehicle: selectedVehicle ?? this.selectedVehicle,
      fare: fare ?? this.fare,
    );
  }
}

class BookingDraftController extends Notifier<BookingDraft> {
  @override
  BookingDraft build() => const BookingDraft();

  void setPickup(Address address) => state = state.copyWith(pickup: address);

  void setDrop(Address address) => state = state.copyWith(drop: address);

  /// Records the chosen vehicle and its quoted fare (computed by the vehicle
  /// selection screen), advancing the draft to a priced state.
  void chooseVehicle(DynamicVehicleType vehicle, FareEstimate fare) =>
      state = state.copyWith(
        selectedVehicle: vehicle,
        vehicleType: vehicle.legacyType,
        fare: fare,
      );

  void chooseLegacyVehicle(VehicleType type, FareEstimate fare) =>
      state = state.copyWith(vehicleType: type, fare: fare);

  /// Creates the booking for [customerId] from the current draft.
  Future<Result<Booking>> confirm(String customerId) {
    final draft = state;
    final vehicle = draft.selectedVehicle;
    return ref
        .read(bookingRepositoryProvider)
        .createBooking(
          customerId: customerId,
          vehicleType: draft.vehicleType ?? vehicle?.legacyType ?? VehicleType.bike,
          vehicleTypeId: vehicle?.id,
          vehicleTypeName: vehicle?.name,
          pickup: draft.pickup!,
          drop: draft.drop!,
          fare: draft.fare!,
        );
  }

  void reset() => state = const BookingDraft();
}

final bookingDraftControllerProvider =
    NotifierProvider<BookingDraftController, BookingDraft>(
      BookingDraftController.new,
    );
