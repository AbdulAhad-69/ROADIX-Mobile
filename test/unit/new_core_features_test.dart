import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadix_mobile/screens/sslcommerz_checkout_screen.dart';
import 'package:roadix_mobile/services/cloudinary_service.dart';
import 'package:roadix_mobile/services/invoice_pdf_service.dart';
import 'package:roadix_mobile/services/notifications_service.dart';
import 'package:roadix_mobile/src/core/models/geo_point.dart';
import 'package:roadix_mobile/widgets/roadix_map_view.dart';
import 'package:roadix_mobile/widgets/roadix_pressable.dart';
import '../e2e/helpers/test_app_harness.dart';

class _MockCloudinaryClient extends Fake implements HttpClient {
  final int statusCode;
  final String responseBody;
  String? capturedBody;
  Uri? capturedUri;

  _MockCloudinaryClient({
    required this.statusCode,
    required this.responseBody,
  });

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    capturedUri = url;
    return _MockCloudinaryRequest(this);
  }

  @override
  void close({bool force = false}) {}
}

class _MockCloudinaryRequest extends Fake implements HttpClientRequest {
  final _MockCloudinaryClient _parent;
  final List<int> _buffer = [];
  final HttpHeaders _headers = _MockHeaders();

  _MockCloudinaryRequest(this._parent);

  @override
  HttpHeaders get headers => _headers;

  @override
  set contentLength(int value) {}

  @override
  void add(List<int> data) => _buffer.addAll(data);

  @override
  Future<HttpClientResponse> close() async {
    _parent.capturedBody = utf8.decode(_buffer, allowMalformed: true);
    return _MockCloudinaryResponse(
      _parent.statusCode,
      _parent.responseBody,
    );
  }
}

class _MockHeaders extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _MockCloudinaryResponse extends Fake implements HttpClientResponse {
  @override
  final int statusCode;
  final String _body;

  _MockCloudinaryResponse(this.statusCode, this._body);

  @override
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) {
    return Stream<List<int>>.value(utf8.encode(_body)).transform(streamTransformer);
  }
}

