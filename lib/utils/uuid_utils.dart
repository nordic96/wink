import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class UuidUtils {
  static String extract16BitUuid(Uuid uuid) {
    return uuid.toString().toLowerCase().substring(4, 8);
  }

  static bool isLongShortUuidEqual(Uuid uuidLong, Uuid uuidShort) {
    String shortenedUuidLong = extract16BitUuid(uuidLong);
    return shortenedUuidLong == uuidShort.toString().toLowerCase();
  }
}
