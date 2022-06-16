import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:kakao_map_editing/kakao_map_editing.dart';
import 'package:kakao_map_editing/src/kakao_map_state.dart';
import 'package:kakao_map_editing/src/kakao_map_util.dart';
import 'package:webview_flutter/webview_flutter.dart';

class KakaoMap extends StatelessWidget {
  // widget size
  final double width;
  final double height;

  // initial location
  final KakaoLatLng initLocation;

  // zoom level
  // default is 3
  final int level;

  // markers clusterer service
  // default is false
  final bool clustererServiceEnable;

  final bool geocodingServiceEnable;

  // kakao dev javascript key
  final String kakaoApiKey;

  // run when map created. at this time, you can get kakaoMapController
  final KakaoMapCreatedCallback? onMapCreated;

  // run when map finished load
  final KakaoMapPageFinishedCallback? onMapLoaded;

  // run when marker touched
  final KakaoMapMarkerTouched? onMarkerTouched;

  KakaoMap(
      {this.width = double.infinity,
        this.height = 500,
        required this.initLocation,
        this.level = 3,
        required this.kakaoApiKey,
        this.clustererServiceEnable = true,
        this.onMapCreated,
        this.onMapLoaded,
        this.onMarkerTouched,
        this.geocodingServiceEnable = true});

  // map controller
  late final KakaoMapController _kakaoMapController;

  final KakaoMapState _state = KakaoMapState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: width,
        height: height,
        child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) =>
                WebView(
                  initialUrl:
                  getMapPage(constraints.maxWidth, constraints.maxHeight),
                  javascriptMode: JavascriptMode.unrestricted,
                  onWebViewCreated: (WebViewController wc) {
                    _kakaoMapController = KakaoMapController(wc);
                    if (onMapCreated != null)
                      onMapCreated!(_kakaoMapController);
                    print("[kakaoMap] onMapCreated!");
                  },
                  javascriptChannels: Set.from([
                    JavascriptChannel(
                        name: 'onMapFinished',
                        onMessageReceived: (_) => _onMapLoadFinished()),
                    JavascriptChannel(
                        name: 'sendCenterPoint',
                        onMessageReceived: (m) {
                          _state.setCenter(
                              KakaoMapUtil.parseKakaoLatLng(m.message));
                        }),
                    JavascriptChannel(
                        name: 'sendLevel',
                        onMessageReceived: (m) {
                          _state.setLevel(int.parse(m.message));
                        }),
                    JavascriptChannel(
                        name: 'markerTouch',
                        onMessageReceived: (m) {
                          if (onMarkerTouched != null) {
                            final List<String> markerInfo =
                            m.message.split('_');
                            onMarkerTouched!(
                                KakaoMapUtil.parseKakaoLatLng(markerInfo[0]),
                                int.parse(markerInfo[1]));
                                getMapPage(25.0, 17.0);
                          }
                        }),
                  ]),
                )));
  }

  String getMapPage(double width, double height) {
    return Uri.dataFromString('''
<html>
  <head>
    <meta name='viewport' content='width=device-width, initial-scale=1.0, user-scalable=yes'/>
  </head>
  <body style="margin:0; padding:0;">
    <script type="text/javascript" src='https://dapi.kakao.com/v2/maps/sdk.js?autoload=false&appkey=$kakaoApiKey${clustererServiceEnable ? '&libraries=clusterer,services,drawing' : ''}'></script>
    <div id='kakao_map_container' style="width:100%; height:100%; min-width:${width}px; min-height:${height}px;" />
    <script type="text/javascript">
      const container = document.querySelector('#kakao_map_container');
      let map;
      let bounds;
      const customOverlays = [];
      const markers = [];
      
      kakao.maps.load(function() {
        const options = {
          center: new kakao.maps.LatLng(${initLocation.latitude}, ${initLocation.longitude}),
          level: $level
        };
        map = new kakao.maps.Map(container, options);
        onMapFinished.postMessage("");
        bounds = new kakao.maps.LatLngBounds();
      });
    </script>
  </body>
</html>''', mimeType: 'text/html', encoding: Encoding.getByName('utf-8'))
        .toString();
  }

  _onMapLoadFinished() {
    if (onMapLoaded != null) onMapLoaded!();
    print('[kakaoMap] Loading Finished!');
  }
}

