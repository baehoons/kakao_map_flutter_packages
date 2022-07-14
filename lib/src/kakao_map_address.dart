import 'package:kakao_map_editing/kakao_map_editing.dart';

class KakaoMapAddress {
  double latitude;
  double longitude;

  KakaoMapAddress(this.latitude, this.longitude);
  
  @override
  String toString() {
    return "lat : $latitude, lng: $longitude";
  }

  @override
  bool operator ==(o) =>
      o is KakaoMapAddress && o.latitude == latitude && o.longitude == longitude;

  @override
  int get hashCode => super.hashCode;

}

typedef void KakaoMapCreatedCallback(KakaoMapController controller);

typedef void KakaoMapPageFinishedCallback();

typedef void KakaoMapMarkerTouched(KakaoLatLng markerLocation, int markerIndex);
