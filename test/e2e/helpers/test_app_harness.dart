import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:roadix_mobile/services/demo_session.dart';
import 'package:roadix_mobile/src/core/config/app_config.dart';

/// Hermetic E2E Test Harness for ROADIX Mobile
/// Intercepts native platform channels (Geolocator, SharedPreferences, UrlLauncher,
/// PathProvider, FlutterSecureStorage, MapLibre) and provides offline HTTP simulation.
class E2ETestHarness {
  static const MethodChannel _sharedPrefsChannel =
      MethodChannel('plugins.flutter.io/shared_preferences');
  static const MethodChannel _geolocatorChannel =
      MethodChannel('flutter.baseflow.com/geolocator');
  static const MethodChannel _urlLauncherChannel =
      MethodChannel('plugins.flutter.io/url_launcher');
  static const MethodChannel _pathProviderChannel =
      MethodChannel('plugins.flutter.io/path_provider');
  static const MethodChannel _secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  // GPS Simulation State
  static double mockLat = 23.8759;
  static double mockLng = 90.3795;
  static double mockAccuracy = 8.0;
  static bool mockLocationServiceEnabled = true;
  static int mockLocationPermission = 3; // LocationPermission.whileInUse (index 3)
  static int gpsQueryCount = 0;

  // URL Launcher History
  static final List<String> launchedUrls = [];

  // In-Memory Secure Storage
  static final Map<String, String> _secureStorage = {};

  // In-Memory Shared Preferences
  static final Map<String, Object> _sharedPreferences = {};

  // Custom Geocode Address Overrides: key = "$lat,$lng" rounded to 4 decimals
  static final Map<String, String> _geocodingOverrides = {};

  // In-Memory Profile Mock State
  static Map<String, dynamic> mockProfile = {
    'id': 'demo-motorist',
    'full_name': 'Motorist',
    'phone': '+8801711000001',
    'role': 'motorist',
    'is_nid_verified': true,
    'avatar_url': null,
  };

  // In-Memory Wallets Mock State
  static List<Map<String, dynamic>> mockWallets = [
    {
      'id': 'w-1',
      'provider': 'bKash',
      'account_number': '01711000001',
      'is_primary': true,
    }
  ];

  // Intercepted REST Payload Tracking
  static Map<String, dynamic>? lastRestPayload;

  // SignOut override callback for resilience testing
  static Future<void> Function()? onSignOutOverride;

  static bool _initialized = false;

  /// Initializes platform channel interception handlers and loads AppConfig / Supabase stubs.
  static Future<void> initializeAppEnvironment() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    initializePlatformChannels();
    HttpOverrides.global = _E2EHttpOverrides();

