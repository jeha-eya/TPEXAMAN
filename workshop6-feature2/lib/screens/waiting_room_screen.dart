import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:waiting_room_app_5/queue_provider.dart';
import 'package:waiting_room_app_5/connectivity_service.dart';

class WaitingRoomScreen extends StatefulWidget {
  final String? roomId;
  final String? roomName;

  const WaitingRoomScreen({Key? key, this.roomId, this.roomName}) : super(key: key);

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load room clients when screen is initialized
    if (widget.roomId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<QueueProvider>(context, listen: false).loadRoomClients(widget.roomId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<QueueProvider>(context);
    final connectivityService = context.watch<ConnectivityService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.roomName ?? 'Waiting Room'),
        actions: [
          if (provider.isSyncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: Text('Syncing...')),
            )
        ],
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
          // Add client form
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = _nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a name')),
                      );
                      return;
                    }
                    
                    // Show loading indicator
                    final result = await provider.addClient(name, roomId: widget.roomId);
                    
                    if (result != null) {
                      // Show error message
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    } else {
                      // Success - clear the field
                      _nameController.clear();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Client added successfully'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Add'),
                )
              ],
            ),
          ),
          // Clients list
          Expanded(
            child: ListView.builder(
              itemCount: provider.clients.length,
              itemBuilder: (context, index) {
                final c = provider.clients[index];
                final lat = c['lat'];
                final lng = c['lng'];
                final clientId = c['id'] as String;
                final position = provider.getClientPosition(clientId);
                final estimatedMinutes = position >= 0 
                    ? provider.calculateEstimatedWaitingTime(position)
                    : 0.0;

                return ListTile(
                  title: Text(c['name'] ?? 'Unknown'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lat == null
                            ? '📍 Location not captured'
                            : '📍 ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 16, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            'Estimated: ${estimatedMinutes.toStringAsFixed(0)} minutes',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 🌩️ Sync status icon
                      Icon(
                        c['is_synced'] == 1 ? Icons.cloud_done : Icons.cloud_off,
                        color: c['is_synced'] == 1 ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      // 🗑️ Delete icon
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          // Confirm before deleting
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete client?'),
                              content: Text('Are you sure you want to remove "${c['name']}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await provider.deleteClient(c['id']);
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
