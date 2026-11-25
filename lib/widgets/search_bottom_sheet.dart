import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/geocoding_service.dart';
import '../services/supabase_service.dart';
import '../src/core/utils/geometry_utils.dart';
import '../src/core/utils/phone_utils.dart';
import '../theme/app_colors.dart';

class SearchBottomSheet extends StatefulWidget {
  final double currentLat;
  final double currentLng;
  final void Function(String workshopName, double lat, double lng)?
      onFacilitySelected;
  final Future<List<Map<String, dynamic>>> Function(double lat, double lng)?
      loadFacilitiesOverride;

  const SearchBottomSheet({
    super.key,
    required this.currentLat,
    required this.currentLng,
    this.onFacilitySelected,
    this.loadFacilitiesOverride,
  });

  @override
  State<SearchBottomSheet> createState() => _SearchBottomSheetState();
}

class _SearchBottomSheetState extends State<SearchBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  Timer? _debounce;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _facilities = [];

  final List<String> _categories = [
    'All',
    'Workshop',
    'Fuel & CNG',
    'Hospital',
    'Police',
  ];

  @override
  void initState() {
    super.initState();
    _loadFacilities();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  IconData _iconForCategory(String category) {
    return switch (category) {
      'Police' => Icons.local_police_outlined,
      'Hospital' => Icons.local_hospital_outlined,
      'Fuel & CNG' => Icons.local_gas_station_outlined,
      _ => Icons.build_circle_outlined,
    };
  }

  Future<void> _loadFacilities({String query = ''}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.loadFacilitiesOverride != null) {
        final injected =
            await widget.loadFacilitiesOverride!(widget.currentLat, widget.currentLng);
        if (mounted) {
          setState(() {
            _facilities = injected;
            _isLoading = false;
          });
        }
        return;
      }

      final combined = <Map<String, dynamic>>[];

      // 1. Live verified workshops from Supabase mechanic_profiles
      try {
        final mechanics = await SupabaseService().client
            .from('mechanic_profiles')
            .select(
              'profile_id, workshop_name, workshop_address, current_location, rating, profiles(phone)',
            )
            .eq('is_verified', true)
            .limit(20);
        for (final row in (mechanics as List)) {
          final coords =
              GeometryUtils.parsePostgisPoint(row['current_location']);
          if (coords == null) continue;
          final dist = GeometryUtils.calculateDistanceKm(
            widget.currentLat,
            widget.currentLng,
            coords.$1,
            coords.$2,
          );
          final profileMap = row['profiles'] as Map?;
          combined.add({
            'name': row['workshop_name']?.toString() ?? 'Verified Workshop',
            'category': 'Workshop',
            'address': row['workshop_address']?.toString() ?? 'Verified ROADIX Partner',
            'phone': profileMap?['phone']?.toString() ?? '',
            'lat': coords.$1,
            'lng': coords.$2,
            'distanceKm': dist,
            'isVerified': true,
            'icon': Icons.verified_outlined,
          });
        }
      } catch (_) {}

      // 2. Live nearby POIs & search results from Geoapify Places API
      final places = await GeocodingService.searchNearbyPlaces(
        lat: widget.currentLat,
        lng: widget.currentLng,
        query: query,
      );
      for (final p in places) {
        combined.add({
          'name': p.name,
          'category': p.category,
          'address': p.address,
          'phone': p.phone,
          'lat': p.latitude,
          'lng': p.longitude,
          'distanceKm': p.distanceKm,
          'isVerified': false,
          'icon': _iconForCategory(p.category),
        });
      }

      combined.sort((a, b) {
        final da = (a['distanceKm'] as num?)?.toDouble() ??
            GeometryUtils.calculateDistanceKm(
              widget.currentLat,
              widget.currentLng,
              (a['lat'] as num).toDouble(),
              (a['lng'] as num).toDouble(),
            );
        final db = (b['distanceKm'] as num?)?.toDouble() ??
            GeometryUtils.calculateDistanceKm(
              widget.currentLat,
              widget.currentLng,
              (b['lat'] as num).toDouble(),
              (b['lng'] as num).toDouble(),
            );
        return da.compareTo(db);
      });

      if (mounted) {
        setState(() {
          _facilities = combined;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load nearby facilities: $e';
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredFacilities {
    final query = _searchController.text.toLowerCase().trim();
    return _facilities.where((item) {
      final catMatches =
          _selectedCategory == 'All' || item['category'] == _selectedCategory;
      final qMatches = query.isEmpty ||
          (item['name']?.toString().toLowerCase().contains(query) ?? false) ||
          (item['address']?.toString().toLowerCase().contains(query) ?? false) ||
          (item['category']?.toString().toLowerCase().contains(query) ?? false);
      return catMatches && qMatches;
    }).toList();
  }

  String _formatDistance(Map<String, dynamic> item) {
    final km = GeometryUtils.calculateDistanceKm(
      widget.currentLat,
      widget.currentLng,
      (item['lat'] as num).toDouble(),
      (item['lng'] as num).toDouble(),
    );
    final suffix = item['isVerified'] == true ? ' • Verified Partner' : '';
    return '${km.toStringAsFixed(1)} km away$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final results = _filteredFacilities;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.78,
        decoration: const BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.slateBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Find Roadside Service',
                      style: TextStyle(
                        color: AppColors.chassisText,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close search',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.slateMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {});
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 400), () {
                    if (mounted && widget.loadFacilitiesOverride == null) {
                      _loadFacilities(query: value);
                    }
                  });
                },
                style: const TextStyle(color: AppColors.chassisText, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search area, garage, fuel, hospital...',
                  prefixIcon: Icon(Icons.search, color: AppColors.slateMuted),
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final cat = _categories[idx];
                  final isSelected = _selectedCategory == cat;
                  return InkWell(
                    onTap: () => setState(() => _selectedCategory = cat),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.caliperCrimson
                            : AppColors.surfaceTint,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.caliperCrimson
                              : AppColors.slateBorder,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.chassisText,
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),
            const Divider(color: AppColors.slateBorder, height: 1),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.caliperCrimson,
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.slateMuted,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: () => _loadFacilities(
                                    query: _searchController.text,
                                  ),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : results.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.search_off,
                                      size: 38,
                                      color: AppColors.slateMuted,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'No roadside facilities match your search nearby',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppColors.slateMuted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              itemCount: results.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, idx) {
                                final item = results[idx];
                                final phone = item['phone']?.toString() ?? '';
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.porcelainBg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.slateBorder),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: AppColors.crimsonLight,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              (item['icon'] as IconData?) ??
                                                  _iconForCategory(
                                                    item['category']?.toString() ??
                                                        'Workshop',
                                                  ),
                                              color: AppColors.crimsonHover,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item['name']?.toString() ??
                                                      'Service Facility',
                                                  style: const TextStyle(
                                                    color: AppColors.chassisText,
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _formatDistance(item),
                                                  style: const TextStyle(
                                                    color: AppColors.emeraldDark,
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w700,
                                                    fontFeatures: [
                                                      FontFeature.tabularFigures(),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        item['address']?.toString() ?? '',
                                        style: const TextStyle(
                                          color: AppColors.slateMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          if (phone.isNotEmpty) ...[
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () async {
                                                  HapticFeedback.lightImpact();
                                                  final ok =
                                                      await PhoneUtils.launchCall(
                                                          phone);
                                                  if (!ok && context.mounted) {
                                                    ScaffoldMessenger.of(context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Could not open phone dialer for $phone.',
                                                        ),
                                                        backgroundColor:
                                                            AppColors.crimsonHover,
                                                      ),
                                                    );
                                                  }
                                                },
                                                icon: const Icon(Icons.call, size: 15),
                                                label: const Text('Call'),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          Expanded(
                                            flex: 2,
                                            child: ElevatedButton.icon(
                                              onPressed: () {
                                                Navigator.pop(context);
                                                widget.onFacilitySelected?.call(
                                                  item['name']?.toString() ??
                                                      'Roadside Location',
                                                  (item['lat'] as num).toDouble(),
                                                  (item['lng'] as num).toDouble(),
                                                );
                                              },
                                              icon: const Icon(Icons.near_me, size: 15),
                                              label: const Text('Set Breakdown Spot'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
