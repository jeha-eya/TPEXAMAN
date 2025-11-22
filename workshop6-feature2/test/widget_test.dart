import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:waiting_room_app_5/queue_provider.dart';
import 'package:waiting_room_app_5/screens/waiting_room_screen.dart';
import 'package:waiting_room_app_5/local_queue_service.dart';
import 'package:waiting_room_app_5/geolocation_service.dart';

// Mock classes
class MockQueueProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _clients = [];
  
  List<Map<String, dynamic>> get clients => _clients;
  bool get isSyncing => false;
  
  Future<void> initialize() async {}
  
  Future<void> addClient(String name) async {
    _clients.add({
      'id': 'test-${_clients.length + 1}',
      'name': name,
      'lat': 51.5074,
      'lng': -0.1278,
      'created_at': DateTime.now().toIso8601String(),
      'is_synced': 0,
    });
    notifyListeners();
  }
  
  Future<void> deleteClient(String id) async {
    _clients.removeWhere((client) => client['id'] == id);
    notifyListeners();
  }
}

void main() {
  group('WaitingRoomScreen Widget Tests', () {
    testWidgets('Displays location when available', (WidgetTester tester) async {
      final provider = MockQueueProvider();
      
      // Add a client with location
      await provider.addClient('Sam');
      
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            home: WaitingRoomScreen(),
          ),
        ),
      );

      expect(find.text('Sam'), findsOneWidget);
      expect(find.textContaining('51.5074'), findsOneWidget);
      expect(find.textContaining('-0.1278'), findsOneWidget);
    });

    testWidgets('Displays "Location not captured" when lat is null', (WidgetTester tester) async {
      final provider = MockQueueProvider();
      
      // Manually add a client without location
      provider._clients.add({
        'id': 'test-1',
        'name': 'Alice',
        'lat': null,
        'lng': null,
        'created_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      });
      provider.notifyListeners();
      
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            home: WaitingRoomScreen(),
          ),
        ),
      );

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('📍 Location not captured'), findsOneWidget);
    });

    testWidgets('Shows sync status icons correctly', (WidgetTester tester) async {
      final provider = MockQueueProvider();
      
      // Add synced and unsynced clients
      provider._clients.addAll([
        {
          'id': 'synced-1',
          'name': 'Synced Client',
          'lat': 40.71,
          'lng': -74.00,
          'created_at': DateTime.now().toIso8601String(),
          'is_synced': 1,
        },
        {
          'id': 'unsynced-1',
          'name': 'Unsynced Client',
          'lat': 40.72,
          'lng': -74.01,
          'created_at': DateTime.now().toIso8601String(),
          'is_synced': 0,
        },
      ]);
      provider.notifyListeners();
      
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            home: WaitingRoomScreen(),
          ),
        ),
      );

      // Check for sync status icons
      expect(find.byIcon(Icons.cloud_done), findsOneWidget); // Synced
      expect(find.byIcon(Icons.cloud_off), findsOneWidget); // Unsynced
    });

    testWidgets('Basic UI elements are present', (WidgetTester tester) async {
      final provider = MockQueueProvider();
      
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            home: WaitingRoomScreen(),
          ),
        ),
      );

      // Check for basic UI elements
      expect(find.text('Waiting Room'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
    });
  });
}
