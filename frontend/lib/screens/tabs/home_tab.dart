// ============================================================
// 📁 lib/screens/tabs/home_tab.dart
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import '../../utils/colors.dart';
import 'active_tab.dart'; // ActiveRideButton, ActiveRideSheet, globalActiveRideState

typedef OnTabChange = void Function(int index);

// ── 핀 데이터 모델 ──────────────────────────────────────────
class RidePin {
  final String id, hostId, dept, dest, time;
  final int max, cur;
  final double lat, lng;

  const RidePin({
    required this.id, required this.hostId,
    required this.dept, required this.dest, required this.time,
    required this.max, required this.cur,
    required this.lat, required this.lng,
  });

  // 동승팀 모집 현황 판단
  bool get isFull => cur >= max;

  // 현재 위치 <-> 핀까지 거리 계산
  double distanceTo(double centerLat, double centerLng) =>
      Geolocator.distanceBetween(lat, lng, centerLat, centerLng);
}
// 동승 핀 더미 데이터
const List<RidePin> _allPins = [
  RidePin(id:'1', hostId:'taxi_kim',   dept:'강남역 2번출구',  dest:'김포공항',    time:'14:30', max:4, cur:2, lat:37.4979, lng:127.0276),
  RidePin(id:'2', hostId:'seoul_lee',  dept:'홍대입구역',      dest:'인천공항 T1', time:'15:00', max:3, cur:1, lat:37.5574, lng:126.9249),
  RidePin(id:'3', hostId:'rider_park', dept:'잠실역 8번출구',  dest:'강남역',       time:'14:45', max:4, cur:3, lat:37.5133, lng:127.1001),
  RidePin(id:'4', hostId:'go_choi',    dept:'신촌역',          dest:'판교역',       time:'16:00', max:2, cur:0, lat:37.5551, lng:126.9368),
  RidePin(id:'5', hostId:'map_yoon',   dept:'판교역',          dest:'강남역',       time:'17:00', max:3, cur:2, lat:37.3947, lng:127.1111),
  RidePin(id:'6', hostId:'fast_jung',  dept:'수원역',          dest:'사당역',       time:'18:30', max:4, cur:1, lat:37.2663, lng:127.0027),
];

// ============================================================
class HomeTab extends StatefulWidget {
  final OnTabChange? onTabChange;
  final VoidCallback? onGoToCreate;
  const HomeTab({super.key, this.onTabChange, this.onGoToCreate});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  NaverMapController? _mapController;

  Position? _currentPosition;
  bool _locationLoading = true;
  String? _activePinId;
  String? _selectedRideId;
  bool _showNotifications = false;
  List<RidePin> _visiblePins = [];
  double _mapCenterLat = 37.5665;
  double _mapCenterLng = 126.9780;
  bool _showSearch = false;
  String _searchQuery = '';

  // 이용 중 시트 표시 여부 (홈탭 전용)
  bool _showActiveDetail = false;

  final DraggableScrollableController _sheetController = DraggableScrollableController();
  final TextEditingController _searchCtrl = TextEditingController();