class KakaoMapController {
  final WebViewController _controller;
  final KakaoMapState _state = KakaoMapState();
  bool _isUsingBounds = false;
  bool _isUsingClustering = false;
  int _customOverlayCount = 0;
  int _markerCount = 0;

  KakaoMapController(this._controller);

  Future _runScript(String script) async =>
      await _controller.evaluateJavascript(script);


  // reload map
  Future reload() async => await _controller.reload();

  // set now location using gps
  // return now location
  Future<KakaoLatLng?> setNowLocation() async {
    final KakaoLatLng? location = await KakaoMapUtil.determinePosition();
    if (location != null) await setCenter(location);
    return location;
  }

  // set center point
  Future setCenter(KakaoLatLng location) async {
    final String script =
    '''(()=>{ const location = new kakao.maps.LatLng(${location.latitude}, ${location.longitude}); map.setCenter(location); })()''';
    await _runScript(script);
  }

  // return now center point
  Future<KakaoLatLng> getCenter() async {
    final String script = '''(()=>{
  const center = map.getCenter();
  sendCenterPoint.postMessage(center.toString());
})()''';
    await _runScript(script);

    return _state.getCenter()!;
  }

  // set zoom level
  Future setLevel(int level) async {
    final String script = '(()=>map.setLevel($level))()';
    await _runScript(script);
  }

  // return now zoom level
  Future<int> getLevel() async {
    final String script = '''(()=>{
  const level = map.getLevel();
  sendLevel.postMessage(level.toString());
})()''';
    await _runScript(script);

    return _state.getLevel()!;
  }

  // add marker
  // if addBounds option is true, you can use setBounds
  // addBounds default value is false
  // return marker index number

  int addMarker(KakaoLatLng location,
      {bool addBounds = false, String? markerImgLink, List<double>? iconSize}) {
    final String script = '''(()=>{
  const location = new kakao.maps.LatLng(${location.latitude}, ${location.longitude});
  ${iconSize != null ? '''const icon = new kakao.maps.MarkerImage(
    '$markerImgLink',
    new kakao.maps.Size(${iconSize[0]}, ${iconSize[1]}));''' : ''}
  const marker = new kakao.maps.Marker({
    position: location,
    ${iconSize != null ? 'image: icon,' : ''}
    clickable: true
  });
  marker.setMap(map);
  map.setCenter(location);
  ${addBounds ? 'bounds.extend(location);' : ''}
  markers[$_markerCount] = marker;
  kakao.maps.event.addListener(marker, 'click', ()=>{
    markerTouch.postMessage(location.toString()+'_$_markerCount');
  });
})()''';
    _runScript(script);
    if (addBounds && !_isUsingBounds) _isUsingBounds = true;
    return _markerCount++;
  }

  int addMarkerInfo(KakaoLatLng location, String id,
      {bool addBounds = false, String? markerImgLink, List<double>? iconSize}) {
    final String script = '''(()=>{
  const location = new kakao.maps.LatLng(${location.latitude}, ${location.longitude});
  ${iconSize != null ? '''const icon = new kakao.maps.MarkerImage(
    '$markerImgLink',
    new kakao.maps.Size(${iconSize[0]}, ${iconSize[1]}));''' : ''}
  const marker = new kakao.maps.Marker({
    position: location,
    ${iconSize != null ? 'image: icon,' : ''}
    clickable: true
  });
  marker.setMap(map);
  map.setCenter(location);
  ${addBounds ? 'bounds.extend(location);' : ''}
  markers[$_markerCount] = marker;
  kakao.maps.event.addListener(marker, 'click', ()=>{
    markerTouch.postMessage(location.toString()+'_$_markerCount'+'  ID is'+$id);
  });
})()''';
    _runScript(script);
    if (addBounds && !_isUsingBounds) _isUsingBounds = true;
    return _markerCount++;
  }