    if (!_initialized) {
      await AppConfig.initialize();
      try {
        await Supabase.initialize(
          url: AppConfig.supabaseUrl,
          // ignore: deprecated_member_use
          anonKey: AppConfig.supabaseAnonKey,
        );
      } catch (_) {
        // Supabase already initialized or offline mock active
      }
      _initialized = true;
    }
  }

  /// Sets up mock method call handlers on the default binary messenger.
  static void initializePlatformChannels() {
    MapLibrePlatform.createInstance = () => _MockMapLibrePlatform();

    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    // 1. SharedPreferences
    messenger.setMockMethodCallHandler(_sharedPrefsChannel, (MethodCall call) async {
      if (call.method == 'getAll') {
        return Map<String, Object>.from(_sharedPreferences);
      }
      if (call.method == 'setString') {
        final key = call.arguments['key'] as String;
        final value = call.arguments['value'] as String;
        _sharedPreferences[key] = value;
        return true;
      }
      if (call.method == 'setBool') {
        final key = call.arguments['key'] as String;
        final value = call.arguments['value'] as bool;
        _sharedPreferences[key] = value;
        return true;
      }
      if (call.method == 'remove') {
        final key = call.arguments['key'] as String;
        _sharedPreferences.remove(key);
        return true;
      }
      if (call.method == 'clear') {
        _sharedPreferences.clear();
        return true;
      }
      return true;
    });

    // 2. Geolocator
    messenger.setMockMethodCallHandler(_geolocatorChannel, (MethodCall call) async {
      if (call.method == 'checkPermission') {
        return mockLocationPermission;
      }
      if (call.method == 'requestPermission') {
        return mockLocationPermission;
      }
      if (call.method == 'isLocationServiceEnabled') {
        return mockLocationServiceEnabled;
      }
      if (call.method == 'getCurrentPosition' || call.method == 'getLastKnownPosition') {
        gpsQueryCount++;
        if (!mockLocationServiceEnabled) {
          throw PlatformException(
            code: 'LOCATION_SERVICES_DISABLED',
            message: 'Location services are disabled on this device.',
          );
        }
        if (mockLocationPermission == 0 || mockLocationPermission == 1) {
          // denied = 0, deniedForever = 1
          throw PlatformException(
            code: 'PERMISSION_DENIED',
            message: 'Location permission was denied.',
          );
        }
        return <String, dynamic>{
          'latitude': mockLat,
          'longitude': mockLng,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'altitude': 12.0,
          'accuracy': mockAccuracy,
          'heading': 0.0,
          'floor': null,
          'speed': 0.0,
          'speed_accuracy': 0.0,
          'is_mocked': true,
        };
      }
      if (call.method == 'openAppSettings' || call.method == 'openLocationSettings') {
        return true;
      }
      if (call.method == 'getLocationAccuracy') {
        return 1; // High accuracy
      }
      return null;
    });

    // 3. UrlLauncher
    messenger.setMockMethodCallHandler(_urlLauncherChannel, (MethodCall call) async {
      if (call.method == 'canLaunch') {
        return true;
      }
      if (call.method == 'launch') {
        final url = (call.arguments as Map?)?['url'] as String? ?? '';
        launchedUrls.add(url);
        return true;
      }
      if (call.method == 'closeWebView') {
        return null;
      }
      return true;
    });

    // 4. PathProvider
    messenger.setMockMethodCallHandler(_pathProviderChannel, (MethodCall call) async {
      return '.';
    });

    // 5. FlutterSecureStorage
    messenger.setMockMethodCallHandler(_secureStorageChannel, (MethodCall call) async {
      final key = (call.arguments as Map?)?['key'] as String?;
      if (call.method == 'read') {
        return key != null ? _secureStorage[key] : null;
      }
      if (call.method == 'write') {
        final value = (call.arguments as Map?)?['value'] as String?;
        if (key != null && value != null) {
          _secureStorage[key] = value;
        }
        return true;
      }
      if (call.method == 'delete') {
        if (E2ETestHarness.onSignOutOverride != null) {
          await E2ETestHarness.onSignOutOverride!();
        }
        if (key != null) _secureStorage.remove(key);
        return true;
      }
      if (call.method == 'deleteAll') {
        if (E2ETestHarness.onSignOutOverride != null) {
          await E2ETestHarness.onSignOutOverride!();
        }
        _secureStorage.clear();
        return true;
      }
      if (call.method == 'readAll') {
        return Map<String, String>.from(_secureStorage);
      }
      if (call.method == 'containsKey') {
        return key != null && _secureStorage.containsKey(key);
      }
      return null;
    });
  }

  /// Sets the simulated GPS coordinates and permission parameters.
  static void setMockGps({
    required double lat,
    required double lng,
    double accuracy = 8.0,
    bool serviceEnabled = true,
    int permission = 3, // 3 = LocationPermission.whileInUse
  }) {
    mockLat = lat;
    mockLng = lng;
    mockAccuracy = accuracy;
    mockLocationServiceEnabled = serviceEnabled;
    mockLocationPermission = permission;
  }

  /// Register custom reverse-geocoding response for a coordinate pair
  static void registerGeocodeResult(double lat, double lng, String address) {
    final key = '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
    _geocodingOverrides[key] = address;
  }

  /// Wraps a widget in a standard test MaterialApp with responsive screen size.
  static Widget wrapWithApp(
    Widget child, {
    Size? physicalSize,
    WidgetTester? tester,
    NavigatorObserver? navigatorObserver,
  }) {
    if (physicalSize != null && tester != null) {
      tester.view.physicalSize = physicalSize;
      tester.view.devicePixelRatio = 1.0;
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorObservers: navigatorObserver != null ? [navigatorObserver] : [],
      home: child,
    );
  }

  /// Clears in-memory SharedPreferences and FlutterSecureStorage maps.
  static void resetStorage() {
    _sharedPreferences.clear();
    _secureStorage.clear();
  }

  /// Resets test viewport, clears platform launcher history, and resets GPS count.
  static Future<void> cleanUp(WidgetTester tester) async {
    // Unmount any active widget tree to cancel periodic timers
    try {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 60));
    } catch (_) {}

    try {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    } catch (_) {}

    _sharedPreferences.clear();
    _secureStorage.clear();
    launchedUrls.clear();
    _geocodingOverrides.clear();
    DemoSession.clear();
    gpsQueryCount = 0;
    mockProfile = {
      'id': 'demo-motorist',
      'full_name': 'Motorist',
      'phone': '+8801711000001',
      'role': 'motorist',
      'is_nid_verified': true,
      'avatar_url': null,
    };
    mockWallets = [
      {
        'id': 'w-1',
        'provider': 'bKash',
        'account_number': '01711000001',
        'is_primary': true,
      }
    ];
    lastRestPayload = null;
    onSignOutOverride = null;
    setMockGps(lat: 23.8759, lng: 90.3795, accuracy: 8.0, serviceEnabled: true, permission: 3);
  }
}

