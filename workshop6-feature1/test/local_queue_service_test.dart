import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:waiting_room_app_5/local_queue_service.dart';

void main() {
  setUpAll(() {
    // Use in-memory database for tests
    databaseFactory = databaseFactoryFfi;
  });

  group('LocalQueueService', () {
    late LocalQueueService service;

    setUp(() {
      service = LocalQueueService(inMemory: true);
    });

    tearDown(() async {
      await service.close();
    });

    test('insertClientLocally adds a record to the database', () async {
      await service.insertClientLocally({
        'id': 'test-123',
        'name': 'Alice',
        'lat': 40.71,
        'lng': -74.00,
        'created_at': '2024-01-01T00:00:00Z',
        'is_synced': 0,
      });

      final clients = await service.getUnsyncedClients();
      expect(clients.length, 1);
      expect(clients[0]['name'], 'Alice');
      expect(clients[0]['lat'], 40.71);
      expect(clients[0]['lng'], -74.00);
    });

    test('getClients returns all clients ordered by created_at', () async {
      // Insert multiple clients with different timestamps
      await service.insertClientLocally({
        'id': 'test-1',
        'name': 'Alice',
        'lat': 40.71,
        'lng': -74.00,
        'created_at': '2024-01-01T10:00:00Z',
        'is_synced': 0,
      });

      await service.insertClientLocally({
        'id': 'test-2',
        'name': 'Bob',
        'lat': 40.72,
        'lng': -74.01,
        'created_at': '2024-01-01T09:00:00Z',
        'is_synced': 0,
      });

      final clients = await service.getClients();
      expect(clients.length, 2);
      expect(clients[0]['name'], 'Bob'); // Earlier timestamp
      expect(clients[1]['name'], 'Alice'); // Later timestamp
    });

    test('getUnsyncedClients returns only unsynced clients', () async {
      // Insert synced and unsynced clients
      await service.insertClientLocally({
        'id': 'synced-1',
        'name': 'Synced Client',
        'lat': 40.71,
        'lng': -74.00,
        'created_at': '2024-01-01T00:00:00Z',
        'is_synced': 1,
      });

      await service.insertClientLocally({
        'id': 'unsynced-1',
        'name': 'Unsynced Client',
        'lat': 40.72,
        'lng': -74.01,
        'created_at': '2024-01-01T00:00:00Z',
        'is_synced': 0,
      });

      final unsyncedClients = await service.getUnsyncedClients();
      expect(unsyncedClients.length, 1);
      expect(unsyncedClients[0]['name'], 'Unsynced Client');
    });

    test('markClientAsSynced updates client sync status', () async {
      await service.insertClientLocally({
        'id': 'test-123',
        'name': 'Alice',
        'lat': 40.71,
        'lng': -74.00,
        'created_at': '2024-01-01T00:00:00Z',
        'is_synced': 0,
      });

      // Initially unsynced
      var unsyncedClients = await service.getUnsyncedClients();
      expect(unsyncedClients.length, 1);

      // Mark as synced
      await service.markClientAsSynced('test-123');

      // Should now be synced
      unsyncedClients = await service.getUnsyncedClients();
      expect(unsyncedClients.length, 0);
    });

    test('deleteClientLocally removes client from database', () async {
      await service.insertClientLocally({
        'id': 'test-123',
        'name': 'Alice',
        'lat': 40.71,
        'lng': -74.00,
        'created_at': '2024-01-01T00:00:00Z',
        'is_synced': 0,
      });

      // Verify client exists
      var clients = await service.getClients();
      expect(clients.length, 1);

      // Delete client
      await service.deleteClientLocally('test-123');

      // Verify client is gone
      clients = await service.getClients();
      expect(clients.length, 0);
    });

    test('clearSyncedClients removes only synced clients', () async {
      // Insert both synced and unsynced clients
      await service.insertClientLocally({
        'id': 'synced-1',
        'name': 'Synced Client',
        'lat': 40.71,
        'lng': -74.00,
        'created_at': '2024-01-01T00:00:00Z',
        'is_synced': 1,
      });

      await service.insertClientLocally({
        'id': 'unsynced-1',
        'name': 'Unsynced Client',
        'lat': 40.72,
        'lng': -74.01,
        'created_at': '2024-01-01T00:00:00Z',
        'is_synced': 0,
      });

      // Clear synced clients
      await service.clearSyncedClients();

      // Only unsynced client should remain
      final clients = await service.getClients();
      expect(clients.length, 1);
      expect(clients[0]['name'], 'Unsynced Client');
    });

    test('handles null location values gracefully', () async {
      await service.insertClientLocally({
        'id': 'test-123',
        'name': 'Alice',
        'lat': null,
        'lng': null,
        'created_at': '2024-01-01T00:00:00Z',
        'is_synced': 0,
      });

      final clients = await service.getClients();
      expect(clients.length, 1);
      expect(clients[0]['lat'], isNull);
      expect(clients[0]['lng'], isNull);
    });
  });
}
