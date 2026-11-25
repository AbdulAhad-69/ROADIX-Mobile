import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import '../src/core/config/app_config.dart';
import '../src/core/models/geo_point.dart';

/// Unified controller abstracting camera moves across Google Maps (`google_maps_flutter`)
/// and MapLibre (`maplibre_gl`).
class RoadixMapController {
  gmaps.GoogleMapController? _googleController;
  ml.MapLibreMapController? _mapLibreController;

  void _attachGoogle(gmaps.GoogleMapController ctrl) {
    _googleController = ctrl;
  }

  void _attachMapLibre(ml.MapLibreMapController ctrl) {
    _mapLibreController = ctrl;
  }

  /// Animates the map camera to [target] (and optional [zoom]).
  Future<void> animateCamera(RoadixGeoPoint target, {double? zoom}) async {
    final gCtrl = _googleController;
    if (gCtrl != null) {
      final update = zoom != null
          ? gmaps.CameraUpdate.newLatLngZoom(
              gmaps.LatLng(target.latitude, target.longitude),
              zoom,
            )
          : gmaps.CameraUpdate.newLatLng(
              gmaps.LatLng(target.latitude, target.longitude),
            );
      await gCtrl.animateCamera(update);
      return;
    }

    final mlCtrl = _mapLibreController;
    if (mlCtrl != null) {
      final update = zoom != null
          ? ml.CameraUpdate.newLatLngZoom(
              ml.LatLng(target.latitude, target.longitude),
              zoom,
            )
          : ml.CameraUpdate.newLatLng(
              ml.LatLng(target.latitude, target.longitude),
            );
      await mlCtrl.animateCamera(update);
    }
  }

  void dispose() {
    _googleController = null;
    _mapLibreController = null;
  }
}

/// Interactive dual-engine map widget that uses Google Maps (`google_maps_flutter`)
/// when `GOOGLE_MAPS_API_KEY` is configured and seamlessly renders Geoapify/OpenFreeMap
/// vector tiles via MapLibre when no Google Maps key is supplied yet.
class RoadixMapView extends StatefulWidget {
  final RoadixGeoPoint initialCenter;
  final double initialZoom;
  final RoadixGeoPoint? breakdownPoint;
  final RoadixGeoPoint? mechanicPoint;
  final List<RoadixGeoPoint> routePoints;
  final void Function(RoadixMapController controller)? onMapCreated;
  final void Function(RoadixGeoPoint center)? onCameraMove;
  final VoidCallback? onCameraIdle;
  final bool myLocationEnabled;
  final bool forceGoogleMapsForTest;
  final Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers;

  const RoadixMapView({
    super.key,
    required this.initialCenter,
    this.initialZoom = 15.5,
    this.breakdownPoint,
    this.mechanicPoint,
    this.routePoints = const [],
    this.onMapCreated,
    this.onCameraMove,
    this.onCameraIdle,
    this.myLocationEnabled = false,
    this.forceGoogleMapsForTest = false,
    this.gestureRecognizers,
  });

  @override
  State<RoadixMapView> createState() => _RoadixMapViewState();
}

class _RoadixMapViewState extends State<RoadixMapView> {
  final RoadixMapController _controller = RoadixMapController();
  ml.MapLibreMapController? _mlCtrl;
  ml.Circle? _breakdownCircle;
  ml.Circle? _mechanicCircle;
  ml.Line? _routeLine;
  bool _mlStyleLoaded = false;

  bool get _useGoogleMaps =>
      widget.forceGoogleMapsForTest || AppConfig.hasGoogleMapsApiKey;