  int searchMarker(String name, String address,
      {bool addBounds = false, String? markerImgLink, List<double>? iconSize}){
    final String script = '''(()=>{
      var geocoder = new kakao.maps.services.Geocoder();
     
    // 주소로 좌표를 검색합니다
      geocoder.addressSearch($address, function(result, status) {

    // 정상적으로 검색이 완료됐으면 
        if (status === kakao.maps.services.Status.OK) {
          var location = new kakao.maps.LatLng(result[0].y, result[0].x);
          ${iconSize != null ? '''const icon = new kakao.maps.MarkerImage('$markerImgLink', 
          new kakao.maps.Size(${iconSize[0]}, ${iconSize[1]}));''' : ''}
          const marker = new kakao.maps.Marker({ position: location, ${iconSize != null ? 'image: icon,' : ''}
          clickable: true
          });
        }
      }); 
    })()''';
    _runScript(script);
    if (addBounds && !_isUsingBounds) _isUsingBounds = true;
    return _markerCount++;
  }

  void searchWord(
      {bool addBounds = false, String? markerImgLink, List<double>? iconSize}){
    final String script = '''(()=>{
   var infowindow = new kakao.maps.InfoWindow({zIndex:1});
var mapContainer = document.getElementById('map'), // 지도를 표시할 div 
    mapOption = {
        center: new kakao.maps.LatLng(37.566826, 126.9786567), // 지도의 중심좌표
        level: 3 // 지도의 확대 레벨
       
    };  
    var map = new kakao.maps.Map(mapContainer, mapOption);
    
   
    

// 지도를 생성합니다    
      // 장소 검색 객체를 생성합니다
var ps = new kakao.maps.services.Places(); 

// 키워드로 장소를 검색합니다
ps.keywordSearch('이태원 맛집', placesSearchCB); 

// 키워드 검색 완료 시 호출되는 콜백함수 입니다
function placesSearchCB (data, status, pagination) {
    if (status === kakao.maps.services.Status.OK) {
   

        // 검색된 장소 위치를 기준으로 지도 범위를 재설정하기위해
        // LatLngBounds 객체에 좌표를 추가합니다
        var bounds = new kakao.maps.LatLngBounds();

        for (var i=0; i<data.length; i++) {
            displayMarker(data[i]);    
            bounds.extend(new kakao.maps.LatLng(data[i].y, data[i].x));
        }       

        // 검색된 장소 위치를 기준으로 지도 범위를 재설정합니다
        map.setBounds(bounds);
    } 
}

// 지도에 마커를 표시하는 함수입니다
function displayMarker(place) {
    
    // 마커를 생성하고 지도에 표시합니다
    var marker = new kakao.maps.Marker({
        map: map,
        position: new kakao.maps.LatLng(place.y, place.x) 
    });

    // 마커에 클릭이벤트를 등록합니다
    kakao.maps.event.addListener(marker, 'click', function() {
        // 마커를 클릭하면 장소명이 인포윈도우에 표출됩니다
        infowindow.setContent('<div style="padding:5px;font-size:12px;">' + place.place_name + '</div>');
        
        infowindow.open(map, marker);
    });
}
    })()''';
    _runScript(script);

  }


//   int addMarkercustom(KakaoLatLng location,double latitude, double longitude,
//       {bool addBounds = false, String? markerImgLink, List<double>? iconSize}) {
//     final String script = '''(()=>{
//   const location = new kakao.maps.LatLng($latitude, $longitude);
//   ${iconSize != null ? '''const icon = new kakao.maps.MarkerImage(
//     '$markerImgLink',
//     new kakao.maps.Size(${iconSize[0]}, ${iconSize[1]}));''' : ''}
//   const marker = new kakao.maps.Marker({
//     position: location,
//     ${iconSize != null ? 'image: icon,' : ''}
//     clickable: true
//   });
//   marker.setMap(map);
//   ${addBounds ? 'bounds.extend(location);' : ''}
//   markers[$_markerCount] = marker;
//   kakao.maps.event.addListener(marker, 'click', ()=>{
//     markerTouch.postMessage(location.toString()+'_$_markerCount');
//   });
// })()''';
//     _runScript(script);
//     if (addBounds && !_isUsingBounds) _isUsingBounds = true;
//     return _markerCount++;
//   }


