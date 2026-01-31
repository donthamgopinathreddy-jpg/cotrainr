import 'package:health/health.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class HealthTrackingService {
  static final HealthTrackingService _instance =
      HealthTrackingService._internal();
  factory HealthTrackingService() => _instance;
  HealthTrackingService._internal();

  Health? _health;
  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;
  DateTime? _lastPositionTime;
  double _totalDistance = 0.0; // in meters
  DateTime _dayStart = DateTime.now();

  // Health data types we want to read from mobile sensors
  final List<HealthDataType> _healthDataTypes = [
    HealthDataType.STEPS, // Uses device step counter sensor
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_WALKING_RUNNING,
  ];

  bool _isInitialized = false;

  /// Initialize health tracking service and request all permissions
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Request all required permissions
      final permissionsGranted = await _requestAllPermissions();
      if (!permissionsGranted) {
        print('Not all required permissions granted');
        return false;
      }

      _health = Health();

      // Request health data permissions (uses mobile sensors)
      bool? hasPermissions = await _health!.hasPermissions(_healthDataTypes);

      if (hasPermissions == false) {
        hasPermissions = await _health!.requestAuthorization(_healthDataTypes);
      }

      if (hasPermissions == true) {
        _isInitialized = true;
        _dayStart = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        );
        _startLocationTracking();
        return true;
      }

      return false;
    } catch (e) {
      print('Error initializing health tracking: $e');
      return false;
    }
  }

  /// Request all required permissions: health, location, notification, camera, microphone
  Future<bool> _requestAllPermissions() async {
    try {
      // Request location permission (required for distance calculation)
      bool locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!locationServiceEnabled) {
        print('Location services are disabled');
        return false;
      }

      LocationPermission locationPermission =
          await Geolocator.checkPermission();
      if (locationPermission == LocationPermission.denied) {
        locationPermission = await Geolocator.requestPermission();
      }
      if (locationPermission == LocationPermission.deniedForever) {
        print('Location permission permanently denied');
        return false;
      }

      // Request notification permission
      final notificationStatus = await Permission.notification.request();
      if (notificationStatus.isDenied) {
        print('Notification permission denied');
      }

      // Request camera permission (optional but requested)
      final cameraStatus = await Permission.camera.request();
      if (cameraStatus.isDenied) {
        print('Camera permission denied');
      }

      // Request microphone permission (optional but requested)
      final microphoneStatus = await Permission.microphone.request();
      if (microphoneStatus.isDenied) {
        print('Microphone permission denied');
      }

      // Location permission is required, others are optional
      return locationPermission == LocationPermission.whileInUse ||
          locationPermission == LocationPermission.always;
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }

  /// Start tracking location for distance calculation using GPS
  void _startLocationTracking() {
    // Reset distance at start of new day
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    if (todayStart.isAfter(_dayStart)) {
      resetDailyDistance();
      _dayStart = todayStart;
    }

    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy
                .high, // High accuracy for precise distance calculation
            distanceFilter: 5, // Update every 5 meters for better accuracy
            timeLimit: Duration(seconds: 30), // Timeout after 30 seconds
          ),
        ).listen(
          (Position position) {
            // Only process if position has good accuracy
            if (position.accuracy > 0 && position.accuracy < 50) {
              if (_lastPosition != null && _lastPositionTime != null) {
                // Calculate distance between last position and current position using GPS
                final distance = Geolocator.distanceBetween(
                  _lastPosition!.latitude,
                  _lastPosition!.longitude,
                  position.latitude,
                  position.longitude,
                );

                // Only add to total if it's a reasonable distance (not a GPS jump)
                // Also check time difference to avoid adding distance from stale positions
                final timeDiff = DateTime.now().difference(_lastPositionTime!);
                if (distance < 500 && timeDiff.inSeconds < 60) {
                  // Less than 500m and within 60 seconds
                  _totalDistance += distance;
                }
              }

              _lastPosition = position;
              _lastPositionTime = DateTime.now();
            }
          },
          onError: (error) {
            print('Location tracking error: $error');
          },
        );
  }

  /// Get today's steps count from mobile sensors
  /// Uses device step counter sensor (pedometer) for accurate step tracking
  Future<int> getTodaySteps() async {
    if (!_isInitialized || _health == null) {
      await initialize();
      if (!_isInitialized) return 0;
    }

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      // Get steps from mobile sensor (step counter)
      final steps = await _health!.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: startOfDay,
        endTime: now,
      );

      int totalSteps = 0;
      for (var data in steps) {
        if (data.value is NumericHealthValue) {
          totalSteps += (data.value as NumericHealthValue).numericValue.toInt();
        }
      }

      return totalSteps;
    } catch (e) {
      print('Error getting steps from sensor: $e');
      return 0;
    }
  }

  /// Get today's calories burned (auto-calculated from steps)
  /// Uses improved formula: calories = steps * (weight_factor * 0.04)
  /// Average person burns ~0.04 calories per step, adjusted for activity intensity
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
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: startOfDay,
        endTime: now,
      );

      double totalCalories = 0.0;
      for (var data in calories) {
        if (data.value is NumericHealthValue) {
          totalCalories += (data.value as NumericHealthValue).numericValue;
        }
      }

      // If we have actual calories from sensors, return them
      if (totalCalories > 0) {
        return totalCalories;
      }

      // Otherwise, auto-calculate from steps using improved formula
      final steps = await getTodaySteps();
      if (steps == 0) return 0.0;

      // Improved calorie calculation:
      // Base: 0.04 calories per step (average for 70kg person)
      // Adjust for walking speed/intensity based on distance
      final distance = await getTodayDistance(); // in km
      final stepsPerKm = steps > 0 && distance > 0
          ? (steps / distance)
          : 1300; // Average steps per km

      // Intensity factor: faster walking (fewer steps/km) = higher intensity = more calories
      double intensityFactor = 1.0;
      if (stepsPerKm < 1200) {
        intensityFactor = 1.2; // Fast walking/running
      } else if (stepsPerKm < 1400) {
        intensityFactor = 1.0; // Normal walking
      } else {
        intensityFactor = 0.9; // Slow walking
      }

      // Calculate calories: steps * base_calories_per_step * intensity_factor
      final calculatedCalories = steps * 0.04 * intensityFactor;
      return calculatedCalories;
    } catch (e) {
      print('Error getting calories: $e');
      // Fallback to simple step-based calculation
      final steps = await getTodaySteps();
      return steps * 0.04;
    }
  }

  /// Get today's distance in kilometers
  /// Uses location/GPS to calculate distance traveled
  Future<double> getTodayDistance() async {
    if (!_isInitialized || _health == null) {
      await initialize();
      if (!_isInitialized) return 0.0;
    }

    try {
      // Check if it's a new day and reset if needed
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      if (todayStart.isAfter(_dayStart)) {
        resetDailyDistance();
        _dayStart = todayStart;
      }

      // First try to get distance from health data (if available)
      final startOfDay = DateTime(now.year, now.month, now.day);

      final distance = await _health!.getHealthDataFromTypes(
        types: [HealthDataType.DISTANCE_WALKING_RUNNING],
        startTime: startOfDay,
        endTime: now,
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

      // Otherwise, use GPS-based distance tracking (calculated from location)
      // This is more accurate as it uses actual GPS coordinates
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
    _dayStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
  }

  /// Check if all required permissions are granted
  Future<Map<String, bool>> checkPermissions() async {
    final permissions = <String, bool>{};

    // Check health permissions
    try {
      if (_health != null) {
        final hasHealth = await _health!.hasPermissions(_healthDataTypes);
        permissions['health'] = hasHealth == true;
      } else {
        permissions['health'] = false;
      }
    } catch (e) {
      permissions['health'] = false;
    }

    // Check location permission
    final locationPermission = await Geolocator.checkPermission();
    permissions['location'] =
        locationPermission == LocationPermission.whileInUse ||
        locationPermission == LocationPermission.always;

    // Check other permissions
    permissions['notification'] = await Permission.notification.isGranted;
    permissions['camera'] = await Permission.camera.isGranted;
    permissions['microphone'] = await Permission.microphone.isGranted;

    return permissions;
  }

  /// Dispose resources
  void dispose() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isInitialized = false;
  }
}