  @override
  void didUpdateWidget(covariant RoadixMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_useGoogleMaps && _mlStyleLoaded) {
      if (oldWidget.breakdownPoint != widget.breakdownPoint ||
          oldWidget.mechanicPoint != widget.mechanicPoint ||
          oldWidget.routePoints != widget.routePoints) {
        _syncMapLibreOverlays();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _mlCtrl = null;
    super.dispose();
  }

  Future<void> _syncMapLibreOverlays() async {
    final ctrl = _mlCtrl;
    if (ctrl == null || !_mlStyleLoaded) return;

    try {
      if (widget.breakdownPoint != null) {
        final pos = ml.LatLng(
          widget.breakdownPoint!.latitude,
          widget.breakdownPoint!.longitude,
        );
        if (_breakdownCircle != null) {
          await ctrl.updateCircle(
            _breakdownCircle!,
            ml.CircleOptions(geometry: pos),
          );
        } else {
          _breakdownCircle = await ctrl.addCircle(
            ml.CircleOptions(
              geometry: pos,
              circleRadius: 8.0,
              circleColor: '#DC2626',
              circleStrokeWidth: 3.0,
              circleStrokeColor: '#FFFFFF',
            ),
          );
        }
      }

      if (widget.mechanicPoint != null) {
        final pos = ml.LatLng(
          widget.mechanicPoint!.latitude,
          widget.mechanicPoint!.longitude,
        );
        if (_mechanicCircle != null) {
          await ctrl.updateCircle(
            _mechanicCircle!,
            ml.CircleOptions(geometry: pos),
          );
        } else {
          _mechanicCircle = await ctrl.addCircle(
            ml.CircleOptions(
              geometry: pos,
              circleRadius: 8.0,
              circleColor: '#047857',
              circleStrokeWidth: 3.0,
              circleStrokeColor: '#FFFFFF',
            ),
          );
        }
      }

      if (widget.routePoints.length >= 2) {
        final mlPoints = widget.routePoints
            .map((p) => ml.LatLng(p.latitude, p.longitude))
            .toList();
        if (_routeLine != null) {
          await ctrl.updateLine(
            _routeLine!,
            ml.LineOptions(geometry: mlPoints),
          );
        } else {
          _routeLine = await ctrl.addLine(
            ml.LineOptions(
              geometry: mlPoints,
              lineColor: '#B91C1C',
              lineWidth: 4.5,
            ),
          );
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_useGoogleMaps) {
      final markers = <gmaps.Marker>{};
      if (widget.breakdownPoint != null) {
        markers.add(
          gmaps.Marker(
            markerId: const gmaps.MarkerId('breakdown'),
            position: gmaps.LatLng(
              widget.breakdownPoint!.latitude,
              widget.breakdownPoint!.longitude,
            ),
            icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
              gmaps.BitmapDescriptor.hueRed,
            ),
            infoWindow: const gmaps.InfoWindow(title: 'Breakdown Location'),
          ),
        );
      }
      if (widget.mechanicPoint != null) {
        markers.add(
          gmaps.Marker(
            markerId: const gmaps.MarkerId('mechanic'),
            position: gmaps.LatLng(
              widget.mechanicPoint!.latitude,
              widget.mechanicPoint!.longitude,
            ),
            icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
              gmaps.BitmapDescriptor.hueGreen,
            ),
            infoWindow: const gmaps.InfoWindow(title: 'Assigned Technician'),
          ),
        );
      }

      final polylines = <gmaps.Polyline>{};
      if (widget.routePoints.length >= 2) {
        polylines.add(
          gmaps.Polyline(
            polylineId: const gmaps.PolylineId('rescue_route'),
            points: widget.routePoints
                .map((p) => gmaps.LatLng(p.latitude, p.longitude))
                .toList(),
            color: const Color(0xFFB91C1C),
            width: 5,
          ),
        );
      }

      return gmaps.GoogleMap(
        initialCameraPosition: gmaps.CameraPosition(
          target: gmaps.LatLng(
            widget.initialCenter.latitude,
            widget.initialCenter.longitude,
          ),
          zoom: widget.initialZoom,
        ),
        myLocationEnabled: widget.myLocationEnabled,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        markers: markers,
        polylines: polylines,
        gestureRecognizers: widget.gestureRecognizers ?? const {},
        onMapCreated: (ctrl) {
          _controller._attachGoogle(ctrl);
          widget.onMapCreated?.call(_controller);
        },
        onCameraMove: widget.onCameraMove == null
            ? null
            : (pos) => widget.onCameraMove!(
                  RoadixGeoPoint(pos.target.latitude, pos.target.longitude),
                ),
        onCameraIdle: widget.onCameraIdle,
      );
    }

    return ml.MapLibreMap(
      styleString: AppConfig.mapStyleUrl,
      initialCameraPosition: ml.CameraPosition(
        target: ml.LatLng(
          widget.initialCenter.latitude,
          widget.initialCenter.longitude,
        ),
        zoom: widget.initialZoom,
      ),
      myLocationEnabled: widget.myLocationEnabled,
      trackCameraPosition: widget.onCameraMove != null || widget.onCameraIdle != null,
      gestureRecognizers: widget.gestureRecognizers,
      onMapCreated: (ctrl) {
        _mlCtrl = ctrl;
        _controller._attachMapLibre(ctrl);
        widget.onMapCreated?.call(_controller);
      },
      onStyleLoadedCallback: () {
        _mlStyleLoaded = true;
        _syncMapLibreOverlays();
      },
      onCameraMove: widget.onCameraMove == null
          ? null
          : (pos) => widget.onCameraMove!(
                RoadixGeoPoint(pos.target.latitude, pos.target.longitude),
              ),
      onCameraIdle: () {
        final target = _mlCtrl?.cameraPosition?.target;
        if (target != null && widget.onCameraMove != null) {
          widget.onCameraMove!(RoadixGeoPoint(target.latitude, target.longitude));
        }
        widget.onCameraIdle?.call();
      },
    );
  }
}
