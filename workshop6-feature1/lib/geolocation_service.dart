import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';

class GeolocationService {
  Future<Position?> getCurrentPosition() async {
    try {
      // 1) Vérifier si le service GPS est activé
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('GPS désactivé - ouverture des paramètres...');
        await Geolocator.openLocationSettings();
        return null;
      }

      // 2) Vérifier permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // 3) Si permission bloquée pour toujours → aucun accès
      if (permission == LocationPermission.deniedForever) {
        debugPrint('Permission bloquée. Ouvre les paramètres.');
        await Geolocator.openAppSettings();
        return null;
      }

      // 4) Utiliser High Accuracy pour obtenir la vraie position
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint('Geolocation error: $e');
      return null;
    }
  }
}
