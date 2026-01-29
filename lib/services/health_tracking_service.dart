import 'package:health/health.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class HealthTrackingService {
  static final HealthTrackingService _instance = HealthTrackingService._internal();
  factory HealthTrackingService() => _instance;
  HealthTrackingService._internal();

  Health? _health;
  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;
  DateTime? _lastPositionTime;
  double _totalDistance = 0.0; // in meters

  // Health data types we want to read
  final List<HealthDataType> _healthDataTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_WALKING_RUNNING,
  ];

  bool _isInitialized = false;

  /// Initialize health tracking service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _health = Health();
      
      // Request permissions
      bool? hasPermissions = await _health!.hasPermissions(_healthDataTypes);
      
      if (hasPermissions == false) {
        hasPermissions = await _health!.requestAuthorization(_healthDataTypes);
      }

      if (hasPermissions == true) {
        _isInitialized = true;
        _startLocationTracking();
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error initializing health tracking: $e');
      return false;
    }
  }

  /// Start tracking location for distance calculation
  void _startLocationTracking() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) {
      if (_lastPosition != null && _lastPositionTime != null) {
        // Calculate distance between last position and current position
        final distance = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        
        // Only add to total if it's a reasonable distance (not a GPS jump)
        if (distance < 1000) { // Less than 1km
          _totalDistance += distance;
        }
      }
      
      _lastPosition = position;
      _lastPositionTime = DateTime.now();
    });
  }

  /// Get today's steps count
  Future<int> getTodaySteps() async {
    if (!_isInitialized || _health == null) {
      await initialize();
      if (!_isInitialized) return 0;
    }

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      
      final steps = await _health!.getHealthDataFromTypes(
        [HealthDataType.STEPS],
        startOfDay,
        now,
      );

      int totalSteps = 0;
      for (var data in steps) {
        if (data.value is NumericHealthValue) {
          totalSteps += (data.value as NumericHealthValue).numericValue.toInt();
        }
      }

      return totalSteps;
    } catch (e) {
      print('Error getting steps: $e');
      return 0;
    }
  }

  /// Get today's calories burned (auto-calculated from steps)
  Future<double> getTodayCalories() async {
    if (!_isInitialized || _health == null) {
      await initialize();
      if (!_isInitialized) return 0.0;
    }

    try {
      // First try to get actual calories from health data
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      
      final calories = await _health!.getHealthDataFromTypes(
        [HealthDataType.ACTIVE_ENERGY_BURNED],
        startOfDay,
        now,
      );

      double totalCalories = 0.0;
      for (var data in calories) {
        if (data.value is NumericHealthValue) {
          totalCalories += (data.value as NumericHealthValue).numericValue;
        }
      }

      // If we have actual calories, return them
      if (totalCalories > 0) {
        return totalCalories;
      }

      // Otherwise, calculate from steps (approximate: 0.04 calories per step)
      final steps = await getTodaySteps();
      return steps * 0.04;
    } catch (e) {
      print('Error getting calories: $e');
      // Fallback to step-based calculation
      final steps = await getTodaySteps();
      return steps * 0.04;
    }
  }

  /// Get today's distance in kilometers
  Future<double> getTodayDistance() async {
    if (!_isInitialized || _health == null) {
      await initialize();
      if (!_isInitialized) return 0.0;
    }

    try {
      // First try to get distance from health data
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      
      final distance = await _health!.getHealthDataFromTypes(
        [HealthDataType.DISTANCE_WALKING_RUNNING],
        startOfDay,
        now,
      );

      double totalDistance = 0.0;
      for (var data in distance) {
        if (data.value is NumericHealthValue) {
          totalDistance += (data.value as NumericHealthValue).numericValue;
        }
      }

      // If we have distance from health data, return it (in meters, convert to km)
      if (totalDistance > 0) {
        return totalDistance / 1000.0; // Convert meters to kilometers
      }

      // Otherwise, use GPS-based distance tracking
      return _totalDistance / 1000.0; // Convert meters to kilometers
    } catch (e) {
      print('Error getting distance: $e');
      // Fallback to GPS-based distance
      return _totalDistance / 1000.0;
    }
  }

  /// Reset daily distance tracking (call at start of new day)
  void resetDailyDistance() {
    _totalDistance = 0.0;
    _lastPosition = null;
    _lastPositionTime = null;
  }

  /// Dispose resources
  void dispose() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isInitialized = false;
  }
}
