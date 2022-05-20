import 'package:kakao_map_editing/kakao_map_editing.dart';

class KakaoMapState {
  static final KakaoMapState _kakaoMapState = KakaoMapState._init();
  KakaoLatLng? _centerPoint;
  int? _level;

  factory KakaoMapState() {
    return _kakaoMapState;
  }

  KakaoMapState._init() {
    // initial state, run this code
  }

  KakaoLatLng? getCenter() {
    return _centerPoint;
  }

  setCenter(KakaoLatLng n) {
    _centerPoint = n;
  }

  int? getLevel() {
    return _level;
  }

  setLevel(int n) {
    _level = n;
  }
}
