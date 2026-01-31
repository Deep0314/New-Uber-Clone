import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uber_clone/core/providers/providers.dart';
import 'package:uber_clone/domain/models/driver.dart';
import 'package:uber_clone/domain/models/ride.dart';
import 'package:uber_clone/domain/models/user.dart';

final allRidesProvider = FutureProvider.autoDispose<List<Ride>>((ref) async {
  final rideRepo = ref.read(rideRepositoryProvider);
  return await rideRepo.getAllRides();
});

final allDriversProvider =
    FutureProvider.autoDispose<List<Driver>>((ref) async {
  final driverRepo = ref.read(driverRepositoryProvider);
  return await driverRepo.getAllDrivers();
});

final adminStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final rides = await ref.watch(allRidesProvider.future);
  final drivers = await ref.watch(allDriversProvider.future);

  final totalRides = rides.length;
  final completedRides =
      rides.where((r) => r.status == RideStatus.completed).length;
  final cancelledRides =
      rides.where((r) => r.status == RideStatus.cancelled).length;
  final activeRides = rides
      .where((r) =>
          r.status == RideStatus.searching ||
          r.status == RideStatus.assigned ||
          r.status == RideStatus.arrived ||
          r.status == RideStatus.ongoing)
      .length;

  final totalDrivers = drivers.length;
  final onlineDrivers = drivers.where((d) => d.isOnline).length;

  final totalRevenue = rides
      .where((r) => r.status == RideStatus.completed && r.actualFare != null)
      .fold<double>(0, (sum, r) => sum + (r.actualFare ?? 0));

  return {
    'totalRides': totalRides,
    'completedRides': completedRides,
    'cancelledRides': cancelledRides,
    'activeRides': activeRides,
    'totalDrivers': totalDrivers,
    'onlineDrivers': onlineDrivers,
    'totalRevenue': totalRevenue,
  };
});
