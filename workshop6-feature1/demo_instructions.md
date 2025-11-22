# Demo Instructions - Offline-First Queue App

## Pre-Demo Setup

1. **Start the app**: `flutter run`
2. **Ensure location services are enabled** on your device/emulator
3. **Grant location permissions** when prompted

## Demo Scenarios

### Scenario 1: Online Operation (5 minutes)

**Objective**: Demonstrate real-time synchronization

**Steps**:
1. **Add a client online**:
   - Enter name: "Alice"
   - Tap "Add"
   - ✅ Client appears immediately
   - ✅ Location coordinates displayed
   - ✅ Cloud sync icon shows "synced"

2. **Open app on another device/browser**:
   - Navigate to Supabase dashboard
   - Check `clients` table
   - ✅ Alice appears in database
   - ✅ Location data is captured

3. **Add another client**:
   - Enter name: "Bob"
   - Tap "Add"
   - ✅ Both clients visible
   - ✅ Real-time sync working

### Scenario 2: Offline Operation (5 minutes)

**Objective**: Demonstrate offline-first functionality

**Steps**:
1. **Disable internet connection**:
   - Turn off Wi-Fi/data on device
   - Or use airplane mode

2. **Add clients offline**:
   - Enter name: "Charlie"
   - Tap "Add"
   - ✅ Client appears instantly (local storage)
   - ✅ Cloud icon shows "offline" status
   - ✅ Location still captured

3. **Add another offline client**:
   - Enter name: "Diana"
   - Tap "Add"
   - ✅ Both offline clients visible
   - ✅ App works completely offline

4. **Re-enable internet**:
   - Turn on Wi-Fi/data
   - ✅ Automatic sync begins
   - ✅ Cloud icons change to "synced"
   - ✅ Check Supabase - all clients now visible

### Scenario 3: Location Services (3 minutes)

**Objective**: Demonstrate geolocation handling

**Steps**:
1. **With location permission**:
   - Add client: "Eve"
   - ✅ Coordinates displayed (e.g., "📍 40.7128, -74.0060")
   - ✅ 4-decimal precision

2. **Deny location permission**:
   - Go to device settings
   - Deny location permission for app
   - Add client: "Frank"
   - ✅ Shows "📍 Location not captured"
   - ✅ App continues working

3. **Re-grant permission**:
   - Re-enable location permission
   - Add client: "Grace"
   - ✅ Location captured again

### Scenario 4: Error Handling (2 minutes)

**Objective**: Demonstrate robust error handling

**Steps**:
1. **Network interruption during sync**:
   - Add client online
   - Disconnect internet mid-sync
   - ✅ App continues working
   - ✅ Client remains in local storage
   - ✅ Sync retries when connection restored

2. **Database operations**:
   - Add multiple clients rapidly
   - ✅ No blocking or freezing
   - ✅ All operations complete successfully

## Key Features to Highlight

### 🏗️ **Offline-First Architecture**
- App works without internet
- Data stored locally first
- Automatic sync when online

### 📍 **Geolocation Integration**
- Automatic location capture
- Graceful permission handling
- Visual location display

### 🔄 **Real-time Synchronization**
- Instant local updates
- Background sync
- Visual sync status indicators

### 🧪 **Test-Driven Development**
- Comprehensive test coverage
- Unit tests for all services
- Widget tests for UI components

### 🏛️ **Clean Architecture**
- Separation of concerns
- Dependency injection
- Service layer pattern

## Troubleshooting

### If location not working:
- Check device location services are ON
- Verify app permissions in settings
- Restart app after permission changes

### If sync not working:
- Check internet connection
- Verify Supabase credentials
- Check console for error messages

### If app crashes:
- Check all permissions are granted
- Verify dependencies are installed
- Run `flutter clean && flutter pub get`

## Success Criteria

✅ **Offline Functionality**: App works without internet  
✅ **Location Capture**: Coordinates displayed or "not captured"  
✅ **Real-time Sync**: Changes appear on other devices  
✅ **Error Handling**: Graceful degradation when services fail  
✅ **Performance**: Smooth, non-blocking operations  
✅ **User Experience**: Intuitive interface with clear status indicators  

## Technical Highlights

- **SQLite**: Local database with offline support
- **Supabase**: Real-time backend synchronization
- **Geolocator**: Device location services
- **Provider**: State management
- **TDD**: Test-driven development approach
- **Clean Architecture**: Maintainable, testable code structure

