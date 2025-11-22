import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'local_queue_service.dart';
import 'geolocation_service.dart';
import 'connectivity_service.dart';
import 'location_utils.dart';

class QueueProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final LocalQueueService _localDb;
  final GeolocationService _geoService;
  final ConnectivityService? _connectivityService;
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _rooms = [];
  bool _isSyncing = false;
  RealtimeChannel? _subscription;
  String? _currentRoomId;
  bool _wasOffline = false;
  
  // Average service time in minutes (configurable)
  static const double averageServiceTime = 5.0;

  List<Map<String, dynamic>> get clients => _clients;
  List<Map<String, dynamic>> get rooms => _rooms;
  bool get isSyncing => _isSyncing;
  String? get currentRoomId => _currentRoomId;

  QueueProvider({
    LocalQueueService? localDb,
    GeolocationService? geoService,
    ConnectivityService? connectivityService,
  })  : _localDb = localDb ?? LocalQueueService(),
        _geoService = geoService ?? GeolocationService(),
        _connectivityService = connectivityService {
    // Listen to connectivity changes
    _connectivityService?.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    if (_connectivityService != null) {
      final isOnline = _connectivityService!.isOnline;
      if (_wasOffline && isOnline) {
        // Just came back online, trigger sync
        unawaited(_syncLocalToRemote().then((error) {
          if (error != null) {
            debugPrint('⚠️ Background sync error: $error');
          }
        }));
      }
      _wasOffline = !isOnline;
    }
  }

  @override
  void dispose() {
    _connectivityService?.removeListener(_onConnectivityChanged);
    _subscription?.unsubscribe();
    super.dispose();
  }
  Future<void> initialize() async {
    await fetchWaitingRooms();
    await _loadQueue();
  }

  Future<void> fetchWaitingRooms() async {
    try {
      final response = await _supabase.from('waiting_rooms').select();
      _rooms = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching waiting rooms: $e');
    }
  }

  Future<String?> _findNearestRoom(double clientLat, double clientLng) async {
    if (_rooms.isEmpty) await fetchWaitingRooms();
    if (_rooms.isEmpty) return null;

    double minDistance = double.infinity;
    String? nearestRoomId;

    for (var room in _rooms) {
      final roomLat = room['latitude'] as double?;
      final roomLng = room['longitude'] as double?;
      if (roomLat == null || roomLng == null) continue;

      final distance = calculateDistance(clientLat, clientLng, roomLat, roomLng);
      if (distance < minDistance) {
        minDistance = distance;
        nearestRoomId = room['id'] as String?;
      }
    }

    return nearestRoomId;
  }

  Future<void> _loadQueue({String? roomId}) async {
    // Load local DB immediately
    _clients = await _localDb.getClients();
    if (roomId != null) {
      _clients = _clients.where((c) => c['waiting_room_id'] == roomId).toList();
    }
    _sortClientsByCreatedAt();
    notifyListeners();

    // Try to fetch from remote if online
    final isOnline = _connectivityService?.isOnline ?? true;
    if (isOnline) {
      try {
        var query = _supabase.from('clients').select();
        if (roomId != null) {
          query = query.eq('waiting_room_id', roomId);
        }
        final remoteClients = await query;
        final remoteList = List<Map<String, dynamic>>.from(remoteClients);
        
        // Update local DB with remote data
        for (var client in remoteList) {
          final clientWithSync = Map<String, dynamic>.from(client)
            ..['is_synced'] = 1
            ..['priority'] = client['priority'] ?? 'normal';
          await _localDb.insertClientLocally(clientWithSync);
        }
        
        // Reload from local DB
        _clients = await _localDb.getClients();
        if (roomId != null) {
          _clients = _clients.where((c) => c['waiting_room_id'] == roomId).toList();
        }
        _sortClientsByCreatedAt();
        notifyListeners();
      } catch (e) {
        debugPrint('Error fetching remote clients: $e');
      }
    }

    // Try syncing local to remote
    unawaited(_syncLocalToRemote().then((error) {
      if (error != null) {
        debugPrint('⚠️ Background sync error: $error');
      }
    }));
    
    // Subscribe to realtime
    if (roomId != null) {
      subscribeToRoom(roomId);
    } else {
      _setupRealtimeSubscription();
    }
  }
  Future<String?> _syncLocalToRemote() async {
    if (_isSyncing) {
      debugPrint('⏸️ Sync already in progress');
      return null;
    }
    
    // Check connectivity before syncing
    final isOnline = _connectivityService?.isOnline ?? true;
    if (!isOnline) {
      debugPrint('⏸️ Skipping sync - offline');
      return 'Offline - will sync when connected';
    }
    
    _isSyncing = true;
    notifyListeners();

    try {
      final unsynced = await _localDb.getUnsyncedClients();
      debugPrint('🔄 Starting sync: ${unsynced.length} unsynced clients');

      if (unsynced.isEmpty) {
        debugPrint('✅ No unsynced clients');
        return null;
      }

      String? lastError;
      for (var client in unsynced) {
        try {
          debugPrint('📤 Preparing to sync client: ${client['id']}');
          debugPrint('📋 Client data: $client');

          // Prepare data for Supabase - only include columns that exist in Supabase
          // Supabase table has: id, name, created_at, waiting_room_id, priority
          // Note: lat and lng are not in Supabase schema, so we exclude them
          final remoteClient = <String, dynamic>{
            'id': client['id'],
            'name': client['name'],
            'created_at': client['created_at'],
            'waiting_room_id': client['waiting_room_id'],
            'priority': client['priority'] ?? 'normal',
          };
          debugPrint('📦 Data to send to Supabase: $remoteClient');

          // Perform upsert
          debugPrint('🚀 Sending to Supabase...');
          final response = await _supabase.from('clients').upsert(
            remoteClient,
            onConflict: 'id',
          );
          debugPrint('✅ Upsert response: $response');

          // Mark as synced locally
          await _localDb.markClientAsSynced(client['id'] as String);
          debugPrint('🎯 Client ${client['id']} fully synced');

        } catch (e, stackTrace) {
          debugPrint('❌ Sync failed for ${client['id']}: $e');
          debugPrint('📚 Stack trace: $stackTrace');
          
          String errorMsg = 'Unknown error';
          if (e is PostgrestException) {
            errorMsg = 'Supabase error: ${e.message}';
            debugPrint('📋 Supabase error details: ${e.message}');
            debugPrint('🔧 Error code: ${e.code}');
            debugPrint('📝 Details: ${e.details}');
            debugPrint('🛠️ Hint: ${e.hint}');
          } else {
            errorMsg = 'Sync error: $e';
          }
          
          lastError = errorMsg;
          
          // If sync fails due to connectivity, break the loop
          if (!(_connectivityService?.isOnline ?? true)) {
            debugPrint('⏸️ Sync interrupted - went offline');
            break;
          }
        }
      }
      
      // Reload clients after sync, filtering by current room if needed
      _clients = await _localDb.getClients();
      if (_currentRoomId != null) {
        _clients = _clients.where((c) => c['waiting_room_id'] == _currentRoomId).toList();
      }
      _sortClientsByCreatedAt();
      
      return lastError; // Return last error if any, null if all succeeded
    } catch (e, stackTrace) {
      debugPrint('💥 General sync error: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      return 'Sync error: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
      debugPrint('🔄 Sync process completed');
    }
  }

  // Sort clients by created_at (FIFO - first in, first out)
  void _sortClientsByCreatedAt() {
    // Convert to mutable list if it's read-only (from sqflite)
    _clients = List<Map<String, dynamic>>.from(_clients);
    _clients.sort((a, b) => (a['created_at'] ?? '').compareTo(b['created_at'] ?? ''));
  }
  
  // Calculate estimated waiting time in minutes for a client
  // Position is the number of clients ahead (0-indexed, so position = index)
  double calculateEstimatedWaitingTime(int position) {
    // Position is already 0-indexed, so we multiply by averageServiceTime
    // If position is 0, estimated time is 0 (first in queue)
    // If position is 1, estimated time is 1 * averageServiceTime (one client ahead)
    return position * averageServiceTime;
  }
  
  // Get client's position in the queue (0-indexed)
  // Returns -1 if client not found
  int getClientPosition(String clientId) {
    return _clients.indexWhere((c) => c['id'] == clientId);
  }
  
  Future<String?> addClient(String name, {String? roomId, String priority = 'normal'}) async {
    try {
      debugPrint('➕ Adding client: $name, roomId: $roomId');
      
      // Get geolocation (non-blocking - continue even if it fails)
      Position? position;
      try {
        position = await _geoService.getCurrentPosition();
      } catch (e) {
        debugPrint('⚠️ Geolocation error (continuing anyway): $e');
      }
      
      final clientLat = position?.latitude ?? 0.0;
      final clientLng = position?.longitude ?? 0.0;
      debugPrint('📍 Client location: $clientLat, $clientLng');

      // Find nearest room if roomId not provided
      String? assignedRoomId = roomId;
      if (assignedRoomId == null) {
        debugPrint('🔍 Finding nearest room...');
        assignedRoomId = await _findNearestRoom(clientLat, clientLng);
      } else {
        // Verify the provided roomId exists
        if (_rooms.isEmpty) await fetchWaitingRooms();
        final roomExists = _rooms.any((r) => r['id'] == assignedRoomId);
        if (!roomExists) {
          debugPrint('❌ Room $assignedRoomId does not exist');
          return 'The selected room does not exist. Please refresh and try again.';
        }
      }

      // Check if room was found before inserting
      if (assignedRoomId == null) {
        debugPrint('❌ No room found for client');
        return 'No room found. Please ensure there are waiting rooms available.';
      }

      debugPrint('✅ Using room: $assignedRoomId');

      final newClient = {
        'id': const Uuid().v4(),
        'name': name,
        'lat': clientLat,
        'lng': clientLng,
        'created_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
        'waiting_room_id': assignedRoomId,
        'priority': priority,
      };

      // Save locally
      try {
        await _localDb.insertClientLocally(newClient);
        debugPrint('💾 Client saved locally');
      } catch (e) {
        debugPrint('❌ Error saving client locally: $e');
        return 'Failed to save client locally: $e';
      }
      
      // ✅ Make sure _clients is mutable before modifying
      _clients = List<Map<String, dynamic>>.from(_clients);

      // Update UI (only if viewing this room or all rooms)
      if (roomId == null || roomId == assignedRoomId) {
        _clients.add(newClient);
        _sortClientsByCreatedAt();
        notifyListeners();
        debugPrint('🔄 UI updated with new client');
      }

      // Try to sync immediately and return any errors
      debugPrint('🔄 Attempting to sync to Supabase...');
      final syncError = await _syncLocalToRemote();
      
      if (syncError != null) {
        debugPrint('⚠️ Sync warning: $syncError');
        // Client is saved locally, but sync failed - return warning
        return 'Client saved locally, but sync failed: $syncError';
      }
      
      debugPrint('✅ Client added and synced successfully');
      return null; // Success
    } catch (e, stackTrace) {
      debugPrint('💥 Error adding client: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      return 'Failed to add client: $e';
    }
  }

  Future<void> deleteClient(String id) async {
    // 1️⃣ Remove from local database
    await _localDb.deleteClientLocally(id);

    // 2️⃣ Update in-memory list
    _clients = List<Map<String, dynamic>>.from(_clients)
      ..removeWhere((client) => client['id'] == id);

    // 3️⃣ Notify UI
    notifyListeners();

    // 4️⃣ Try to delete from remote if online
    final isOnline = _connectivityService?.isOnline ?? true;
    if (isOnline) {
      try {
        await _supabase.from('clients').delete().eq('id', id);
        debugPrint('✅ Client deleted from remote: $id');
      } catch (e) {
        debugPrint('❌ Error deleting client from remote: $e');
        // If remote delete fails, we'll try to sync later
      }
    }
  }


  void subscribeToRoom(String roomId) {
    _currentRoomId = roomId;
    // Cancel old subscription
    _subscription?.unsubscribe();

    try {
      final channel = _supabase.channel('public:clients:$roomId');

      channel.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'clients',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'waiting_room_id',
          value: roomId,
        ),
        callback: (payload) async {
          debugPrint('📡 New client inserted in room $roomId: ${payload.newRecord}');
          // Save to local DB
          final clientData = Map<String, dynamic>.from(payload.newRecord)
            ..['is_synced'] = 1
            ..['priority'] = payload.newRecord['priority'] ?? 'normal';
          await _localDb.insertClientLocally(clientData);
          _clients = await _localDb.getClients();
          _clients = _clients.where((c) => c['waiting_room_id'] == roomId).toList();
          _sortClientsByCreatedAt();
          notifyListeners();
        },
      );

      channel.onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'clients',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'waiting_room_id',
          value: roomId,
        ),
        callback: (payload) async {
          debugPrint('📡 Client deleted from room $roomId: ${payload.oldRecord}');
          // Remove from local DB
          final clientId = payload.oldRecord['id'] as String?;
          if (clientId != null) {
            await _localDb.deleteClientLocally(clientId);
          }
          _clients = await _localDb.getClients();
          _clients = _clients.where((c) => c['waiting_room_id'] == roomId).toList();
          _sortClientsByCreatedAt();
          notifyListeners();
        },
      );

      channel.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'clients',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'waiting_room_id',
          value: roomId,
        ),
        callback: (payload) async {
          debugPrint('📡 Client updated in room $roomId: ${payload.newRecord}');
          // Update local DB
          final clientData = Map<String, dynamic>.from(payload.newRecord)
            ..['is_synced'] = 1
            ..['priority'] = payload.newRecord['priority'] ?? 'normal';
          await _localDb.insertClientLocally(clientData);
          _clients = await _localDb.getClients();
          _clients = _clients.where((c) => c['waiting_room_id'] == roomId).toList();
          _sortClientsByCreatedAt();
          notifyListeners();
        },
      );

      _subscription = channel;
      channel.subscribe();
    } catch (e) {
      debugPrint('Realtime subscription error: $e');
    }
  }

  void _setupRealtimeSubscription() {
    try {
      final channel = _supabase.channel('public:clients');

      channel.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'clients',
        callback: (payload) async {
          debugPrint('📡 New client inserted: ${payload.newRecord}');
          // Save to local DB
          final clientData = Map<String, dynamic>.from(payload.newRecord)
            ..['is_synced'] = 1
            ..['priority'] = payload.newRecord['priority'] ?? 'normal';
          await _localDb.insertClientLocally(clientData);
          _clients = await _localDb.getClients();
          if (_currentRoomId != null) {
            _clients = _clients.where((c) => c['waiting_room_id'] == _currentRoomId).toList();
          }
          _sortClientsByCreatedAt();
          notifyListeners();
        },
      );

      channel.onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'clients',
        callback: (payload) async {
          debugPrint('📡 Client deleted: ${payload.oldRecord}');
          // Remove from local DB
          final clientId = payload.oldRecord['id'] as String?;
          if (clientId != null) {
            await _localDb.deleteClientLocally(clientId);
          }
          _clients = await _localDb.getClients();
          if (_currentRoomId != null) {
            _clients = _clients.where((c) => c['waiting_room_id'] == _currentRoomId).toList();
          }
          _sortClientsByCreatedAt();
          notifyListeners();
        },
      );

      channel.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'clients',
        callback: (payload) async {
          debugPrint('📡 Client updated: ${payload.newRecord}');
          // Update local DB
          final clientData = Map<String, dynamic>.from(payload.newRecord)
            ..['is_synced'] = 1
            ..['priority'] = payload.newRecord['priority'] ?? 'normal';
          await _localDb.insertClientLocally(clientData);
          _clients = await _localDb.getClients();
          if (_currentRoomId != null) {
            _clients = _clients.where((c) => c['waiting_room_id'] == _currentRoomId).toList();
          }
          _sortClientsByCreatedAt();
          notifyListeners();
        },
      );

      _subscription = channel;
      channel.subscribe();
    } catch (e) {
      debugPrint('Realtime subscription error: $e');
    }
  }

  Future<void> loadRoomClients(String roomId) async {
    _currentRoomId = roomId;
    await _loadQueue(roomId: roomId);
  }
  
  // Get sorted clients (already sorted by priority)
  List<Map<String, dynamic>> get sortedClients => _clients;
}