  // delete marker
  deleteMarker(int idx) {
    if (idx >= _markerCount) return; // bounds of index
    final String script = 'markers[$idx].setMap(null); markers[$idx] = null;';
    _runScript(script);
  }

  // delete all marker
  deleteAllMarkers() {
    final String script =
        'markers.forEach((v)=>v.setMap(null)); markers.length = 0;';
    _runScript(script);
    _markerCount = 0;
  }

  // resetting level and center point.
  // all markers added with the addBounds option enabled are visible.
  setBounds() {
    if (!_isUsingBounds) return;
    final String script = 'map.setBounds(bounds);';
    _runScript(script);
  }

  // add custom overlay
  // change overlayHtml, using markerHtml option
  // return custom overlay index number

  int addCustomOverlay(KakaoLatLng location, {String? markerHtml}) {
    String html = markerHtml ??
        '''<div style="background-color: orangered; border: 3px solid white; box-shadow: 1px 2px 4px rgba(0,0,0,0.2); border-radius: 9999px; padding: 7px;"/>''';
    final String script = '''(()=>{
  const location = new kakao.maps.LatLng(${location.latitude}, ${location.longitude});
  const customOverlay = new kakao.maps.CustomOverlay({
    position: location,
    content: `$html`
  });
  customOverlay.setMap(map);
  customOverlays[$_customOverlayCount] = customOverlay;
})()''';
    _runScript(script);
    return _customOverlayCount++;
  }

  // number of custom overlays
  int customOverlaysCount() => _customOverlayCount;
  // delete custom overlay using index number
  deleteCustomOverlay(int idx) {
    if (idx >= _customOverlayCount) return; // bounds of index
    final String script =
        'customOverlays[$idx].setMap(null); customOverlays[$idx] = null;';
    _runScript(script);
  }

  // delete all custom overlay
  deleteAllCustomOverlays() {
    final String script =
        'customOverlays.forEach((v)=>v.setMap(null)); customOverlays.length = 0;';
    _runScript(script);
    _customOverlayCount = 0;
  }

  // marker clusterer using added markers
  // make sure enable clustererServiceEnable option.
  startClustering(
      {bool avgCenter = true,
        int minLevel = 10,
        List<int>? calculator,
        List<String>? texts,
        List<Map<String, String>>? styles}) {
    final String script = '''const clusterer = new kakao.maps.MarkerClusterer({
  map: map,
  averageCenter: $avgCenter,
  minLevel: $minLevel,
  ${calculator != null ? "calculator: $calculator," : ""}
  ${texts != null ? "texts: ${KakaoMapUtil.listToJsString(texts)}," : ""}
  ${styles != null ? "styles: ${KakaoMapUtil.mapListToJson(styles)}" : ""}
});
${_markerCount != 0 ? 'clusterer.addMarkers(markers);' : ''}''';
    _runScript(script);
    _isUsingClustering = true;
  }

  // marker clusterer update
  updateClustering() {
    if (!_isUsingClustering) return; // todo : exception processing
    final String script = 'clusterer.addMarkers(markers);';
    _runScript(script);
  }

  bool nowClusteringEnabled() => _isUsingClustering;
}
