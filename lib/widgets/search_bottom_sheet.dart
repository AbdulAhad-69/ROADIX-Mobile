import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../src/core/utils/geometry_utils.dart';
import '../src/core/utils/phone_utils.dart';
import '../theme/app_colors.dart';

class SearchBottomSheet extends StatefulWidget {
  final Function(String facilityName, double lat, double lng)? onFacilitySelected;
  final double currentLat;
  final double currentLng;

  const SearchBottomSheet({
    super.key,
    this.onFacilitySelected,
    this.currentLat = 23.8759,
    this.currentLng = 90.3795,
  });

  @override
  State<SearchBottomSheet> createState() => _SearchBottomSheetState();
}

class _SearchBottomSheetState extends State<SearchBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    '24/7 Tire Repair',
    'Fuel & CNG',
    'Authorized Garages',
    'Highway Police',
  ];

  final List<Map<String, dynamic>> _facilities = [
    {
      'name': 'Uttara 24/7 Vulcanizing & Tire Hub',
      'category': '24/7 Tire Repair',
      'address': 'House 14, Sector 7, Jashimuddin Ave, Uttara',
      'phone': '+880 1711-234567',
      'icon': Icons.album_outlined,
      'lat': 23.8732,
      'lng': 90.3980,
    },
    {
      'name': 'Padma Oil & CNG Filling Station',
      'category': 'Fuel & CNG',
      'address': 'Airport Road, Kawla, Dhaka',
      'phone': '+880 1819-345678',
      'icon': Icons.local_gas_station_outlined,
      'lat': 23.8512,
      'lng': 90.4078,
    },
    {
      'name': 'Navana Toyota Certified Workshop',
      'category': 'Authorized Garages',
      'address': 'Plot 4, Sector 9, Sonargaon Janapath, Uttara',
      'phone': '+880 1912-987654',
      'icon': Icons.car_repair,
      'lat': 23.8795,
      'lng': 90.3842,
    },
    {
      'name': 'Highway Police Outpost (Abdullahpur)',
      'category': 'Highway Police',
      'address': 'Abdullahpur Bus Stand, Dhaka-Mymensingh Hwy',
      'phone': '999',
      'icon': Icons.local_police_outlined,
      'lat': 23.8967,
      'lng': 90.3883,
    },
    {
      'name': 'Mirpur Battery & Starter Clinic',
      'category': '24/7 Tire Repair',
      'address': 'Section 10, Mirpur Roundabout',
      'phone': '+880 1622-445566',
      'icon': Icons.battery_charging_full,
      'lat': 23.8069,
      'lng': 90.3687,
    },
  ];

  String _formatDistance(Map<String, dynamic> item) {
    final km = GeometryUtils.calculateDistanceKm(
      widget.currentLat,
      widget.currentLng,
      (item['lat'] as num).toDouble(),
      (item['lng'] as num).toDouble(),
    );
    final mins = GeometryUtils.calculateEtaMinutes(km);
    return '${km.toStringAsFixed(1)} km • ~$mins mins';
  }

  List<Map<String, dynamic>> get _filteredFacilities {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _facilities.where((item) {
      final matchesCategory = _selectedCategory == 'All' ||
          item['category'] == _selectedCategory;
      final matchesQuery = query.isEmpty ||
          item['name'].toString().toLowerCase().contains(query) ||
          item['address'].toString().toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
    filtered.sort((a, b) {
      final da = GeometryUtils.calculateDistanceKm(
        widget.currentLat,
        widget.currentLng,
        (a['lat'] as num).toDouble(),
        (a['lng'] as num).toDouble(),
      );
      final db = GeometryUtils.calculateDistanceKm(
        widget.currentLat,
        widget.currentLng,
        (b['lat'] as num).toDouble(),
        (b['lng'] as num).toDouble(),
      );
      return da.compareTo(db);
    });
    return filtered;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: AppColors.chassisText, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search area, garage, tire repair, fuel...',
                  prefixIcon: Icon(Icons.search, color: AppColors.slateMuted),
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 38,
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
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.caliperCrimson
                            : AppColors.surfaceTint,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.caliperCrimson
                              : AppColors.slateBorder,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color:
                              isSelected ? Colors.white : AppColors.chassisText,
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
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
              child: _filteredFacilities.isEmpty
                  ? Center(
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
                            'No roadside facilities match your search',
                            style: TextStyle(
                              color: AppColors.slateMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      itemCount: _filteredFacilities.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final item = _filteredFacilities[idx];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.cardWhite,
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
                                      item['icon'] as IconData,
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
                                          item['name'] as String,
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
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item['address'] as String,
                                style: const TextStyle(
                                  color: AppColors.slateMuted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        HapticFeedback.lightImpact();
                                        final phone =
                                            item['phone'] as String? ?? '999';
                                        final ok =
                                            await PhoneUtils.launchCall(phone);
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
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        widget.onFacilitySelected?.call(
                                          item['name'] as String,
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
