import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class WalletEditorSheet extends StatefulWidget {
  final List<Map<String, dynamic>> wallets;
  final Function(List<Map<String, dynamic>> updatedWallets) onWalletsChanged;

  const WalletEditorSheet({
    super.key,
    required this.wallets,
    required this.onWalletsChanged,
  });

  @override
  State<WalletEditorSheet> createState() => _WalletEditorSheetState();
}

class _WalletEditorSheetState extends State<WalletEditorSheet> {
  late List<Map<String, dynamic>> _currentWallets;
  final TextEditingController _numberController = TextEditingController();
  String _newProvider = 'bKash';

  final List<String> _providers = ['bKash', 'Nagad', 'Rocket'];

  @override
  void initState() {
    super.initState();
    _currentWallets = List.from(widget.wallets);
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  void _selectPrimary(int index) {
    setState(() {
      for (int i = 0; i < _currentWallets.length; i++) {
        _currentWallets[i]['isPrimary'] = (i == index);
      }
    });
    widget.onWalletsChanged(_currentWallets);
  }

  void _addWallet() {
    final num = _numberController.text.trim();
    if (num.length >= 11) {
      setState(() {
        _currentWallets.add({
          'provider': _newProvider,
          'number': num,
          'isPrimary': _currentWallets.isEmpty,
        });
      });
      _numberController.clear();
      widget.onWalletsChanged(_currentWallets);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: const BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const Text(
                'Payment & MFS Wallets',
                style: TextStyle(
                  color: AppColors.chassisText,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select primary wallet for instant rescue fee pre-authorizations',
                style: TextStyle(color: AppColors.slateMuted, fontSize: 11),
              ),
              const SizedBox(height: 16),

              // Saved Wallets List
              ..._currentWallets.asMap().entries.map((entry) {
                final idx = entry.key;
                final wallet = entry.value;
                final isPrimary = wallet['isPrimary'] == true;
                final provider = wallet['provider'] as String;

                Color tagColor = provider == 'bKash'
                    ? const Color(0xFFE2136E)
                    : (provider == 'Nagad' ? const Color(0xFFF7941D) : const Color(0xFF8B2C84));

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isPrimary ? const Color(0xFFF8FAFC) : AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPrimary ? AppColors.caliperCrimson : AppColors.slateBorder,
                      width: isPrimary ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: tagColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                provider.substring(0, 2),
                                style: TextStyle(
                                  color: tagColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$provider (${wallet['number']})',
                                style: const TextStyle(
                                  color: AppColors.chassisText,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                isPrimary ? 'Primary authorization' : 'Tap to set primary',
                                style: TextStyle(
                                  color: isPrimary ? AppColors.emeraldGps : AppColors.slateMuted,
                                  fontSize: 9.5,
                                  fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(
                          isPrimary ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: isPrimary ? AppColors.caliperCrimson : AppColors.slateBorder,
                          size: 20,
                        ),
                        onPressed: () => _selectPrimary(idx),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 16),
              const Divider(color: AppColors.slateBorder, height: 1),
              const SizedBox(height: 14),

              const Text(
                'ADD NEW WALLET',
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  DropdownButton<String>(
                    value: _newProvider,
                    underline: const SizedBox(),
                    items: _providers.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _newProvider = val);
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _numberController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(
                        color: AppColors.chassisText,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        hintText: '01XXXXXXXXX',
                        filled: true,
                        fillColor: AppColors.porcelainBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.slateBorder),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addWallet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.chassisText,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Add', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}