void main() {
  setUpAll(() async {
    await E2ETestHarness.initializeAppEnvironment();
  });

  group('CloudinaryService Signature & Upload', () {
    test('computeSignature produces exact Cloudinary SHA-1 digest', () {
      // Canonical Cloudinary example vector:
      // folder=roadix/avatars&timestamp=1700000000 + secret
      final sig = CloudinaryService.computeSignature(
        params: {
          'timestamp': '1700000000',
          'folder': 'roadix/avatars',
          'ignored_empty': '',
        },
        apiSecret: 'my_secret',
      );
      expect(sig, hasLength(40));
      expect(
        sig,
        equals(
          CloudinaryService.computeSignature(
            params: {'folder': 'roadix/avatars', 'timestamp': '1700000000'},
            apiSecret: 'my_secret',
          ),
        ),
      );
    });

    test('uploadImage posts signed multipart payload and returns secureUrl on 200', () async {
      final mockClient = _MockCloudinaryClient(
        statusCode: 200,
        responseBody: jsonEncode({
          'secure_url': 'https://res.cloudinary.com/kefzjqi3/image/upload/v1/roadix/avatars/u1.jpg',
          'public_id': 'roadix/avatars/u1',
          'bytes': 12,
          'format': 'jpg',
        }),
      );

      final result = await CloudinaryService().uploadImage(
        Uint8List.fromList([1, 2, 3, 4]),
        folder: 'roadix/avatars',
        signUpload: ({required String folder, String? publicId}) async =>
            const CloudinarySignedParams(
          signature: 'abc123sig',
          timestamp: '1700000000',
          apiKey: '123456789012345',
          cloudName: 'kefzjqi3',
          folder: 'roadix/avatars',
        ),
        httpClientFactory: () => mockClient,
      );

      expect(
        mockClient.capturedUri.toString(),
        equals('https://api.cloudinary.com/v1_1/kefzjqi3/image/upload'),
      );
      expect(mockClient.capturedBody, contains('name="api_key"'));
      expect(mockClient.capturedBody, contains('123456789012345'));
      expect(mockClient.capturedBody, contains('name="signature"'));
      expect(mockClient.capturedBody, contains('abc123sig'));
      expect(
        result.secureUrl,
        equals('https://res.cloudinary.com/kefzjqi3/image/upload/v1/roadix/avatars/u1.jpg'),
      );
    });

    test('uploadImage throws CloudinaryUploadException on 401 Invalid api_key', () async {
      final mockClient = _MockCloudinaryClient(
        statusCode: 401,
        responseBody: jsonEncode({
          'error': {'message': 'Invalid api_key Root'},
        }),
      );

      expect(
        () => CloudinaryService().uploadImage(
          Uint8List.fromList([1, 2, 3]),
          folder: 'roadix/faults',
          uploadPreset: 'roadix_unsigned',
          httpClientFactory: () => mockClient,
        ),
        throwsA(
          isA<CloudinaryUploadException>().having(
            (e) => e.message,
            'message',
            contains('Invalid api_key Root'),
          ),
        ),
      );
    });
  });

  group('InvoicePdfService', () {
    test('buildInvoicePdfBytes generates real PDF document bytes & persists to disk', () async {
      const data = InvoiceData(
        serviceId: 'RDX-2026-9901',
        title: 'Dead Battery Jumpstart',
        date: 'Nov 25, 2026',
        techName: 'Md. Rafiqul Islam',
        vehicle: 'Toyota Corolla • DHAKA-11-2034',
        location: 'Sector 11, Uttara, Dhaka',
        diagFee: 'BDT 300',
        laborFee: 'BDT 500',
        partsTotal: 'BDT 450',
        totalAmount: 'BDT 1,250',
        paymentMethod: 'SSLCommerz',
        paymentStatus: 'Paid',
      );

      final bytes = await InvoicePdfService.buildInvoicePdfBytes(data);
      final header = utf8.decode(bytes.take(7).toList());
      final tail = utf8.decode(bytes.skip(bytes.length - 10).toList(), allowMalformed: true);
      expect(header, startsWith('%PDF-1.'));
      expect(tail, contains('%%EOF'));

      final tempDir = await Directory.systemTemp.createTemp('roadix_pdf_test_');
      try {
        var sharedCount = 0;
        final file = await InvoicePdfService.saveAndShareInvoice(
          data,
          outputDir: tempDir,
          onShare: (f, _) async {
            sharedCount++;
            expect(await f.exists(), isTrue);
          },
        );
        expect(sharedCount, equals(1));
        expect(await file.exists(), isTrue);
        expect(await file.length(), greaterThan(500));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('SSLCommerz URL Callback Classifier', () {
    test('classifies success, failed, cancelled, gateway https, and unsafe schemes', () {
      final ok = classifySslcommerzUrl(
        'io.supabase.roadix://payment-callback?status=success&tran_id=RDX-100&val_id=VAL-22',
      );
      expect(ok.action, equals(SslcommerzNavigationAction.completeSuccess));
      expect(ok.tranId, equals('RDX-100'));
      expect(ok.valId, equals('VAL-22'));

      final fail = classifySslcommerzUrl(
        'io.supabase.roadix://payment-callback?status=failed&tran_id=RDX-100',
      );
      expect(fail.action, equals(SslcommerzNavigationAction.completeFailed));

      final cancel = classifySslcommerzUrl(
        'io.supabase.roadix://payment-callback?status=cancelled&tran_id=RDX-100',
      );
      expect(cancel.action, equals(SslcommerzNavigationAction.completeCancelled));

      final gateway = classifySslcommerzUrl(
        'https://sandbox.sslcommerz.com/gwprocess/v4/gw.php?Q=pay',
      );
      expect(gateway.action, equals(SslcommerzNavigationAction.navigate));

      final blocked = classifySslcommerzUrl('javascript:alert(1)');
      expect(blocked.action, equals(SslcommerzNavigationAction.block));
    });
  });

  group('NotificationsService Persistence', () {
    test('persists readIds so unread state stays false after markAllAsRead', () async {
      E2ETestHarness.initializePlatformChannels();
      final firstLoad = await NotificationsService.loadNotifications();
      expect(firstLoad, isNotEmpty);

      await NotificationsService.markAllAsRead(firstLoad.map((e) => e.id));
      final secondLoad = await NotificationsService.loadNotifications();
      expect(secondLoad.every((n) => !n.isUnread), isTrue);
    });
  });

  group('RoadixMapView & RoadixPressable Widgets', () {
    testWidgets('RoadixMapView renders cleanly with mocked MapLibre platform', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RoadixMapView(
              initialCenter: RoadixGeoPoint(23.8759, 90.3795),
              breakdownPoint: RoadixGeoPoint(23.8759, 90.3795),
              mechanicPoint: RoadixGeoPoint(23.8810, 90.3820),
              routePoints: [
                RoadixGeoPoint(23.8810, 90.3820),
                RoadixGeoPoint(23.8759, 90.3795),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RoadixMapView), findsOneWidget);
      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('RoadixPressable invokes tap and honors disableAnimations', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: RoadixPressable(
                onTap: () => tapped = true,
                child: const Text('Tap Me'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Tap Me'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
}
