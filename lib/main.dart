import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'queue_provider.dart';
import 'connectivity_service.dart';
import 'screens/room_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://pzoldhpqfxgfmkxqjagk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB6b2xkaHBxZnhnZm1reHFqYWdrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTkxNzA5MzQsImV4cCI6MjA3NDc0NjkzNH0.dcpr2zEwhJjI4N0h5MEz1fPPURTYJrOMKl8jk-VoS70',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ChangeNotifierProxyProvider<ConnectivityService, QueueProvider>(
          create: (context) {
            final connectivityService = context.read<ConnectivityService>();
            return QueueProvider(
              connectivityService: connectivityService,
            )..initialize();
          },
          update: (context, connectivityService, previous) {
            return previous ?? QueueProvider(
              connectivityService: connectivityService,
            )..initialize();
          },
        ),
      ],
      child: MaterialApp(
        title: 'Waiting Room',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const RoomListScreen(),
      ),
    );
  }
}