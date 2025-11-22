import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:waiting_room_app_5/local_queue_service.dart';
import 'package:waiting_room_app_5/queue_provider.dart'; // ✅ corrige ici
import 'package:waiting_room_app_5/geolocation_service.dart'; // ✅ corrige ici
import 'queue_provider_geolocation_test.mocks.dart'; // ✅ le bon import


@GenerateMocks([GeolocationService])
void main() async {
  // ✅ Initialize Supabase once for tests
  await Supabase.initialize(
    url: 'https://irmogsjkatbbbybedaop.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlybW9nc2prYXRiYmJ5YmVkYW9wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAyMzk0NTMsImV4cCI6MjA3NTgxNTQ1M30.BlF1_z0gRyv1TNhCAHHfbsbWTf_oRErIVAMsiaqCIKA',
  );

  test('addClient saves client with geolocation', () async {
    final mockGeo = MockGeolocationService();

    final mockPos = Position(
      longitude: -122.4194,
      latitude: 37.7749,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0, // <— ajoutés
      headingAccuracy: 0.0,  // <— ajoutés
    );

    when(mockGeo.getCurrentPosition()).thenAnswer((_) async => mockPos);

    final provider = QueueProvider(
      geoService: mockGeo,
      localDb: LocalQueueService(inMemory: true),
    );

    await provider.addClient('Test User');

    final client = provider.clients.last;
    expect(client['lat'], 37.7749);
    expect(client['lng'], -122.4194);
  });
}
