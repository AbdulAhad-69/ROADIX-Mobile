import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import 'brand_logo.dart';

class WalletEditorSheet extends StatefulWidget {
  final List<Map<String, dynamic>> wallets;
  final Function(List<Map<String, dynamic>> updatedWallets)? onWalletsChanged;
  final Future<void> Function(String provider, String number)? onAddWallet;
  final Future<void> Function(String walletId)? onDeleteWallet;
  final Future<void> Function(String walletId)? onSetPrimaryWallet;

  const WalletEditorSheet({
    super.key,
    required this.wallets,
    this.onWalletsChanged,
    this.onAddWallet,
    this.onDeleteWallet,
    this.onSetPrimaryWallet,
  });

  @override
  State<WalletEditorSheet> createState() => _WalletEditorSheetState();
}

class _WalletEditorSheetState extends State<WalletEditorSheet> {
  late List<Map<String, dynamic>> _currentWallets;
  final TextEditingController _numberController = TextEditingController();
  String _newProvider = 'bKash';
  String? _errorMessage;
  bool _isAdding = false;

  final List<String> _providers = [
    'bKash',
    'Nagad',
    'Rocket',
    'Upay',
    'NexusPay',
    'Ucash',
  ];

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

  Future<void> _selectPrimary(int index) async {
    HapticFeedback.selectionClick();
    final selectedId = _currentWallets[index]['id']?.toString();
    final previousStates = _currentWallets.map((w) => w['isPrimary']).toList();
    setState(() {
      for (int i = 0; i < _currentWallets.length; i++) {
        _currentWallets[i]['isPrimary'] = (i == index);
      }
      _errorMessage = null;
    });

    try {
      if (widget.onSetPrimaryWallet != null && selectedId != null) {
        await widget.onSetPrimaryWallet!(selectedId);
      } else {
        widget.onWalletsChanged?.call(_currentWallets);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < _currentWallets.length; i++) {
          _currentWallets[i]['isPrimary'] = previousStates[i];
        }
        _errorMessage = 'Could not update primary wallet: $e';
      });
    }
  }

  Future<void> _deleteWallet(int index) async {
    HapticFeedback.mediumImpact();
    final wallet = _currentWallets[index];
    final walletId = wallet['id']?.toString();

    setState(() {
      _currentWallets.removeAt(index);
      _errorMessage = null;
    });

    try {
      if (widget.onDeleteWallet != null && walletId != null) {
        await widget.onDeleteWallet!(walletId);
      } else {
        widget.onWalletsChanged?.call(_currentWallets);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currentWallets.insert(index, wallet);
        _errorMessage = 'Could not remove wallet: $e';
      });
    }
  }

  Future<void> _addWallet() async {
    final num = _numberController.text.trim();
    if (num.length < 11) {
      setState(() {
        _errorMessage =
            'Please enter an 11-digit mobile wallet number (e.g. 017XXXXXXXX)';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _isAdding = true;
    });

    HapticFeedback.lightImpact();
    try {
      if (widget.onAddWallet != null) {
        await widget.onAddWallet!(_newProvider, num);
        if (!mounted) return;
        setState(() {
          _currentWallets.add({
            'provider': _newProvider,
            'number': num,
            'isPrimary': _currentWallets.isEmpty,
          });
          _isAdding = false;
        });
      } else {
        setState(() {
          _currentWallets.add({
            'provider': _newProvider,
            'number': num,
            'isPrimary': _currentWallets.isEmpty,
          });
          _isAdding = false;
        });
        widget.onWalletsChanged?.call(_currentWallets);
      }
      _numberController.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAdding = false;
        _errorMessage = 'Could not link wallet: $e';
      });
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
                'Select primary mobile wallet for emergency service pre-authorizations',
                style: TextStyle(color: AppColors.slateMuted, fontSize: 11),
              ),
              const SizedBox(height: 16),

              // Saved Wallets List
              if (_currentWallets.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.porcelainBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.slateBorder),
                  ),
                  child: const Center(
                    child: Text(
                      'No mobile wallets linked yet.',
                      style: TextStyle(color: AppColors.slateMuted, fontSize: 12),
                    ),
                  ),
                )
              else
                ..._currentWallets.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final wallet = entry.value;
                  final isPrimary = wallet['isPrimary'] == true;
                  final provider = wallet['provider'] as String? ?? 'bKash';

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
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(2),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              BrandLogo(brand: provider, size: 34),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$provider (${wallet['number']})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.chassisText,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      isPrimary ? 'Primary authorization' : 'Tap radio to set primary',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isPrimary ? AppColors.emeraldGps : AppColors.slateMuted,
                                        fontSize: 9.5,
                                        fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isPrimary)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.slateMuted),
                                onPressed: () => _deleteWallet(idx),
                              ),
                            IconButton(
                              icon: Icon(
                                isPrimary ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: isPrimary ? AppColors.caliperCrimson : AppColors.slateBorder,
                                size: 22,
                              ),
                              onPressed: () => _selectPrimary(idx),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 16),
              const Divider(color: AppColors.slateBorder, height: 1),
              const SizedBox(height: 14),

              const Text(
                'LINK NEW MOBILE WALLET',
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),

              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.caliperCrimson, fontSize: 11),
                ),
                const SizedBox(height: 6),
              ],

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.porcelainBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.slateBorder),
                    ),
                    child: DropdownButton<String>(
                      value: _newProvider,
                      underline: const SizedBox(),
                      items: _providers.map((p) => DropdownMenuItem(
                        value: p,
                        child: Row(
                          children: [
                            BrandLogo(brand: p, size: 16),
                            const SizedBox(width: 6),
                            Text(p, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _newProvider = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _numberController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(
                        color: AppColors.chassisText,
                        fontSize: 13,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: '01XXXXXXXXX',
                        hintStyle: const TextStyle(color: AppColors.slateMuted, fontSize: 12),
                        filled: true,
                        fillColor: AppColors.porcelainBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.slateBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.slateBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.caliperCrimson),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _isAdding ? null : _addWallet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.caliperCrimson,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: _isAdding
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Add', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
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
