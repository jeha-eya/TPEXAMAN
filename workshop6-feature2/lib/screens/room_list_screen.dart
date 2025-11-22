import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../queue_provider.dart';
import '../connectivity_service.dart';
import 'waiting_room_screen.dart';

class RoomListScreen extends StatefulWidget {
  const RoomListScreen({Key? key}) : super(key: key);

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure rooms are fetched when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<QueueProvider>(context, listen: false).fetchWaitingRooms();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<QueueProvider>(context);
    final connectivityService = context.watch<ConnectivityService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Waiting Room'),
      ),
      body: Column(
        children: [
          // Connectivity banner
          if (!connectivityService.isOnline)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red[800],
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Offline Mode - Data will sync when connected.',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          // Rooms list
          Expanded(
            child: provider.rooms.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : ListView.builder(
                    itemCount: provider.rooms.length,
                    itemBuilder: (context, index) {
                      final room = provider.rooms[index];
                      final roomName = room['name'] as String? ?? 'Unknown Room';
                      final lat = room['latitude'] as double?;
                      final lng = room['longitude'] as double?;

                      return ListTile(
                        leading: const Icon(Icons.room, size: 40),
                        title: Text(
                          roomName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        subtitle: lat != null && lng != null
                            ? Text('📍 ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}')
                            : const Text('Location not available'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          final roomId = room['id'] as String?;
                          if (roomId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WaitingRoomScreen(roomId: roomId, roomName: roomName),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

