import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/navigation_controller.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../widgets/app_bottom_nav_bar.dart';
import 'history_screen.dart';
import 'scan_screen.dart';
import 'welcome_screen.dart';

/// 1:1 Replica of Stitch "settings" screen (History And Settings)
/// Features: Sunny GOLD TIER profile card, Active Trolley #CR-408 live connected card with Release,
/// Smart Trolley & Hardware switches, Shopping Preferences toggles, Account & Security navigation,
/// Telemetry OS metadata, and Log Out action.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoPair = true;
  bool _scannerSound = true;
  bool _calibrationAlerts = false;
  bool _digitalBill = true;
  bool _proximityAlerts = true;
  bool _isTestingServer = false;

  void _showServerConfigDialog(BuildContext context, CartProvider cart) {
    final hostCtrl = TextEditingController(text: cart.serverHost);
    final portCtrl = TextEditingController(text: cart.serverPort.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Central Server Config', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Laptop Wi-Fi IPv4 Address:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 4),
            TextField(
              controller: hostCtrl,
              decoration: const InputDecoration(
                hintText: 'e.g. 10.138.30.169',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            const Text('Port (Default 8000):', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 4),
            TextField(
              controller: portCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '8000',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            onPressed: () {
              final newHost = hostCtrl.text.trim();
              final newPort = int.tryParse(portCtrl.text.trim()) ?? 8000;
              if (newHost.isNotEmpty) {
                cart.updateServerConfig(host: newHost, port: newPort);
              }
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Central Server updated to http://$newHost:$newPort')),
              );
            },
            child: const Text('Save & Apply'),
          ),
        ],
      ),
    );
  }

  Future<void> _testServerConnection(BuildContext context, CartProvider cart) async {
    setState(() => _isTestingServer = true);
    final client = ApiClient(host: cart.serverHost, port: cart.serverPort, isMockMode: false);
    final status = await client.checkStatus();
    setState(() => _isTestingServer = false);

    if (!context.mounted) return;

    if (status != null && status['status'] == 'healthy') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Central Server (${cart.serverHost}:${cart.serverPort}) is ONLINE!'),
          backgroundColor: const Color(0xFF00AB76),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not reach Central Server at http://${cart.serverHost}:${cart.serverPort}'),
          backgroundColor: AppTheme.hazardError,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final auth = context.read<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF0F172A)),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.read<NavigationController>().goToHome();
            }
          },
        ),
        title: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shopping_cart, color: AppTheme.primary, size: 18),
                const SizedBox(width: 4),
                const Text(
                  'e-Cart',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const Text(
              'History And Settings',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 17),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Profile Overview Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: NetworkImage(
                            'https://lh3.googleusercontent.com/aida-public/AB6AXuCv2lf-uTDLRwD38iDrMIfdWl3KVTw0_rn7laMNKQGZoeaHx9Km1hJFWCmwY-FaDrRFtDZ1Q8Yyz06emiGUbFc4yNKjK_4UJRFtDD6NJxcVdvnGH-BAZjzerkeoQShDviuHaKKxAjlOEM2nfGkqdtDs0uqhTFy0F_61-KeFyjhE3uXkNsOr83I_nqUOHDqF3_M6B8zSSnvWI1tYUFskGJjowxTMukL2Eh0XFtn82bsLD-w9gLKVpGQMgQ',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.verified, color: Colors.white, size: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Sunny',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEAD8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'GOLD TIER',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF7D2D00),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '+91 98765 43210 • D-Mart Club',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: const [
                          Icon(Icons.stars, color: Color(0xFF006C49), size: 14),
                          SizedBox(width: 4),
                          Text(
                            '2,450 SuperPoints Available',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF006C49),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFEFF4FF),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile Editor opened')),
                    );
                  },
                  child: const Text(
                    'Edit',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.primary),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Active Trolley Live Status Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFDAE2FD),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.shopping_cart_checkout, color: AppTheme.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Trolley ${cart.cartId ?? "#CR-408"}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF131B2E),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF00AB76),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Connected • Bay 3, HSR Layout',
                          style: TextStyle(fontSize: 11, color: Color(0xFF5C647A), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primary,
                    elevation: 1,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    cart.clearCart();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Trolley Released successfully')),
                    );
                  },
                  child: const Text(
                    'Release',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Central Server & Connectivity
          _buildSectionHeader(Icons.wifi_tethering, 'Central Server & Wi-Fi Connectivity'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Central Server URL',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'http://${cart.serverHost}:${cart.serverPort}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEFF4FF),
                        foregroundColor: AppTheme.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _showServerConfigDialog(context, cart),
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('Edit IP', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const Divider(height: 20, color: Color(0xFFF1F5F9)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Offline Mock Mode',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Disable to use real Wi-Fi Central Server & Pi',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    Switch(
                      value: cart.isMockMode,
                      activeThumbColor: Colors.white,
                      activeTrackColor: AppTheme.primary,
                      onChanged: (val) {
                        cart.updateServerConfig(mockMode: val);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(val ? 'Mock Mode Enabled' : 'Mock Mode Disabled. Using real Central Server!'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const Divider(height: 20, color: Color(0xFFF1F5F9)),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: _isTestingServer ? null : () => _testServerConnection(context, cart),
                    icon: _isTestingServer
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.network_check, size: 16, color: Color(0xFF00AB76)),
                    label: Text(
                      _isTestingServer ? 'Checking Connectivity...' : 'Ping Central Server (/api/status)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Section 1: SMART TROLLEY & HARDWARE
          _buildSectionHeader(Icons.memory, 'Smart Trolley & Hardware'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildSwitchTile(
                  icon: Icons.bluetooth_searching,
                  title: 'Auto-Pair Nearest Cart',
                  subtitle: 'Connect within 1.5m of trolley handle',
                  value: _autoPair,
                  onChanged: (val) => setState(() => _autoPair = val),
                ),
                const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                _buildSwitchTile(
                  icon: Icons.volume_up,
                  title: 'Barcode Scanner Sound',
                  subtitle: 'Audio chime on successful item capture',
                  value: _scannerSound,
                  onChanged: (val) => setState(() => _scannerSound = val),
                ),
                const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                _buildSwitchTile(
                  icon: Icons.scale,
                  title: 'Auto-Weigh Calibration Alerts',
                  subtitle: 'Haptic pulse when tray balance shifts >5g',
                  value: _calibrationAlerts,
                  onChanged: (val) => setState(() => _calibrationAlerts = val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Section 2: SHOPPING PREFERENCES
          _buildSectionHeader(Icons.tune, 'Shopping Preferences'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildSwitchTile(
                  icon: Icons.receipt_long,
                  title: 'Default to Digital Live Bill',
                  subtitle: 'Paperless invoice via WhatsApp & SMS',
                  value: _digitalBill,
                  onChanged: (val) => setState(() => _digitalBill = val),
                ),
                const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                _buildSwitchTile(
                  icon: Icons.near_me,
                  title: 'Aisle Proximity Alerts',
                  subtitle: 'Vibrate cart handle for saved grocery list',
                  value: _proximityAlerts,
                  onChanged: (val) => setState(() => _proximityAlerts = val),
                ),
                const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                _buildNavigationTile(
                  icon: Icons.eco,
                  title: 'Dietary & Allergen Warnings',
                  subtitle: 'Gluten, peanut & high sodium scans',
                  badge: '2 Active',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Allergen scanner active: Peanut, Gluten')),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Section 3: ACCOUNT & SECURITY
          _buildSectionHeader(Icons.manage_accounts, 'Account & Security'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildNavigationTile(
                  icon: Icons.account_balance_wallet,
                  title: 'Payment Methods',
                  subtitle: 'UPI, RuPay ••8920, DMart Wallet',
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                _buildNavigationTile(
                  icon: Icons.history,
                  title: 'Order History & E-Receipts',
                  subtitle: '18 store trips recorded with itemized bills',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                _buildNavigationTile(
                  icon: Icons.light_mode,
                  title: 'App Appearance',
                  subtitle: 'Sunburst high-visibility theme',
                  badge: 'Light Mode',
                  onTap: () {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Store & Device Telemetry Metadata
          Center(
            child: Column(
              children: const [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hub, size: 15, color: Color(0xFF006C49)),
                    SizedBox(width: 4),
                    Text(
                      'e-Cart OS v2.4.1 (Build 8904)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF565E74)),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  'BLE 5.3 Ready • D-Mart Hypermarket HSR Layout',
                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Destructive Logout Action
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFDAD6),
                foregroundColor: const Color(0xFF93000A),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                auth.logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Log Out of Smart Trolley',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        onScanPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ScanScreen()),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF565E74)),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF565E74),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF565E74), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: AppTheme.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFCBD5E1),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF565E74), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDAE2FD),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF131B2E)),
                ),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8), size: 20),
          ],
        ),
      ),
    );
  }
}