/// Headless mock for MapLibre platform view preventing MissingPluginException and LateInitializationError
class _MockMapLibrePlatform extends MapLibrePlatform {
  bool _viewCreated = false;

  @override
  Future<void> initPlatform(int id) async {}

  @override
  Widget buildView(
    Map<String, dynamic> creationParams,
    OnPlatformViewCreatedCallback onPlatformViewCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  ) {
    if (!_viewCreated) {
      _viewCreated = true;
      scheduleMicrotask(() {
        try {
          onPlatformViewCreated(1);
        } catch (_) {}
      });
    }
    return const SizedBox.expand();
  }

  @override
  Future<bool?> animateCamera(CameraUpdate cameraUpdate, {Duration? duration}) async {
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter) return null;
    if (invocation.isMethod) {
      return Future.value(null);
    }
    return super.noSuchMethod(invocation);
  }
}

/// HTTP Overrides for offline test execution
class _E2EHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient();
  }
}

class _MockHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _MockHttpClientRequest(url);
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _MockHttpClientRequest(url);
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpClientRequest implements HttpClientRequest {
  @override
  final Uri uri;
  _MockHttpClientRequest(this.uri);

  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  int contentLength = -1;

  @override
  bool persistentConnection = true;

  @override
  bool bufferOutput = true;

  @override
  Encoding encoding = utf8;

  final List<int> _bodyBytes = [];

  @override
  void add(List<int> data) {
    _bodyBytes.addAll(data);
  }

  @override
  void write(Object? obj) {
    if (obj != null) _bodyBytes.addAll(utf8.encode(obj.toString()));
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) {
    write(objects.join(separator));
  }

  @override
  void writeln([Object? obj = '']) {
    write('$obj\n');
  }

  @override
  void writeCharCode(int charCode) {
    _bodyBytes.add(charCode);
  }

  @override
  Future addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      _bodyBytes.addAll(chunk);
    }
  }

  @override
  Future flush() async {}

  @override
  Future abort([Object? exception, StackTrace? stackTrace]) async {}

  @override
  Future<HttpClientResponse> close() async {
    // 1. Geoapify Reverse Geocoding
    if (uri.host.contains('geoapify.com')) {
      final lat = double.tryParse(uri.queryParameters['lat'] ?? '') ?? 0.0;
      final lon = double.tryParse(uri.queryParameters['lon'] ?? '') ?? 0.0;
      final coordKey = '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';

      String formattedAddress;
      String city;
      if (E2ETestHarness._geocodingOverrides.containsKey(coordKey)) {
        formattedAddress = E2ETestHarness._geocodingOverrides[coordKey]!;
        city = formattedAddress.split(',').first.trim();
      } else if ((lat - 22.3569).abs() < 0.2 && (lon - 91.8215).abs() < 0.2) {
        // Chittagong
        formattedAddress = 'Agrabad Commercial Area, Chittagong, Bangladesh';
        city = 'Chittagong';
      } else if ((lat - 24.8949).abs() < 0.2 && (lon - 91.8687).abs() < 0.2) {
        // Sylhet
        formattedAddress = 'Zindabazar, Sylhet, Bangladesh';
        city = 'Sylhet';
      } else if ((lat - 22.8456).abs() < 0.2 && (lon - 89.5403).abs() < 0.2) {
        // Khulna
        formattedAddress = 'Shibbari More, Khulna, Bangladesh';
        city = 'Khulna';
      } else if ((lat - 24.3636).abs() < 0.2 && (lon - 88.6241).abs() < 0.2) {
        // Rajshahi
        formattedAddress = 'Saheb Bazar, Rajshahi, Bangladesh';
        city = 'Rajshahi';
      } else {
        // Default Dhaka / Uttara Corridor
        formattedAddress = 'Sector 11, Uttara, Dhaka, Bangladesh';
        city = 'Dhaka';
      }

      final jsonBody = jsonEncode({
        'features': [
          {
            'properties': {
              'formatted': formattedAddress,
              'street': 'Main Road',
              'city': city,
              'district': city,
            }
          }
        ]
      });
      return _MockHttpClientResponse(utf8.encode(jsonBody), 200);
    }

    // 2. OpenStreetMap Nominatim
    if (uri.host.contains('nominatim.openstreetmap.org')) {
      final lat = double.tryParse(uri.queryParameters['lat'] ?? '') ?? 0.0;
      final lon = double.tryParse(uri.queryParameters['lon'] ?? '') ?? 0.0;
      final coordKey = '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';

      String? display;
      if (E2ETestHarness._geocodingOverrides.containsKey(coordKey)) {
        display = E2ETestHarness._geocodingOverrides[coordKey]!;
      } else if ((lat - 22.3569).abs() < 0.2 && (lon - 91.8215).abs() < 0.2) {
        display = 'Agrabad Commercial Area, Chittagong, Bangladesh';
      } else if ((lat - 24.8949).abs() < 0.2 && (lon - 91.8687).abs() < 0.2) {
        display = 'Zindabazar, Sylhet, Bangladesh';
      } else if ((lat - 22.8456).abs() < 0.2 && (lon - 89.5403).abs() < 0.2) {
        display = 'Shibbari More, Khulna, Bangladesh';
      } else if ((lat - 24.3636).abs() < 0.2 && (lon - 88.6241).abs() < 0.2) {
        display = 'Saheb Bazar, Rajshahi, Bangladesh';
      } else if ((lat - 23.81).abs() < 0.25 && (lon - 90.40).abs() < 0.25) {
        display = 'Uttara Sector 11, Dhaka, Bangladesh';
      }

      if (display == null) {
        return _MockHttpClientResponse(utf8.encode('{}'), 404);
      }

      final jsonBody = jsonEncode({'display_name': display});
      return _MockHttpClientResponse(utf8.encode(jsonBody), 200);
    }

    // 2b. OSRM route queries fail cleanly to offline Haversine fallback in tests
    if (uri.host.contains('project-osrm.org')) {
      return _MockHttpClientResponse(utf8.encode('{}'), 404);
    }

    // 3. Supabase Auth API simulation
    if (uri.path.contains('/auth/v1/')) {
      if (E2ETestHarness.onSignOutOverride != null) {
        await E2ETestHarness.onSignOutOverride!();
      }
      return _MockHttpClientResponse(utf8.encode('{}'), 200);
    }

    // 4. Supabase REST API simulation
    if (uri.path.contains('/rest/v1/')) {
      if (uri.path.contains('/profiles')) {
        if (_bodyBytes.isNotEmpty) {
          try {
            final payload = jsonDecode(utf8.decode(_bodyBytes));
            if (payload is Map<String, dynamic>) {
              E2ETestHarness.lastRestPayload = Map<String, dynamic>.from(payload);
              E2ETestHarness.mockProfile.addAll(payload);
            }
          } catch (_) {}
        }
        return _MockHttpClientResponse(utf8.encode(jsonEncode(E2ETestHarness.mockProfile)), 200);
      }
      if (uri.path.contains('/vehicles')) {
        final vehicles = [
          {
            'id': 'v-1',
            'model': 'Toyota Premio',
            'plate': 'Dhaka Metro GA-11-2034',
            'fuel': 'Octane',
            'type': 'Passenger Car',
            'is_primary': true,
          }
        ];
        return _MockHttpClientResponse(utf8.encode(jsonEncode(vehicles)), 200);
      }
      if (uri.path.contains('/emergency_contacts')) {
        return _MockHttpClientResponse(utf8.encode('[]'), 200);
      }
      if (uri.path.contains('/wallets')) {
        if (_bodyBytes.isNotEmpty) {
          try {
            final payload = jsonDecode(utf8.decode(_bodyBytes));
            if (payload is Map<String, dynamic>) {
              final wallet = Map<String, dynamic>.from(payload);
              wallet.putIfAbsent('id', () => 'w-${E2ETestHarness.mockWallets.length + 1}');
              E2ETestHarness.mockWallets.add(wallet);
            } else if (payload is Map) {
              final wallet = Map<String, dynamic>.from(payload);
              wallet.putIfAbsent('id', () => 'w-${E2ETestHarness.mockWallets.length + 1}');
              E2ETestHarness.mockWallets.add(wallet);
            } else if (payload is List) {
              for (final item in payload) {
                if (item is Map) {
                  final wallet = Map<String, dynamic>.from(item);
                  wallet.putIfAbsent('id', () => 'w-${E2ETestHarness.mockWallets.length + 1}');
                  E2ETestHarness.mockWallets.add(wallet);
                }
              }
            }
          } catch (_) {}
        }
        return _MockHttpClientResponse(
          utf8.encode(jsonEncode(E2ETestHarness.mockWallets)),
          200,
        );
      }
      return _MockHttpClientResponse(utf8.encode('[]'), 200);
    }

    // 4. Image / CDN requests (return valid 1x1 transparent PNG)
    final transparentPng = <int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
      0x42, 0x60, 0x82,
    ];
    return _MockHttpClientResponse(transparentPng, 200);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isSetter) return null;
    if (invocation.isGetter) return null;
    if (invocation.isMethod) return Future.value(null);
    return null;
  }
}

class _MockHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _headers = {};
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers.putIfAbsent(name.toLowerCase(), () => []).add(value.toString());
  }
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[name.toLowerCase()] = [value.toString()];
  }
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isSetter) return null;
    if (invocation.isGetter) return null;
    if (invocation.isMethod) return null;
    return null;
  }
}

class _MockHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  final List<int> _bytes;
  @override
  final int statusCode;

  _MockHttpClientResponse(this._bytes, this.statusCode);

  @override
  int get contentLength => _bytes.length;

  @override
  String get reasonPhrase => 'OK';

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  bool get persistentConnection => true;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  HttpHeaders get headers => _MockHttpHeaders();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter) return null;
    if (invocation.isSetter) return null;
    if (invocation.isMethod) return Future.value(null);
    return null;
  }
}
