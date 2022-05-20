import 'package:kakao_map_editting/kakao_map_editting.dart';
import 'package:location/location.dart';

class KakaoMapUtil {
  static Future<KakaoLatLng?> determinePosition() async {
    Location location = new Location();

    bool _serviceEnabled;
    PermissionStatus _permissionGranted;
    LocationData _locationData;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return null; // todo : exception processing
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return null; // todo : exception processing
      }
    }

    _locationData = await location.getLocation();

    return KakaoLatLng(_locationData.latitude ?? 37.56633045338814,
        _locationData.longitude ?? 126.97703388516338);
  }

  static String mapListToJson(List<Map<String, String>> mapList) {
    String resultStr = "[";

    mapList.forEach((m) {
      resultStr += "{";
      m.forEach((key, value) {
        resultStr += "$key: '$value', ";
      });
      resultStr += "},";
    });

    return resultStr + "]";
  }

  static String listToJsString(List<String> list) {
    String resultStr = "[";
    list.forEach((e) {
      resultStr += "'$e', ";
    });
    return resultStr + "]";
  }

  static RegExp _parseLocationRegExp = new RegExp(r'[\(\),]');

  static KakaoLatLng parseKakaoLatLng(String m) {
    final List<String> latLngStr =
    m.replaceAll(_parseLocationRegExp, '').split(' ');
    return KakaoLatLng(double.parse(latLngStr[0]), double.parse(latLngStr[1]));
  }
}