  static const _dummyNotifications = [
    {'icon':'🚖','msg':'taxi_kim님이 동승 요청을 수락했습니다.',     'time':'방금 전'},
    {'icon':'💬','msg':'강남→김포 팀 채팅에 새 메시지가 있습니다.',  'time':'5분 전'},
    {'icon':'📍','msg':'내 근처에 새로운 동승 핀이 생성되었습니다.', 'time':'12분 전'},
    {'icon':'✅','msg':'이용 내역이 정산되었습니다.',                 'time':'1시간 전'},
  ];

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _locationLoading = false);
      _showLocationError('위치 서비스가 꺼져 있습니다.\n설정에서 위치 서비스를 켜주세요.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _locationLoading = false);
        _showLocationError('위치 권한이 거부되었습니다.');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() => _locationLoading = false);
      _showLocationError('위치 권한이 영구 차단되었습니다.\n설정에서 권한을 허용해주세요.');
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() {
        _currentPosition = position;
        _mapCenterLat = position.latitude;
        _mapCenterLng = position.longitude;
        _locationLoading = false;
      });
      _updateVisiblePins(position.latitude, position.longitude);
      if (_mapController != null) _moveToMyLocation();
    } catch (e) {
      setState(() => _locationLoading = false);
    }
  }

  Future<void> _moveToMyLocation() async {
    if (_mapController == null || _currentPosition == null) return;
    await _mapController!.updateCamera(
      NCameraUpdate.scrollAndZoomTo(
        target: NLatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        zoom: 15,
      ),
    );
  }

  void _updateVisiblePins(double centerLat, double centerLng,
      {double radiusMeters = 5000}) {
    setState(() {
      _mapCenterLat = centerLat;
      _mapCenterLng = centerLng;
      _visiblePins = _allPins
          .where((pin) => pin.distanceTo(centerLat, centerLng) <= radiusMeters)
          .toList();
    });
  }

  Future<void> _addMarkersToMap() async {
    if (_mapController == null) return;
    await _mapController!.clearOverlays();

    for (final pin in _visiblePins) {
      final marker = NMarker(
        id: pin.id,
        position: NLatLng(pin.lat, pin.lng),
        caption: NOverlayCaption(
          text: '${pin.cur}/${pin.max}명',
          textSize: 11,
          color: pin.isFull ? AppColors.gray : AppColors.primary,
          haloColor: Colors.white,
        ),
        subCaption: NOverlayCaption(
          text: pin.hostId,
          textSize: 9,
          color: AppColors.gray,
        ),
      );
      marker.setOnTapListener((overlay) {
        setState(() {
          _activePinId = overlay.info.id;
          _selectedRideId = null;
        });
      });
      _mapController!.addOverlay(marker);
    }

    if (_currentPosition != null) {
      final myMarker = NMarker(
        id: 'my_location',
        position: NLatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        caption: const NOverlayCaption(
          text: '📍 내 위치',
          textSize: 12,
          color: Colors.blue,
          haloColor: Colors.white,
        ),
      );
      await _mapController!.addOverlay(myMarker);
    }
  }

  void _showLocationError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating));
  }

  RidePin? get _activePinData => _activePinId == null
      ? null
      : _visiblePins.firstWhere((p) => p.id == _activePinId,
      orElse: () => _allPins.first);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(children: [
              _buildHeader(),
              Expanded(child: _buildMapWithSheet()),
              // 이용 중 창
              AnimatedBuilder(
                animation: globalActiveRideState,
                builder: (_, __) => ActiveRideButton(
                  state: globalActiveRideState,
                  onTap: () => setState(() => _showActiveDetail = true),
                ),
              ),
            ]),
            if (_showNotifications) _buildNotificationOverlay(),
            if (_showSearch) _buildSearchOverlay(),

            // 이용 중 상세 시트 (홈탭 오버레이)
            if (_showActiveDetail)
              ActiveRideSheet(
                state: globalActiveRideState,
                onClose: () => setState(() => _showActiveDetail = false),
                onGoToChat: () {
                  final ride = globalActiveRideState.activeRide;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ActiveTabChatBridge(
                        hostId: ride.hostId,
                        dept: ride.dept,
                        dest: ride.dest,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Row(children: [
            RichText(text: const TextSpan(
              style: TextStyle(fontSize: 26, letterSpacing: 2, fontWeight: FontWeight.w900),
              children: [
                TextSpan(text: 'TAXI', style: TextStyle(color: AppColors.secondary)),
                TextSpan(text: 'MATE', style: TextStyle(color: AppColors.primary)),
              ],
            )),
            const Spacer(),
            Stack(children: [
              IconButton(
                icon: Icon(
                  _showNotifications ? Icons.notifications : Icons.notifications_outlined,
                  color: _showNotifications ? AppColors.primary : AppColors.secondary,
                ),
                onPressed: () => setState(() => _showNotifications = !_showNotifications),
              ),
              Positioned(top: 8, right: 8,
                  child: Container(width: 8, height: 8,
                      decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle))),
            ]),
            GestureDetector(
              onTap: () => widget.onTabChange?.call(4),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: AppColors.bg, shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border)),
                child: const Icon(Icons.person, color: AppColors.gray, size: 22),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _showSearch = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(children: [
                    Icon(Icons.search, color: AppColors.gray, size: 18),
                    SizedBox(width: 8),
                    Text('출발지 또는 목적지 검색...',
                        style: TextStyle(fontSize: 13, color: AppColors.gray)),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => widget.onGoToCreate?.call(),
              child: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 24),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildMapWithSheet() {
    return Stack(children: [
      _buildNaverMap(),

      // 내 위치 버튼
      Positioned(
        bottom: _activePinId != null ? 320 : 24,
        right: 16,
        child: FloatingActionButton.small(
          heroTag: 'location_btn',
          backgroundColor: Colors.white,
          elevation: 4,
          onPressed: _moveToMyLocation,
          child: const Icon(Icons.my_location, color: AppColors.primary, size: 22),
        ),
      ),

      // 핀 목록 시트
      if (_activePinId != null)
        DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: 0.45,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          snap: true,
          snapSizes: const [0.3, 0.45, 0.85],
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -4))],
              ),
              child: Column(children: [
                _buildSheetHeader(),
                Expanded(
                  child: _visiblePins.isEmpty
                      ? const Center(
                      child: Text('이 지역에 동승 핀이 없습니다.',
                          style: TextStyle(color: AppColors.gray)))
                      : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _visiblePins.length,
                    itemBuilder: (_, i) => _buildRideCard(_visiblePins[i]),
                  ),
                ),
              ]),
            );
          },
        ),

      // 로딩 오버레이
      if (_locationLoading)
        Container(
          color: Colors.white.withOpacity(0.7),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 12),
                Text('내 위치를 찾는 중...',
                    style: TextStyle(fontSize: 13, color: AppColors.gray)),
              ],
            ),
          ),
        ),
    ]);
  }

  Widget _buildNaverMap() {
    if (kIsWeb) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 12),
              Text('지도는 모바일에서 확인 가능합니다',
                  style: TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    final initialPosition = NCameraPosition(
      target: NLatLng(_mapCenterLat, _mapCenterLng),
      zoom: 14,
    );

    return NaverMap(
      options: NaverMapViewOptions(
        initialCameraPosition: initialPosition,
        mapType: NMapType.basic,
        activeLayerGroups: [NLayerGroup.building, NLayerGroup.transit],
        locationButtonEnable: false,
        consumeSymbolTapEvents: false,
        rotationGesturesEnable: true,
        scrollGesturesEnable: true,
        tiltGesturesEnable: false,
        zoomGesturesEnable: true,
        stopGesturesEnable: false,
        minZoom: 6,
        maxZoom: 21,
        extent: const NLatLngBounds(
          southWest: NLatLng(33.0, 124.5),
          northEast: NLatLng(38.9, 131.9),
        ),
        nightModeEnable: false,
        logoClickEnable: true,
        logoAlign: NLogoAlign.leftBottom,
      ),
      onMapReady: (controller) async {
        _mapController = controller;
        if (_currentPosition != null) await _moveToMyLocation();
        await _addMarkersToMap();
      },
      onCameraIdle: () {
        if (_mapController == null) return;
        _mapController!.getCameraPosition().then((cameraPos) {
          final center = cameraPos.target;
          final movedDistance = Geolocator.distanceBetween(
            _mapCenterLat, _mapCenterLng,
            center.latitude, center.longitude,
          );
          if (movedDistance > 500) {
            _updateVisiblePins(center.latitude, center.longitude);
            _addMarkersToMap();
          }
        });
      },
      onMapTapped: (point, latLng) {
        if (_activePinId != null) {
          setState(() { _activePinId = null; _selectedRideId = null; });
        }
        if (_showNotifications) {
          setState(() => _showNotifications = false);
        }
      },
    );
  }

  Widget _buildSheetHeader() {
    final pinData = _activePinData;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Column(children: [
        GestureDetector(
          onTap: () {
            final current = _sheetController.size;
            final targetSize = current >= 0.8 ? 0.45 : 0.85;
            _sheetController.animateTo(targetSize,
                duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
          },
          behavior: HitTestBehavior.translucent,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
        ),
        Row(children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('동승 모집 목록',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.secondary)),
              if (pinData != null)
                Text('${pinData.dept} 주변 ${_visiblePins.length}팀',
                    style: const TextStyle(fontSize: 11, color: AppColors.gray)),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              setState(() {
                _visiblePins.sort((a, b) =>
                    a.distanceTo(_mapCenterLat, _mapCenterLng)
                        .compareTo(b.distanceTo(_mapCenterLat, _mapCenterLng)));
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text('📍 거리순',
                  style: TextStyle(fontSize: 11, color: AppColors.gray)),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() { _activePinId = null; _selectedRideId = null; }),
            child: const Icon(Icons.close, color: AppColors.gray, size: 20),
          ),
        ]),
      ]),
    );
  }

  Widget _buildRideCard(RidePin pin) {
    final isSelected = _selectedRideId == pin.id;
    final distanceM = pin.distanceTo(_mapCenterLat, _mapCenterLng);
    final distanceText = distanceM < 1000
        ? '${distanceM.toInt()}m'
        : '${(distanceM / 1000).toStringAsFixed(1)}km';

    return GestureDetector(
      onTap: () {
        setState(() => _selectedRideId = isSelected ? null : pin.id);
        if (!isSelected) {
          _mapController?.updateCamera(
            NCameraUpdate.scrollAndZoomTo(
              target: NLatLng(pin.lat, pin.lng),
              zoom: 16,
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color: AppColors.bg,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border)),
                child: const Icon(Icons.person, color: AppColors.gray, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('@${pin.hostId}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondary)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text('📍 $distanceText',
                            style: const TextStyle(fontSize: 9, color: AppColors.gray)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Flexible(
                          child: Text(pin.dept,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text('→',
                            style: TextStyle(
                                color: AppColors.textSub, fontWeight: FontWeight.w700)),
                      ),
                      Flexible(
                          child: Text(pin.dest,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.secondary),
                              overflow: TextOverflow.ellipsis)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  const Text('출발',
                      style: TextStyle(fontSize: 9, color: Colors.white70)),
                  Text(pin.time,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              ...List.generate(pin.max, (j) => Container(
                width: 22, height: 22,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: j < pin.cur ? AppColors.primary : AppColors.bg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: j < pin.cur ? AppColors.primary : AppColors.border),
                ),
                child: j < pin.cur
                    ? const Icon(Icons.person, color: Colors.white, size: 13)
                    : null,
              )),
              const SizedBox(width: 6),
              Text('${pin.cur}/${pin.max}명',
                  style: const TextStyle(fontSize: 11, color: AppColors.gray)),
              if (pin.isFull)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(100)),
                  child: const Text('마감',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppColors.gray,
                          fontWeight: FontWeight.w700)),
                ),
            ]),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              child: isSelected
                  ? Column(children: [
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pin.isFull ? AppColors.gray : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: pin.isFull ? null : () {},
                    child: Text(pin.isFull ? '마감된 팀입니다' : '참여하기',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ])
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationOverlay() {
    return Positioned(
      top: 0, right: 12, left: 12,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        child: Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                child: Row(children: [
                  const Text('알림',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(foregroundColor: AppColors.gray),
                    child: const Text('모두 읽음',
                        style: TextStyle(fontSize: 11)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.gray),
                    onPressed: () => setState(() => _showNotifications = false),
                  ),
                ]),
              ),
              const Divider(height: 1, color: AppColors.border),
              ..._dummyNotifications.map((n) => InkWell(
                onTap: () => setState(() => _showNotifications = false),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n['icon']!, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n['msg']!,
                                style: const TextStyle(
                                    fontSize: 13, color: AppColors.secondary)),
                            const SizedBox(height: 2),
                            Text(n['time']!,
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.gray)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchOverlay() {
    final filtered = _searchQuery.isEmpty
        ? _allPins
        : _allPins
        .where((p) =>
    p.dept.contains(_searchQuery) || p.dest.contains(_searchQuery))
        .toList();

    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          setState(() { _showSearch = false; _searchQuery = ''; _searchCtrl.clear(); });
        },
        child: Container(
          color: Colors.black.withOpacity(0.3),
          child: Column(children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: '출발지 또는 목적지 검색...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppColors.gray),
                      prefixIcon: const Icon(Icons.search, color: AppColors.gray),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                          icon: const Icon(Icons.clear, color: AppColors.gray),
                          onPressed: () =>
                              setState(() { _searchQuery = ''; _searchCtrl.clear(); }))
                          : null,
                      filled: true, fillColor: AppColors.bg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                          const BorderSide(color: AppColors.primary, width: 1.5)),
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () {
                    setState(() { _showSearch = false; _searchQuery = ''; _searchCtrl.clear(); });
                  },
                  child: const Text('취소',
                      style: TextStyle(color: AppColors.gray)),
                ),
              ]),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  color: Colors.white,
                  child: filtered.isEmpty
                      ? const Center(
                      child: Text('검색 결과가 없습니다.',
                          style: TextStyle(color: AppColors.gray)))
                      : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _buildSearchResultCard(filtered[i]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildSearchResultCard(RidePin pin) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showSearch = false;
          _searchQuery = '';
          _searchCtrl.clear();
          _activePinId = pin.id;
        });
        _mapController?.updateCamera(
          NCameraUpdate.scrollAndZoomTo(
              target: NLatLng(pin.lat, pin.lng), zoom: 16),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: AppColors.bg,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border)),
            child: const Icon(Icons.person, color: AppColors.gray, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@${pin.hostId}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary)),
                const SizedBox(height: 4),
                Row(children: [
                  Flexible(
                      child: Text(pin.dept,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis)),
                  const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text('→',
                          style: TextStyle(color: AppColors.textSub))),
                  Flexible(
                      child: Text(pin.dest,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.secondary),
                          overflow: TextOverflow.ellipsis)),
                ]),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8)),
            child: Text(pin.time,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ]),
      ),
    );
  }
}