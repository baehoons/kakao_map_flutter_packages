import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kakao_map_editing/kakao_map_editing.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  MyApp({Key? key}) : super(key: key);

  late final KakaoMapController _mapController;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
          body: SafeArea(
            child: Column(children: [
              Expanded(
                  child: KakaoMap(
                    initLocation: KakaoLatLng(33.450701, 126.570667),
                    kakaoApiKey: "api key",
                    clustererServiceEnable: true,
                    geocodingServiceEnable: true,
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    onMapLoaded: () {
                      Get.rawSnackbar(
                          message: "맵 로드 완료",
                          margin: const EdgeInsets.all(8),
                          borderRadius: 12.0,
                          snackPosition: SnackPosition.TOP);
                      _mapController.setNowLocation();
                    },
                    onMarkerTouched: (markerLocation, markerIndex) {
                      Get.rawSnackbar(
                          message: "$markerLocation, $markerIndex",
                          margin: const EdgeInsets.all(8),
                          borderRadius: 12.0,
                          snackPosition: SnackPosition.TOP);
                    },
                  )),
              _customButton("현재 위치로 이동하고 커스텀 오버레이 추가하기", onTap: () async {
                final location = await _mapController.setNowLocation();
                if (location != null) {
                  _mapController.deleteAllCustomOverlays();
                  _mapController.addCustomOverlay(location);
                }
              }),
              _customButton("지도 위치에 마커 추가하기", onTap: () async {
                _mapController.addMarker(await _mapController.getCenter());
              }, color: Colors.green),
              _customButton("모든 마커 삭제하기", onTap: () {
                _mapController.deleteAllMarkers();
              }, color: Colors.red),
              _customButton("모든 마커 클러스터링하기", onTap: () {
                if (!_mapController.nowClusteringEnabled())
                  _mapController.startClustering(minLevel: 5);
                else
                  _mapController.updateClustering();
              }, color: Colors.black87),
              _customButton("리스트 가져오기 및 마커 ", onTap: () async {
                String ks = '대한민국&nbsp서울&nbsp중구&nbsp동호로 249';

                _mapController.searchMarker("가천대", ks);
              }, color: Colors.green),
            ]),
          )),
    );
  }

  Widget _customButton(String text,
      {Function()? onTap, Color color = Colors.lightBlue}) =>
      SizedBox(
          width: double.infinity,
          child: Material(
            color: color,
            child: InkWell(
                onTap: onTap,
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
                    child: Text(text,
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center))),
          ));
}
