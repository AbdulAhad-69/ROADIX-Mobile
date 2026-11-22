import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../src/core/utils/phone_utils.dart';
import '../theme/app_colors.dart';

class SearchBottomSheet extends StatefulWidget {
  final Function(String facilityName, double lat, double lng)? onFacilitySelected;

  const SearchBottomSheet({super.key, this.onFacilitySelected});

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
      'distance': '0.8 km • ~3 mins',
      'address': 'House 14, Sector 7, Jashimuddin Ave, Uttara',
      'phone': '+880 1711-234567',
      'icon': Icons.album_outlined,
      'lat': 23.8732,
      'lng': 90.3980,
    },
    {
      'name': 'Padma Oil & CNG Filling Station',
      'category': 'Fuel & CNG',
      'distance': '1.4 km • ~6 mins',
      'address': 'Airport Road, Kawla, Dhaka',
      'phone': '+880 1819-345678',
      'icon': Icons.local_gas_station_outlined,
      'lat': 23.8512,
      'lng': 90.4078,
    },
    {
      'name': 'Navana Toyota Certified Workshop',
      'category': 'Authorized Garages',
      'distance': '2.1 km • ~8 mins',
      'address': 'Plot 4, Sector 9, Sonargaon Janapath, Uttara',
      'phone': '+880 1912-987654',
      'icon': Icons.car_repair,
      'lat': 23.8795,
      'lng': 90.3842,
    },
    {
      'name': 'Highway Police Outpost (Abdullahpur)',
      'category': 'Highway Police',
      'distance': '2.9 km • ~11 mins',
      'address': 'Abdullahpur Bus Stand, Dhaka-Mymensingh Hwy',
      'phone': '999',
      'icon': Icons.local_police_outlined,
      'lat': 23.8967,
      'lng': 90.3883,
    },
    {
      'name': 'Mirpur Battery & Starter Clinic',
      'category': '24/7 Tire Repair',
      'distance': '4.5 km • ~18 mins',
      'address': 'Section 10, Mirpur Roundabout',
      'phone': '+880 1622-445566',
      'icon': Icons.battery_charging_full,
      'lat': 23.8069,
      'lng': 90.3687,
    },
  ];

  List<Map<String, dynamic>> get _filteredFacilities {
    final query = _searchController.text.trim().toLowerCase();
    return _facilities.where((item) {
      final matchesCategory = _selectedCategory == 'All' || item['category'] == _selectedCategory;
      final matchesQuery = query.isEmpty ||
          item['name'].toString().toLowerCase().contains(query) ||
          item['address'].toString().toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
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
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle Bar
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
            const SizedBox(height: 14),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Flexible(
                    child: Text(
                      'Emergency Facilities',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.chassisText,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'DHAKA NORTH REGION',
                    style: TextStyle(
                      color: AppColors.slateMuted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Search Input Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: AppColors.chassisText, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search garages, fuel depots, police posts...',
                  hintStyle: const TextStyle(color: AppColors.slateMuted, fontSize: 12),
                  prefixIcon: const Icon(Icons.search, color: AppColors.slateMuted, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16, color: AppColors.slateMuted),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.porcelainBg,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.slateBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.slateBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.caliperCrimson, width: 1.5),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Filter Chips
            SizedBox(
              height: 34,
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
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.caliperCrimson : AppColors.porcelainBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.caliperCrimson : AppColors.slateBorder,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.chassisText,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),
            const Divider(color: AppColors.slateBorder, height: 1),

            // Facilities List
            Expanded(
              child: _filteredFacilities.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.search_off, size: 38, color: AppColors.slateMuted),
                          SizedBox(height: 8),
                          Text(
                            'No roadside facilities match your search',
                            style: TextStyle(color: AppColors.slateMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      itemCount: _filteredFacilities.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final item = _filteredFacilities[idx];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.cardWhite,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.slateBorder),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.chassisText.withAlpha(4),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppColors.crimsonLight,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      item['icon'] as IconData,
                                      color: AppColors.caliperCrimson,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['name'] as String,
                                          style: const TextStyle(
                                            color: AppColors.chassisText,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item['distance'] as String,
                                          style: const TextStyle(
                                            color: AppColors.emeraldGps,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
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
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        HapticFeedback.lightImpact();
                                        final phone = item['phone'] as String? ?? '999';
                                        final ok = await PhoneUtils.launchCall(phone);
                                        if (!ok && context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Could not open phone dialer for $phone.'),
                                              backgroundColor: AppColors.caliperCrimson,
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.call, size: 14, color: AppColors.chassisText),
                                      label: const Text(
                                        'Call',
                                        style: TextStyle(
                                          color: AppColors.chassisText,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: AppColors.slateBorder),
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                      ),
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
                                          item['lat'] as double,
                                          item['lng'] as double,
                                        );
                                      },
                                      icon: const Icon(Icons.near_me, size: 14, color: Colors.white),
                                      label: const Text(
                                        'Set Breakdown Spot',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.caliperCrimson,
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                      ),
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