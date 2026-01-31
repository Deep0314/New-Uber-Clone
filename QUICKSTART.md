# Quick Start Guide - RideShare App

## Prerequisites Check

Before running the app, ensure you have:
- ✅ Flutter SDK installed (run `flutter --version`)
- ✅ Android Studio / Xcode (for mobile development)
- ✅ Chrome browser (for web development)

## Step 1: Install Dependencies

```bash
cd "c:\Users\kambl\Desktop\Deep Projects\New-Uber-Clone"
flutter pub get
```

## Step 2: Run the App

### For Android/iOS (Emulator or Device)
```bash
flutter run
```

### For Web
```bash
flutter run -d chrome
```

### For specific device
```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device-id>
```

## Step 3: Test the App

### Testing as User/Customer
1. Open the app
2. Enter phone number: **9876543211** (any number ending with 1)
3. Enter OTP: **123456** (any 6 digits)
4. You'll see the **User Home Screen** with map
5. Click "Where would you like to go?"
6. Search for pickup location (try "New Delhi" or "Mumbai")
7. Search for destination
8. Select vehicle type
9. View fare estimate
10. Book ride
11. Watch the ride status change

### Testing as Driver/Captain
1. Restart app or logout
2. Enter phone number: **9876543212** (any number ending with 2)
3. Enter OTP: **123456**
4. You'll see the **Driver Home Screen**
5. Toggle the switch to go **Online**
6. View your profile and statistics
7. When a ride is simulated, accept it
8. Manage ride status:
   - Click "Arrived at Pickup"
   - Click "Start Ride"
   - Click "Complete Ride"

### Testing as Admin
1. Restart app or logout
2. Enter phone number: **9876543213** (any number ending with 3)
3. Enter OTP: **123456**
4. You'll see the **Admin Dashboard**
5. View overview statistics
6. Navigate to Rides tab to see all rides
7. Navigate to Drivers tab to see all drivers
8. Refresh to update data

## Common Commands

### Clean build
```bash
flutter clean
flutter pub get
```

### Check for issues
```bash
flutter doctor -v
flutter analyze
```

### Build for production
```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

## Troubleshooting

### 1. Dependencies not installing
```bash
flutter clean
flutter pub cache repair
flutter pub get
```

### 2. Build errors
```bash
flutter clean
flutter pub get
flutter pub upgrade
```

### 3. Map not showing
- Check internet connection
- Ensure location permissions are granted
- Try restarting the app

### 4. Location not working
- Grant location permissions when prompted
- Enable location services on your device
- For Android: Settings → Location → On
- For iOS: Settings → Privacy → Location Services → On

### 5. Hot reload not working
```bash
# Press 'r' in terminal for hot reload
# Press 'R' for hot restart
# Press 'q' to quit
```

## App Features to Explore

### User Features
- ✅ Live map with current location
- ✅ Search pickup and destination
- ✅ View nearby drivers
- ✅ Select vehicle type (Go, Sedan, XL, Premium)
- ✅ Real-time fare estimation
- ✅ Book rides
- ✅ Track ride status
- ✅ Cancel rides
- ✅ View driver details

### Driver Features
- ✅ Go online/offline
- ✅ View earnings and statistics
- ✅ Accept rides
- ✅ Update ride status
- ✅ Navigate to pickup/drop
- ✅ Complete rides

### Admin Features
- ✅ View all statistics
- ✅ Monitor all rides
- ✅ Manage drivers
- ✅ Revenue tracking
- ✅ Success rate analytics

## Important Notes

1. **Mock Data**: All data is simulated. 20 mock drivers are pre-generated.

2. **Authentication**: The auth system is for demonstration. Any phone number with specific endings will work:
   - Ends with 1 → User
   - Ends with 2 → Driver
   - Ends with 3 → Admin

3. **Maps**: Uses OpenStreetMap (free, no API key needed)

4. **Location**: Grant location permission for full functionality

5. **Internet**: App needs internet for map tiles and geocoding

6. **Ride Simulation**: When booking a ride, a driver is auto-assigned after 3 seconds

## File Structure Reference

```
lib/
├── main.dart                    # App entry point
├── auth/                        # Authentication module
├── user/                        # User/Customer module
├── driver/                      # Driver/Captain module
├── admin/                       # Admin module
├── core/                        # Shared services & config
├── domain/                      # Data models
├── data/                        # Repositories
└── shared/                      # Reusable widgets
```

## Next Steps

1. **Explore the code**: Start with `lib/main.dart`
2. **Test all flows**: Try all three user roles
3. **Modify UI**: Check `lib/core/theme/` for styling
4. **Add features**: Follow the clean architecture pattern
5. **Integrate backend**: Replace mock repositories in `lib/data/repositories/`

## Support

If you encounter any issues:
1. Check `flutter doctor` output
2. Ensure all dependencies are installed
3. Try `flutter clean` and rebuild
4. Check the console for error messages

## Performance Tips

- First run might be slow while downloading map tiles
- Subsequent runs will be faster with cached tiles
- Use `flutter run --release` for better performance testing
- Debug mode has performance overhead

---

**Ready to start!** 🚀

Run: `flutter run` and explore the app!
