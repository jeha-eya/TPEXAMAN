# Waiting Room App 6 - Offline-First Queue App with Geolocation

A Flutter application that demonstrates offline-first architecture with supabase persistence, geolocation services, and Supabase synchronization.

## Features

### ✅ Offline-First Architecture
- **Local SQLite Database**: All data is stored locally using `sqflite`
- **Offline Functionality**: App works completely offline
- **Automatic Sync**: Data syncs with Supabase when connection is available
- **Conflict Resolution**: Handles sync conflicts gracefully

### ✅ Geolocation Services
- **Location Capture**: Automatically captures user location when joining queue
- **Permission Handling**: Proper Android/iOS permission configuration
- **Fallback Support**: Gracefully handles location permission denial
- **Location Display**: Shows coordinates in UI with 4-decimal precision

### ✅ Real-time Synchronization
- **Supabase Integration**: Real-time updates across devices
- **Sync Status Indicators**: Visual indicators for sync status
- **Background Sync**: Non-blocking sync operations
- **Error Handling**: Robust error handling for network issues

### ✅ Clean Architecture
- **Service Layer**: Separate services for database, geolocation, and queue management
- **Provider Pattern**: State management using Provider
- **Dependency Injection**: Testable architecture with dependency injection
- **TDD Approach**: Comprehensive test coverage

## Architecture

```
lib/
├── main.dart                    # App entry point
├── queue_provider.dart         # Main state management
├── local_queue_service.dart    # SQLite database operations
├── geolocation_service.dart        # Location services
└── screens/
    └── waiting_room_screen.dart # Main UI
```

## Dependencies

```yaml
dependencies:
  flutter: sdk: flutter
  provider: ^6.0.0
  supabase_flutter: ^2.0.0
  sqflite: ^2.3.0
  path_provider: ^2.1.1
  path: ^1.8.3
  geolocator: ^11.0.0
  uuid: ^4.0.0

dev_dependencies:
  flutter_test: sdk: flutter
  mockito: ^5.4.0
  build_runner: ^2.4.0
  sqflite_common_ffi: ^2.3.0+2
```

## Database Schema

```sql
CREATE TABLE local_clients (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  lat REAL,
  lng REAL,
  created_at TEXT NOT NULL,
  is_synced INTEGER NOT NULL DEFAULT 0
);
```

## Key Components

### LocalQueueService
- **Purpose**: Manages local SQLite database operations
- **Features**: 
  - Insert/update/delete clients
  - Track sync status
  - Query unsynced records
  - In-memory testing support

### GeolocationService
- **Purpose**: Handles device location services
- **Features**:
  - Permission management
  - Location accuracy control
  - Error handling
  - Timeout protection

### QueueProvider
- **Purpose**: Main application state management
- **Features**:
  - Offline-first data flow
  - Background synchronization
  - Real-time updates
  - Error recovery

## Testing

### Unit Tests
```bash
flutter test test/local_queue_service_test.dart
```

### Widget Tests
```bash
flutter test test/widget_test.dart
```

### Integration Tests
```bash
flutter test test/queue_provider_geolocation_test.dart
```

## Permissions

### Android (android/app/src/main/AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### iOS (ios/Runner/Info.plist)
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app uses your location to tag where you joined the waiting room.</string>
```

## Usage

### Adding a Client
1. Enter client name in the text field
2. Tap "Add" button
3. App captures current location automatically
4. Client is saved locally immediately
5. Sync happens in background

### Offline Mode
1. Disable internet connection
2. Add clients - they appear instantly
3. Re-enable internet
4. Clients automatically sync to Supabase

### Sync Status
- 🌩️ **Cloud Done**: Successfully synced
- 🌩️ **Cloud Off**: Pending sync

## Demo Scenarios

### Scenario 1: Online Operation
1. Add client online → appears in Supabase immediately
2. Real-time updates visible on other devices

### Scenario 2: Offline Operation
1. Disable Wi-Fi/data
2. Add 2+ clients → appear in UI instantly
3. Re-enable internet → unsynced clients auto-upload

### Scenario 3: Location Services
1. Grant location permission → coordinates captured
2. Deny permission → "Location not captured" displayed

## Troubleshooting

| Issue | Solution |
|-------|----------|
| App crashes on launch | Check Android/iOS permissions; restart app |
| Offline clients not syncing | Check `_syncLocalToRemote()` error logs |
| "No such table" in tests | Confirm `databaseFactory = databaseFactoryFfi` |
| Location always null | Ensure location services are ON |

## Development

### Running Tests
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/local_queue_service_test.dart

# Run with coverage
flutter test --coverage
```

### Building
```bash
# Debug build
flutter build apk --debug

# Release build
flutter build apk --release
```

## Git Workflow

### Feature Branches
```bash
# Offline sync feature
git checkout -b feature/offline-sync
# Complete implementation → commit → push → PR

# Geolocation feature  
git checkout -b feature/geolocation
# Complete implementation → commit → push → PR
```

## Performance Considerations

- **Database Operations**: All local operations are non-blocking
- **Sync Operations**: Background sync doesn't block UI
- **Memory Usage**: In-memory database for tests only
- **Location Accuracy**: Low accuracy for better performance

## Security

- **Local Storage**: SQLite database is device-specific
- **Network Security**: HTTPS for all Supabase communications
- **Data Privacy**: Location data stored locally first
- **Permission Handling**: Graceful degradation when permissions denied

## Future Enhancements

- [ ] Push notifications for queue updates
- [ ] Offline conflict resolution
- [ ] Data encryption for sensitive information
- [ ] Analytics and monitoring
- [ ] Multi-language support
- [ ] Dark mode support

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
