// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// ============================================================
// Storm Café — Menu Page (Magazine Grid Redesign)
// Design  : Concept 2 — Magazine Grid  (semi-transparent cards
//           over the real background image)
// Arch    : Clean separation — each section is its own const
//           widget class with RepaintBoundary isolation.
// Features: Entry overlay · Waiter login · Search bar ·
//           Category carousel (old-style PageView) ·
//           Magazine grid product list · Basket row ·
//           Order tracker · FAB quick-menu · Call waiter ·
//           Request bill · Change table · Particle burst ·
//           Sizes dialog · Waiter terminal (POS + orders)
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui';
import 'dart:math' as math;
import 'dart:js' as js;
import 'dart:html' as html;
import 'theme.dart';
import 'services/api_service.dart';
import 'firebase_options.dart';

// ─────────────────────────────────────────────
// Assets
// ─────────────────────────────────────────────
const String localBackgroundImage = 'assets/images/storm_bg.jpg';
const String localLogoImage = 'assets/images/storm_logo.png';

// ─────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const NeonCyberCafeApp());
}

class NeonCyberCafeApp extends StatelessWidget {
  const NeonCyberCafeApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Storm Café | Premium Experience',
      theme: CafeTheme.themeData,
      home: const MenuPage(),
    );
  }
}

Widget buildStormLogo({double size = 60, Color? color}) {
  return Image.asset(
    localLogoImage,
    width: size,
    height: size,
    color: color,
    fit: BoxFit.contain,
    errorBuilder: (_, __, ___) =>
        Icon(Icons.restaurant_menu, size: size, color: CafeTheme.accent),
  );
}

// ─────────────────────────────────────────────
// Background — isolated in RepaintBoundary so it
// NEVER repaints when menu state changes.
// ─────────────────────────────────────────────
class _MenuBackground extends StatelessWidget {
  const _MenuBackground();
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: RepaintBoundary(
        child: Stack(
          children: [
            Image.asset(
              localBackgroundImage,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              cacheWidth: 1920,
              errorBuilder: (_, __, ___) =>
                  Container(color: CafeTheme.deepBrown),
            ),
            // Dark overlay — keeps readability while showing bg
            Container(color: CafeTheme.deepBrown.withValues(alpha: 0.82)),
            // Subtle radial glow — brand warmth
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.5),
                  radius: 1.4,
                  colors: [
                    CafeTheme.primaryBrown.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Menu Page — State
// ─────────────────────────────────────────────
class MenuPage extends StatefulWidget {
  const MenuPage({super.key});
  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> with TickerProviderStateMixin {
  // ── state ──────────────────────────────────
  String? currentCat;
  final TextEditingController _catSearchCtrl = TextEditingController();
  final TextEditingController _globalSearchCtrl = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _nameEntryController = TextEditingController();
  final TextEditingController _tableEntryController = TextEditingController();

  List<Map<String, dynamic>> basket = [];
  String? registeredName;
  String? currentTable;

  bool _isEntryComplete = false;
  bool _hasSavedName = false;
  bool _isWaiterAlertActive = false;
  bool _showQuickMenu = false;

  // ── animation controllers ──────────────────
  late AnimationController _glowController;
  late AnimationController _fabPulseController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _fabPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _checkSavedData();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _fabPulseController.dispose();
    _catSearchCtrl.dispose();
    _globalSearchCtrl.dispose();
    _noteController.dispose();
    _nameEntryController.dispose();
    _tableEntryController.dispose();
    super.dispose();
  }

  // ── helpers ────────────────────────────────
  void _checkSavedData() {
    if (kIsWeb) {
      final saved = html.window.localStorage['customer_name'];
      if (saved != null && saved.isNotEmpty) {
        setState(() {
          registeredName = saved;
          _hasSavedName = true;
        });
      }
    }
  }

  void _playSound(String url, {double volume = 1.0}) {
    if (!kIsWeb) return;
    final v = volume.clamp(0.0, 1.0);
    js.context.callMethod('eval', [
      "(function(){var a=new Audio('$url');a.volume=$v;a.play();})()",
    ]);
  }

  void _playWaiterBell() => _playSound('https://files.catbox.moe/y77se9.mp3');

  void _showStatusSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 15,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 10,
      ),
    );
  }

  void _initStatusListeners() {}

  // ── entry / login ──────────────────────────
  void _validateAndStart() {
    final name = _hasSavedName
        ? registeredName!
        : _nameEntryController.text.trim();
    if (name.isEmpty) {
      _showStatusSnackBar('يرجى إدخال الاسم', Colors.redAccent);
      return;
    }
    if (_tableEntryController.text.trim().isEmpty) {
      _showStatusSnackBar('يرجى تحديد رقم الطاولة', Colors.redAccent);
      return;
    }
    currentTable = _tableEntryController.text.trim();
    if (kIsWeb) html.window.localStorage['customer_name'] = name;
    setState(() {
      registeredName = name;
      _isEntryComplete = true;
    });
    _initStatusListeners();
  }

  void _showWaiterLogin() {
    final passwordCtrl = TextEditingController();
    bool isLoading = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDS) => AlertDialog(
          backgroundColor: const Color(0xFF2E1F10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: CafeTheme.primaryBrown, width: 1.5),
          ),
          title: const Text(
            'دخول الويتر 🤵',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: CafeTheme.secondaryBrown,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: passwordCtrl,
            obscureText: true,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              hintText: 'أدخل كلمة السر',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(fontSize: 16)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: CafeTheme.primaryBrown,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: isLoading
                  ? null
                  : () async {
                      setDS(() => isLoading = true);
                      try {
                        await apiService.loginWaiter(passwordCtrl.text);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (ctx.mounted)
                          Navigator.push(
                            ctx,
                            MaterialPageRoute(
                              builder: (_) => const WaiterTerminal(),
                            ),
                          );
                      } on ApiException catch (e) {
                        setDS(() => isLoading = false);
                        if (mounted)
                          _showStatusSnackBar(
                            e.statusCode == 401
                                ? 'كلمة السر خاطئة!'
                                : 'تعذر التحقق',
                            Colors.red,
                          );
                      } catch (_) {
                        setDS(() => isLoading = false);
                        if (mounted)
                          _showStatusSnackBar(
                            'تعذر الاتصال بالخادم',
                            Colors.red,
                          );
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'دخول',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── categories sheet ───────────────────────
  void _showCategoriesSheet(List<QueryDocumentSnapshot> cats) {
    _catSearchCtrl.clear();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final sw = MediaQuery.of(ctx).size.width;
        final crossAxis = sw < 600 ? 2 : 4;
        final ratio = sw < 400
            ? 2.0
            : sw < 600
            ? 2.3
            : 3.0;
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final q = _catSearchCtrl.text.trim();
            final filtered = q.isEmpty
                ? cats
                : cats
                      .where((d) => (d['name'] ?? '').toString().contains(q))
                      .toList();
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  height: MediaQuery.of(ctx).size.height * 0.75,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E1F10).withValues(alpha: 0.90),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    border: const Border(
                      top: BorderSide(
                        color: CafeTheme.primaryBrown,
                        width: 1.5,
                      ),
                      left: BorderSide(
                        color: CafeTheme.primaryBrown,
                        width: 0.5,
                      ),
                      right: BorderSide(
                        color: CafeTheme.primaryBrown,
                        width: 0.5,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: CafeTheme.primaryBrown.withValues(alpha: 0.4),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(ctx).viewInsets.bottom,
                      left: 20,
                      right: 20,
                      top: 15,
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 5,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                CafeTheme.primaryBrown,
                                CafeTheme.secondaryBrown,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ShaderMask(
                          shaderCallback: (b) => const LinearGradient(
                            colors: [
                              CafeTheme.primaryBrown,
                              CafeTheme.secondaryBrown,
                            ],
                          ).createShader(b),
                          child: const Text(
                            'اختر القسم',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: CafeTheme.secondaryBrown.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                          child: TextField(
                            controller: _catSearchCtrl,
                            onChanged: (_) => setSheet(() {}),
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'ابحث عن قسم...',
                              hintStyle: TextStyle(color: Colors.white38),
                              prefixIcon: Icon(
                                Icons.search,
                                color: CafeTheme.secondaryBrown,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: filtered.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxis,
                                  childAspectRatio: ratio,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                            itemBuilder: (_, i) {
                              final name = (filtered[i]['name'] ?? '')
                                  .toString();
                              final sel = currentCat == name;
                              return GestureDetector(
                                onTap: () {
                                  setState(() => currentCat = name);
                                  Navigator.pop(ctx);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  decoration: BoxDecoration(
                                    gradient: sel
                                        ? const LinearGradient(
                                            colors: [
                                              CafeTheme.primaryBrown,
                                              CafeTheme.secondaryBrown,
                                            ],
                                          )
                                        : null,
                                    color: sel
                                        ? null
                                        : Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: sel
                                          ? CafeTheme.primaryBrown
                                          : CafeTheme.primaryBrown.withValues(
                                              alpha: 0.25,
                                            ),
                                      width: sel ? 1.5 : 1,
                                    ),
                                    boxShadow: sel
                                        ? [
                                            BoxShadow(
                                              color: CafeTheme.primaryBrown
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 15,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      name,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: sel
                                            ? Colors.black
                                            : Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: sw < 400 ? 16 : 15,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── dialogs ────────────────────────────────
  void _showAddDialog(Map<String, dynamic> item) {
    _noteController.clear();
    final sizes = item['sizes'] as List<dynamic>?;
    Map<String, dynamic>? selectedSize = sizes?.isNotEmpty == true
        ? sizes!.first
        : null;
    double currentPrice = selectedSize != null
        ? (selectedSize['price'] as num).toDouble()
        : (item['price'] as num).toDouble();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDS) => AlertDialog(
          backgroundColor: const Color(0xFF2E1F10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(
              color: CafeTheme.primaryBrown.withValues(alpha: 0.7),
              width: 1.5,
            ),
          ),
          title: Text(
            'تخصيص ${item['name']}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: CafeTheme.secondaryBrown,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (sizes != null && sizes.isNotEmpty) ...[
                const Text(
                  'اختر الحجم:',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.end,
                  children: sizes.map((s) {
                    final isSel = selectedSize == s;
                    return ChoiceChip(
                      label: Text('${s['name']} - ${s['price']} ج.م'),
                      selected: isSel,
                      selectedColor: CafeTheme.primaryBrown,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      labelStyle: TextStyle(
                        color: isSel ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSel
                              ? CafeTheme.primaryBrown
                              : Colors.transparent,
                        ),
                      ),
                      onSelected: (v) {
                        if (v)
                          setDS(() {
                            selectedSize = s;
                            currentPrice = (s['price'] as num).toDouble();
                          });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],
              TextField(
                controller: _noteController,
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'أي إضافات تحب نجهزها لك؟',
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: CafeTheme.primaryBrown.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.only(
            bottom: 20,
            right: 20,
            left: 20,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(fontSize: 16)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: CafeTheme.primaryBrown,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                setState(() {
                  final note = _noteController.text.isEmpty
                      ? 'بدون إضافات'
                      : _noteController.text;
                  String iName = item['name'];
                  if (selectedSize != null)
                    iName += ' (${selectedSize!['name']})';
                  final idx = basket.indexWhere(
                    (e) =>
                        e['name'] == iName &&
                        e['note'] == note &&
                        e['price'] == currentPrice,
                  );
                  if (idx != -1) {
                    basket[idx]['quantity']++;
                  } else {
                    basket.add({
                      'name': iName,
                      'price': currentPrice,
                      'image_url': item['image_url'],
                      'note': note,
                      'quantity': 1,
                    });
                  }
                });
                Navigator.pop(ctx);
                _showStatusSnackBar('تمت الإضافة ✨', CafeTheme.primaryBrown);
              },
              child: const Text(
                'إضافة',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _changeTableDialog() {
    _tableEntryController.text = currentTable ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2E1F10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: CafeTheme.secondaryBrown, width: 1.5),
        ),
        title: const Text(
          'تغيير الطاولة 🪑',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: CafeTheme.secondaryBrown,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: _tableEntryController,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: 'رقم الطاولة الجديد',
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            contentPadding: const EdgeInsets.symmetric(vertical: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CafeTheme.secondaryBrown,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              if (_tableEntryController.text.isNotEmpty) {
                setState(() => currentTable = _tableEntryController.text);
                Navigator.pop(ctx);
                _showStatusSnackBar(
                  'تم تغيير الطاولة إلى ${_tableEntryController.text} 🪑',
                  CafeTheme.secondaryBrown,
                );
              }
            },
            child: const Text(
              'تحديث',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── order actions ──────────────────────────
  void _sendOrder() async {
    if (basket.isEmpty || registeredName == null) return;
    try {
      final itemsWithQty = basket
          .map((e) => {'name': e['name'], 'qty': e['quantity']})
          .toList();
      final total = basket.fold(
        0.0,
        (p, e) => p + (e['price'] as num) * (e['quantity'] as num),
      );
      final note = basket.any((e) => e['note'] != 'بدون إضافات')
          ? basket.firstWhere((e) => e['note'] != 'بدون إضافات')['note']
          : 'بدون إضافات';

      await apiService.createOrder(
        customerName: registeredName!,
        tableNumber: currentTable ?? '?',
        itemsWithQty: itemsWithQty,
        totalPrice: total,
        note: note,
      );

      final lines = basket
          .map((e) => '  • ${e['name']} × ${e['quantity']}')
          .join('\n');
      await apiService.sendTelegramMessage(
        '━━━━━━━━━━━━━━━━━━\n☕ طلب جديد — Storm Café\n━━━━━━━━━━━━━━━━━━\n'
        '👤 العميل : $registeredName\n🪑 الطاولة : $currentTable\n━━━━━━━━━━━━━━━━━━\n'
        '🛒 الطلبات :\n$lines\n━━━━━━━━━━━━━━━━━━\n'
        '📝 ملاحظة : $note\n💰 الإجمالي : ${total.toStringAsFixed(2)} ج.م\n━━━━━━━━━━━━━━━━━━',
      );

      setState(() => basket.clear());
      _showStatusSnackBar('تم إرسال طلبك! 🚀', Colors.greenAccent);
    } catch (_) {
      _showStatusSnackBar('تعذر إرسال الطلب، حاول مرة أخرى', Colors.redAccent);
    }
  }

  void _callWaiter() async {
    if (_isWaiterAlertActive || registeredName == null) return;
    setState(() => _isWaiterAlertActive = true);
    _playWaiterBell();
    try {
      await apiService.callWaiter(
        customerName: registeredName!,
        tableNumber: currentTable ?? '?',
      );
      await apiService.sendTelegramMessage(
        '━━━━━━━━━━━━━━━━━━\n🔔 نداء ويتر — Storm Café\n━━━━━━━━━━━━━━━━━━\n'
        '👤 العميل : $registeredName\n🪑 الطاولة : $currentTable\n━━━━━━━━━━━━━━━━━━\n'
        '⚡ العميل يطلب مساعدة الويتر الآن!',
      );
    } catch (_) {
      setState(() => _isWaiterAlertActive = false);
      _showStatusSnackBar('تعذر إرسال نداء الويتر', Colors.redAccent);
    }
  }

  void _requestBill() async {
    if (registeredName == null) return;
    await apiService.sendTelegramMessage(
      '━━━━━━━━━━━━━━━━━━\n🧾 طلب حساب — Storm Café\n━━━━━━━━━━━━━━━━━━\n'
      '👤 العميل : $registeredName\n🪑 الطاولة : $currentTable\n━━━━━━━━━━━━━━━━━━\n'
      '💳 العميل جاهز للدفع!',
    );
    _showStatusSnackBar(
      'تم طلب الحساب! سيأتي الويتر قريباً 🧾',
      CafeTheme.success,
    );
  }

  // ─────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          children: [
            _buildMainContent(),
            if (!_isEntryComplete) _buildEntryOverlay(),
          ],
        ),
      ),
    );
  }

  // ── entry overlay ──────────────────────────
  Widget _buildEntryOverlay() {
    return Container(
      color: CafeTheme.darkBg.withValues(alpha: 0.96),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(40),
            width: 400,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: CafeTheme.primaryBrown.withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: CafeTheme.primaryBrown.withValues(alpha: 0.2),
                  blurRadius: 50,
                  spreadRadius: 5,
                ),
                BoxShadow(
                  color: CafeTheme.secondaryBrown.withValues(alpha: 0.1),
                  blurRadius: 80,
                  spreadRadius: 15,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildStormLogo(size: 110),
                const SizedBox(height: 15),
                const Text(
                  'storm',
                  style: TextStyle(
                    color: CafeTheme.primaryBrown,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'اطلب وانت في راحتك ⚡',
                  style: TextStyle(color: Colors.white54, fontSize: 15),
                ),
                const SizedBox(height: 35),
                if (!_hasSavedName) ...[
                  _entryField(
                    _nameEntryController,
                    'اسمك الكريم..',
                    Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 18),
                ],
                _entryField(
                  _tableEntryController,
                  'رقم الطاولة..',
                  Icons.table_restaurant_rounded,
                  isNumber: true,
                ),
                const SizedBox(height: 30),
                _buildActionButton(
                  onPressed: _validateAndStart,
                  color: CafeTheme.primaryBrown,
                  child: const Text(
                    'اكتشف القائمة ⚡',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: _showWaiterLogin,
                  icon: const Icon(
                    Icons.lock_person,
                    color: CafeTheme.accent,
                    size: 20,
                  ),
                  label: const Text(
                    'الدخول كويتر',
                    style: TextStyle(
                      color: CafeTheme.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _entryField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: ctrl,
      textAlign: TextAlign.center,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        prefixIcon: Icon(icon, color: CafeTheme.accent, size: 22),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.4),
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required Widget child,
    Color color = CafeTheme.primaryBrown,
  }) {
    return Container(
      width: double.infinity,
      height: 65,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 25,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          elevation: 0,
        ),
        child: child,
      ),
    );
  }

  // ── main content ───────────────────────────
  Widget _buildMainContent() {
    return Stack(
      children: [
        const _MenuBackground(),
        CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            _buildHeader(),
            _buildSearchBar(),
            _buildCategorySectionSliver(),
            SliverToBoxAdapter(child: _buildProductsSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 360)),
          ],
        ),
        _buildBottomActionArea(),
        _buildFloatingActionMenu(),
      ],
    );
  }

  // ── HEADER ─────────────────────────────────
  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 55, 24, 18),
            decoration: BoxDecoration(
              color: CafeTheme.surface.withValues(alpha: 0.75),
              border: const Border(
                bottom: BorderSide(color: CafeTheme.border, width: 1.5),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Dev badge
                _buildDevBadge(),
                // Logo + name centre
                Expanded(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (kIsWeb) html.window.location.reload();
                        },
                        child: buildStormLogo(size: 44),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'storm',
                        style: TextStyle(
                          color: CafeTheme.accent,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                          fontSize: 20,
                        ),
                      ),
                      if (registeredName != null && currentTable != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            'طاولة $currentTable  |  أهلاً، $registeredName',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Right actions: table + waiter call
                Column(
                  children: [
                    _buildTableChip(),
                    const SizedBox(height: 8),
                    _buildWaiterCallChip(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDevBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: CafeTheme.accent.withValues(alpha: 0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.code_rounded, color: CafeTheme.accent, size: 16),
          SizedBox(width: 5),
          Text(
            'Dev',
            style: TextStyle(
              color: CafeTheme.accent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableChip() {
    return GestureDetector(
      onTap: _changeTableDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: CafeTheme.primaryBrown.withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.table_restaurant_rounded,
              color: CafeTheme.primaryBrown,
              size: 18,
            ),
            SizedBox(width: 5),
            Text(
              'الطاولة',
              style: TextStyle(
                color: CafeTheme.primaryBrown,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaiterCallChip() {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (_, __) => GestureDetector(
          onTap: _callWaiter,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: CafeTheme.accent.withValues(
                  alpha: 0.5 + 0.5 * _glowController.value,
                ),
                width: 1.8,
              ),
              boxShadow: _isWaiterAlertActive
                  ? [
                      BoxShadow(
                        color: CafeTheme.accent.withValues(
                          alpha: 0.3 * _glowController.value,
                        ),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isWaiterAlertActive ? 'جاري..' : 'نداء',
                  style: const TextStyle(
                    color: CafeTheme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.notifications_active_rounded,
                  color: CafeTheme.accent,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── SEARCH ─────────────────────────────────
  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                color: CafeTheme.surface.withValues(alpha: 0.80),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: CafeTheme.border, width: 1.5),
              ),
              child: TextField(
                controller: _globalSearchCtrl,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: CafeTheme.textMain, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'ابحث عن منتج أو قسم...',
                  hintStyle: TextStyle(
                    color: CafeTheme.mutedText.withValues(alpha: 0.8),
                    fontSize: 15,
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(
                      Icons.search_rounded,
                      color: CafeTheme.accent,
                      size: 24,
                    ),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── CATEGORY SECTION ───────────────────────
  Widget _buildCategorySectionSliver() {
    return SliverToBoxAdapter(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('categories').snapshots(),
        builder: (_, snap) {
          if (snap.hasError)
            return const SizedBox(
              height: 80,
              child: Center(
                child: Text(
                  'تعذر تحميل الأقسام',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            );
          if (!snap.hasData || snap.data!.docs.isEmpty)
            return const SizedBox(height: 80);

          final cats = snap.data!.docs.toList()
            ..sort((a, b) {
              final ai = (a.data() as Map)['index'] ?? 999;
              final bi = (b.data() as Map)['index'] ?? 999;
              return (ai as num).compareTo(bi as num);
            });

          if (currentCat == null && cats.isNotEmpty) {
            // initialise without setState since we're inside build
            Future.microtask(
              () => setState(() => currentCat = cats.first['name']),
            );
          }

          return Column(
            children: [
              const SizedBox(height: 22),
              // Current-category label row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(
                      Icons.category_rounded,
                      color: CafeTheme.secondaryBrown,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'القسم الحالي',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        currentCat ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // "All categories" button — compact
                    GestureDetector(
                      onTap: () => _showCategoriesSheet(cats),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [CafeTheme.primaryBrown, Color(0xFF7A4D2A)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: CafeTheme.primaryBrown.withValues(
                                alpha: 0.45,
                              ),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.grid_view_rounded,
                              color: Colors.black,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'كل الأقسام',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Carousel
              MagazineCategoryCarousel(
                categories: cats,
                selectedCategory: currentCat,
                onSelect: (name) {
                  if (name == currentCat) return;
                  _playSound(
                    'https://assets.mixkit.co/active_storage/sfx/270/270-preview.mp3',
                    volume: 0.13,
                  );
                  setState(() => currentCat = name);
                },
              ),
              const SizedBox(height: 10),
            ],
          );
        },
      ),
    );
  }

  // ── PRODUCT SECTION ────────────────────────
  Widget _buildProductsSection() {
    if (currentCat == null) return const SizedBox();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('cat', isEqualTo: currentCat)
          .snapshots(),
      builder: (_, snap) {
        if (snap.hasError || !snap.hasData) return const SizedBox();
        var items = snap.data!.docs;
        final q = _globalSearchCtrl.text.trim();
        if (q.isNotEmpty) {
          items = items
              .where((d) => (d['name'] ?? '').toString().contains(q))
              .toList();
        }
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(50),
            child: Center(
              child: Text(
                'لا توجد منتجات في هذا القسم',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ),
          );
        }
        return MagazineProductGrid(
          items: items.map((d) => d.data() as Map<String, dynamic>).toList(),
          categoryName: currentCat ?? '',
          basket: basket,
          onAddItem: _showAddDialog,
          onQuantityChange: (idx, increase) => setState(() {
            if (increase) {
              basket[idx]['quantity']++;
            } else {
              if (basket[idx]['quantity'] > 1)
                basket[idx]['quantity']--;
              else
                basket.removeAt(idx);
            }
          }),
        );
      },
    );
  }

  // ── BOTTOM ACTION AREA ─────────────────────
  Widget _buildBottomActionArea() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D0804).withValues(alpha: 0.88),
              border: const Border(
                top: BorderSide(color: CafeTheme.primaryBrown, width: 1.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: CafeTheme.primaryBrown.withValues(alpha: 0.35),
                  blurRadius: 30,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActiveOrdersTracker(),
                _buildBasketRow(),
                _buildCheckoutBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveOrdersTracker() {
    if (registeredName == null) return const SizedBox();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('customer_name', isEqualTo: registeredName)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox();
        final orders = snap.data!.docs;
        return SizedBox(
          height: 125,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            itemCount: orders.length,
            itemBuilder: (_, i) {
              final data = orders[i].data() as Map<String, dynamic>;
              final status = data['status'] ?? 'قيد الانتظار';
              final sColor = status == 'جاهز'
                  ? Colors.greenAccent
                  : (status == 'جاري التجهيز'
                        ? Colors.orangeAccent
                        : Colors.white54);
              final sIcon = status == 'جاهز'
                  ? Icons.check_circle_rounded
                  : (status == 'جاري التجهيز'
                        ? Icons.local_cafe_rounded
                        : Icons.hourglass_top_rounded);
              return Container(
                width: 165,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: sColor.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: sColor.withValues(alpha: 0.12),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(sIcon, color: sColor, size: 26),
                    const SizedBox(height: 6),
                    Text(
                      status,
                      style: TextStyle(
                        color: sColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    if (data['items_with_qty'] != null)
                      Text(
                        '${(data['items_with_qty'] as List).length} صنف',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBasketRow() {
    if (basket.isEmpty) return const SizedBox();
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(top: 12, left: 20, right: 20),
        itemCount: basket.length,
        itemBuilder: (_, i) => Container(
          width: 165,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: CafeTheme.primaryBrown.withValues(alpha: 0.45),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  basket[i]['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.redAccent,
                      size: 22,
                    ),
                    onPressed: () => setState(() {
                      if (basket[i]['quantity'] > 1)
                        basket[i]['quantity']--;
                      else
                        basket.removeAt(i);
                    }),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      '${basket[i]['quantity']}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: Colors.greenAccent,
                      size: 22,
                    ),
                    onPressed: () => setState(() => basket[i]['quantity']++),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              if (basket[i]['note'] != 'بدون إضافات')
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                  child: Text(
                    '📝 ${basket[i]['note']}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckoutBar() {
    final total = basket.fold(
      0.0,
      (p, e) => p + (e['price'] as num) * (e['quantity'] as num),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'المبلغ الحالي',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${total.toStringAsFixed(2)} ج.م',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: CafeTheme.accent,
                  letterSpacing: 1,
                ),
              ),
              if (basket.isNotEmpty)
                Text(
                  '${basket.length} صنف',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
            ],
          ),
          Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: CafeTheme.primaryBrown.withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: basket.isEmpty ? null : _sendOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CafeTheme.primaryBrown,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'تأكيد الطلب ⚡',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
              ),
              if (basket.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() => basket.clear());
                      _showStatusSnackBar('تم مسح السلة', Colors.redAccent);
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 16,
                    ),
                    label: const Text(
                      'مسح السلة',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── FAB QUICK MENU ─────────────────────────
  Widget _buildFloatingActionMenu() {
    return Positioned(
      bottom: 230,
      left: 20,
      child: Column(
        children: [
          if (_showQuickMenu) ...[
            _fabOption(
              icon: Icons.receipt_long_rounded,
              label: 'الحساب',
              color: CafeTheme.success,
              onTap: () {
                setState(() => _showQuickMenu = false);
                _requestBill();
              },
            ),
            const SizedBox(height: 12),
            _fabOption(
              icon: Icons.help_outline_rounded,
              label: 'مساعدة',
              color: CafeTheme.secondaryBrown,
              onTap: () {
                setState(() => _showQuickMenu = false);
                _showStatusSnackBar(
                  'جاري إرسال طلب المساعدة... 🙏',
                  CafeTheme.secondaryBrown,
                );
              },
            ),
            const SizedBox(height: 12),
            _fabOption(
              icon: Icons.room_service_rounded,
              label: 'نداء ويتر',
              color: CafeTheme.accent,
              onTap: () {
                setState(() => _showQuickMenu = false);
                _callWaiter();
              },
            ),
            const SizedBox(height: 16),
          ],
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _fabPulseController,
              builder: (_, __) => GestureDetector(
                onTap: () => setState(() => _showQuickMenu = !_showQuickMenu),
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        CafeTheme.primaryBrown,
                        CafeTheme.secondaryBrown,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: CafeTheme.primaryBrown.withValues(
                          alpha: 0.5 + 0.3 * _fabPulseController.value,
                        ),
                        blurRadius: 25,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: Icon(
                      _showQuickMenu
                          ? Icons.close_rounded
                          : Icons.support_agent_rounded,
                      key: ValueKey<bool>(_showQuickMenu),
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fabOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.2),
              border: Border.all(
                color: color.withValues(alpha: 0.7),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 14),
              ],
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
// MAGAZINE CATEGORY CAROUSEL
// Horizontal scroll — lighter than PageView with
// 3-D transforms; uses simple ListView for perf.
// ══════════════════════════════════════════════
class MagazineCategoryCarousel extends StatefulWidget {
  final List<QueryDocumentSnapshot> categories;
  final String? selectedCategory;
  final void Function(String) onSelect;

  const MagazineCategoryCarousel({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onSelect,
  });

  @override
  State<MagazineCategoryCarousel> createState() =>
      _MagazineCategoryCarouselState();
}

class _MagazineCategoryCarouselState extends State<MagazineCategoryCarousel> {
  late ScrollController _sc;

  @override
  void initState() {
    super.initState();
    _sc = ScrollController();
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MagazineCategoryCarousel old) {
    super.didUpdateWidget(old);
    if (widget.selectedCategory != old.selectedCategory) {
      final idx = widget.categories.indexWhere(
        (d) => d['name'] == widget.selectedCategory,
      );
      if (idx >= 0 && _sc.hasClients) {
        final target = idx * 96.0; // ~chip width + gap
        _sc.animateTo(
          target.clamp(0, _sc.position.maxScrollExtent),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        controller: _sc,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: widget.categories.length,
        itemBuilder: (_, i) {
          final name = (widget.categories[i]['name'] ?? '').toString();
          final sel = widget.selectedCategory == name;
          return RepaintBoundary(
            child: GestureDetector(
              onTap: () => widget.onSelect(name),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 230),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: sel
                      ? const LinearGradient(
                          colors: [
                            CafeTheme.primaryBrown,
                            CafeTheme.secondaryBrown,
                          ],
                        )
                      : null,
                  color: sel ? null : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: sel
                        ? CafeTheme.primaryBrown
                        : CafeTheme.primaryBrown.withValues(alpha: 0.25),
                    width: sel ? 1.5 : 1,
                  ),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                            color: CafeTheme.primaryBrown.withValues(
                              alpha: 0.45,
                            ),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  name,
                  style: TextStyle(
                    color: sel ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════
// MAGAZINE PRODUCT GRID
// Hero first item spans full width.
// Rest → 2-column grid with semi-transparent
// glass cards — background shows through.
// ══════════════════════════════════════════════
class MagazineProductGrid extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String categoryName;
  final List<Map<String, dynamic>> basket;
  final void Function(Map<String, dynamic>) onAddItem;
  final void Function(int, bool) onQuantityChange;

  const MagazineProductGrid({
    super.key,
    required this.items,
    required this.categoryName,
    required this.basket,
    required this.onAddItem,
    required this.onQuantityChange,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox();

    final sw = MediaQuery.of(context).size.width;
    // On wider screens use more columns for the mini-grid
    final miniCols = sw < 600 ? 2 : 3;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          _sectionHeader(categoryName),
          const SizedBox(height: 16),
          // Hero card — first item
          RepaintBoundary(
            child: _MagazineHeroCard(
              key: ValueKey('hero_${categoryName}_${items[0]['name']}'),
              item: items[0],
              inBasket: basket.any((e) => e['name'] == items[0]['name']),
              qty: _qtyFor(items[0]['name']),
              basketIdx: _basketIdx(items[0]['name']),
              onAdd: () => onAddItem(items[0]),
              onQuantityChange: onQuantityChange,
            ),
          ),
          if (items.length > 1) ...[
            const SizedBox(height: 12),
            // Mini grid — remaining items
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length - 1,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: miniCols,
                childAspectRatio: sw < 400
                    ? 0.88
                    : sw < 600
                    ? 0.92
                    : 1.0,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (_, i) {
                final item = items[i + 1];
                final name = item['name'] ?? '';
                final bIdx = _basketIdx(name);
                return RepaintBoundary(
                  child: _MagazineMiniCard(
                    key: ValueKey('mini_${categoryName}_$name'),
                    item: item,
                    inBasket: bIdx != -1,
                    qty: bIdx != -1 ? basket[bIdx]['quantity'] as int : 0,
                    basketIdx: bIdx,
                    onAdd: () => onAddItem(item),
                    onQuantityChange: onQuantityChange,
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  int _basketIdx(String name) => basket.indexWhere((e) => e['name'] == name);
  int _qtyFor(String name) {
    final i = _basketIdx(name);
    return i != -1 ? basket[i]['quantity'] as int : 0;
  }

  Widget _sectionHeader(String name) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [CafeTheme.primaryBrown, CafeTheme.secondaryBrown],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Hero card — full-width, image left, info right
// ─────────────────────────────────────────────
class _MagazineHeroCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool inBasket;
  final int qty;
  final int basketIdx;
  final VoidCallback onAdd;
  final void Function(int, bool) onQuantityChange;

  const _MagazineHeroCard({
    super.key,
    required this.item,
    required this.inBasket,
    required this.qty,
    required this.basketIdx,
    required this.onAdd,
    required this.onQuantityChange,
  });

  @override
  State<_MagazineHeroCard> createState() => _MagazineHeroCardState();
}

class _MagazineHeroCardState extends State<_MagazineHeroCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _burst;
  bool _showBurst = false;
  final List<_Particle> _particles = [];
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _burst.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _showBurst = false);
        _burst.reset();
      }
    });
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  void _triggerBurst() {
    _particles.clear();
    for (int i = 0; i < 18; i++) {
      _particles.add(
        _Particle(
          angle: (i / 18) * math.pi * 2 + _rng.nextDouble() * 0.4,
          speed: 45 + _rng.nextDouble() * 60,
          size: 4 + _rng.nextDouble() * 5,
          color: [
            CafeTheme.primaryBrown,
            CafeTheme.secondaryBrown,
            CafeTheme.success,
            Colors.white,
            const Color(0xFFD4A96A),
          ][i % 5],
        ),
      );
    }
    setState(() => _showBurst = true);
    _burst.forward();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final name = item['name'] ?? '';
    final hasSz = item['sizes'] != null && (item['sizes'] as List).isNotEmpty;
    final price = hasSz ? 'أحجام متعددة' : '${item['price']} ج.م';
    final sel = widget.inBasket;
    final accent = sel ? CafeTheme.success : CafeTheme.primaryBrown;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              height: 130,
              decoration: BoxDecoration(
                // Semi-transparent so background image shows through
                color: sel
                    ? const Color(0xFF1A2A10).withValues(alpha: 0.75)
                    : const Color(0xFF2E1F10).withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: accent.withValues(alpha: sel ? 0.80 : 0.35),
                  width: sel ? 2.0 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: sel ? 0.35 : 0.12),
                    blurRadius: sel ? 28 : 14,
                    spreadRadius: sel ? 2 : 0,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Colour accent bar
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 5,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [accent, accent.withValues(alpha: 0.5)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.7),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Image
                  _itemImage(item, 90, 90, 18),
                  const SizedBox(width: 16),
                  // Info
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color:
                                    (hasSz
                                            ? Colors.orangeAccent
                                            : CafeTheme.success)
                                        .withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hasSz
                                      ? Icons.tune_rounded
                                      : Icons.payments_outlined,
                                  size: 12,
                                  color: hasSz
                                      ? Colors.orangeAccent
                                      : CafeTheme.success,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  price,
                                  style: TextStyle(
                                    color: hasSz
                                        ? Colors.orangeAccent
                                        : CafeTheme.success,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Add / qty control
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    child: sel
                        ? _QuantityControl(
                            qty: widget.qty,
                            onMinus: () => widget.onQuantityChange(
                              widget.basketIdx,
                              false,
                            ),
                            onPlus: () =>
                                widget.onQuantityChange(widget.basketIdx, true),
                          )
                        : GestureDetector(
                            onTap: () {
                              widget.onAdd();
                              _triggerBurst();
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                gradient: const LinearGradient(
                                  colors: [
                                    CafeTheme.primaryBrown,
                                    CafeTheme.secondaryBrown,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: CafeTheme.primaryBrown.withValues(
                                      alpha: 0.6,
                                    ),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // "في السلة" badge
        if (sel)
          Positioned(
            top: -10,
            right: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [CafeTheme.success, Color(0xFF4CAF50)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: CafeTheme.success.withValues(alpha: 0.6),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, size: 11, color: Colors.black),
                  SizedBox(width: 4),
                  Text(
                    'في السلة',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Particle burst
        if (_showBurst)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _burst,
                builder: (_, __) => CustomPaint(
                  painter: _ParticleBurstPainter(
                    particles: _particles,
                    progress: _burst.value,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Mini card — compact tile in the 2/3-col grid
// ─────────────────────────────────────────────
class _MagazineMiniCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool inBasket;
  final int qty;
  final int basketIdx;
  final VoidCallback onAdd;
  final void Function(int, bool) onQuantityChange;

  const _MagazineMiniCard({
    super.key,
    required this.item,
    required this.inBasket,
    required this.qty,
    required this.basketIdx,
    required this.onAdd,
    required this.onQuantityChange,
  });

  @override
  State<_MagazineMiniCard> createState() => _MagazineMiniCardState();
}

class _MagazineMiniCardState extends State<_MagazineMiniCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _burst;
  bool _showBurst = false;
  bool _isHovered = false;
  final List<_Particle> _particles = [];
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _burst.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _showBurst = false);
        _burst.reset();
      }
    });
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  void _triggerBurst() {
    _particles.clear();
    for (int i = 0; i < 14; i++) {
      _particles.add(
        _Particle(
          angle: (i / 14) * math.pi * 2 + _rng.nextDouble() * 0.5,
          speed: 35 + _rng.nextDouble() * 45,
          size: 3 + _rng.nextDouble() * 4,
          color: [
            CafeTheme.primaryBrown,
            CafeTheme.secondaryBrown,
            CafeTheme.success,
            Colors.white,
          ][i % 4],
        ),
      );
    }
    setState(() => _showBurst = true);
    _burst.forward();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final name = item['name'] ?? '';
    final hasSz = item['sizes'] != null && (item['sizes'] as List).isNotEmpty;
    final price = hasSz ? 'متعدد' : '${item['price']} ج.م';
    final sel = widget.inBasket;
    final accent = sel ? CafeTheme.success : CafeTheme.primaryBrown;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                transform: Matrix4.translationValues(
                  0,
                  _isHovered && !sel ? -3 : 0,
                  0,
                ),
                decoration: BoxDecoration(
                  // Magazine look: semi-transparent glass over bg image
                  color: sel
                      ? const Color(0xFF1A2A10).withValues(alpha: 0.78)
                      : Colors.black.withValues(
                          alpha: _isHovered ? 0.50 : 0.40,
                        ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: accent.withValues(
                      alpha: sel ? 0.80 : (_isHovered ? 0.45 : 0.25),
                    ),
                    width: sel ? 2.0 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: sel ? 0.30 : 0.08),
                      blurRadius: sel ? 22 : 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Image area
                    Expanded(
                      flex: 5,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(22),
                            ),
                            child: _itemImage(
                              item,
                              double.infinity,
                              double.infinity,
                              0,
                              cover: true,
                            ),
                          ),
                          // Add button overlaid on image — corner "+"
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: sel
                                ? const SizedBox.shrink()
                                : GestureDetector(
                                    onTap: () {
                                      widget.onAdd();
                                      _triggerBurst();
                                    },
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        gradient: const LinearGradient(
                                          colors: [
                                            CafeTheme.primaryBrown,
                                            CafeTheme.secondaryBrown,
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: CafeTheme.primaryBrown
                                                .withValues(alpha: 0.65),
                                            blurRadius: 12,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.add_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                          ),
                          if (sel)
                            Positioned(
                              bottom: 6,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: _QuantityControl(
                                  qty: widget.qty,
                                  onMinus: () => widget.onQuantityChange(
                                    widget.basketIdx,
                                    false,
                                  ),
                                  onPlus: () => widget.onQuantityChange(
                                    widget.basketIdx,
                                    true,
                                  ),
                                  compact: true,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Info row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: sel
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            price,
                            style: TextStyle(
                              color: hasSz
                                  ? Colors.orangeAccent
                                  : CafeTheme.success,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // "في السلة" badge
        if (sel)
          Positioned(
            top: -8,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [CafeTheme.success, Color(0xFF4CAF50)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: CafeTheme.success.withValues(alpha: 0.55),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, size: 10, color: Colors.black),
                  SizedBox(width: 3),
                  Text(
                    '✓',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Burst
        if (_showBurst)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _burst,
                builder: (_, __) => CustomPaint(
                  painter: _ParticleBurstPainter(
                    particles: _particles,
                    progress: _burst.value,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Shared image builder
// ─────────────────────────────────────────────
Widget _itemImage(
  Map<String, dynamic> item,
  double w,
  double h,
  double r, {
  bool cover = false,
}) {
  final url = item['image_url'] as String?;
  if (url != null && url.isNotEmpty) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: Image.network(
        url,
        width: w,
        height: h,
        fit: cover ? BoxFit.cover : BoxFit.cover,
        cacheWidth: 380,
        cacheHeight: 380,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _imagePlaceholder(w, h, r),
        errorBuilder: (_, __, ___) => _imageFallback(w, h, r),
      ),
    );
  }
  return _imageFallback(w, h, r);
}

Widget _imagePlaceholder(double w, double h, double r) {
  return Container(
    width: w == double.infinity ? null : w,
    height: h == double.infinity ? null : h,
    decoration: BoxDecoration(
      color: CafeTheme.surface,
      borderRadius: BorderRadius.circular(r),
    ),
    child: Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: CafeTheme.accent.withValues(alpha: 0.6),
        ),
      ),
    ),
  );
}

Widget _imageFallback(double w, double h, double r) {
  return Container(
    width: w == double.infinity ? null : w,
    height: h == double.infinity ? null : h,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(r),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          CafeTheme.primaryBrown.withValues(alpha: 0.22),
          CafeTheme.secondaryBrown.withValues(alpha: 0.14),
        ],
      ),
      border: Border.all(
        color: CafeTheme.primaryBrown.withValues(alpha: 0.35),
        width: 1.5,
      ),
    ),
    child: const Icon(
      Icons.fastfood_rounded,
      color: CafeTheme.primaryBrown,
      size: 36,
    ),
  );
}

// ─────────────────────────────────────────────
// Quantity control — reusable, const-friendly
// ─────────────────────────────────────────────
class _QuantityControl extends StatelessWidget {
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final bool compact;

  const _QuantityControl({
    required this.qty,
    required this.onMinus,
    required this.onPlus,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final sz = compact ? 30.0 : 36.0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 12 : 15),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(
          color: CafeTheme.success.withValues(alpha: 0.40),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.remove_rounded, Colors.redAccent, onMinus, sz),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 13),
            child: Text(
              '$qty',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: compact ? 15 : 17,
              ),
            ),
          ),
          _btn(Icons.add_rounded, CafeTheme.success, onPlus, sz),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, Color color, VoidCallback onTap, double sz) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: sz,
        height: sz,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 8 : 11),
          color: color.withValues(alpha: 0.18),
        ),
        child: Icon(icon, color: color, size: compact ? 16 : 20),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Particle system (same as original)
// ─────────────────────────────────────────────
class _Particle {
  final double angle, speed, size;
  final Color color;
  const _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
  });
}

class _ParticleBurstPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  const _ParticleBurstPainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = math.sin(progress * math.pi / 2);
    final alpha = progress < 0.5 ? 1.0 : 1.0 - (progress - 0.5) * 2;
    final center = Offset(size.width / 2, size.height / 2);

    for (final p in particles) {
      final dist = p.speed * t;
      final px = center.dx + math.cos(p.angle) * dist;
      final py = center.dy + math.sin(p.angle) * dist;
      canvas.drawCircle(
        Offset(px, py),
        p.size * (1 - progress * 0.5),
        Paint()
          ..color = p.color.withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      if (dist > 8) {
        final td = dist - 8;
        canvas.drawLine(
          Offset(
            center.dx + math.cos(p.angle) * td,
            center.dy + math.sin(p.angle) * td,
          ),
          Offset(px, py),
          Paint()
            ..color = p.color.withValues(alpha: alpha * 0.4)
            ..strokeWidth = p.size * 0.6
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleBurstPainter old) =>
      old.progress != progress;
}

// ─────────────────────────────────────────────
// Category icon helper
// ─────────────────────────────────────────────
IconData _categoryIconByName(String name) {
  final n = name.toLowerCase();
  if (n.contains('برجر') || n.contains('burger'))
    return Icons.lunch_dining_rounded;
  if (n.contains('بيتزا') || n.contains('pizza'))
    return Icons.local_pizza_rounded;
  if (n.contains('مكرونة') || n.contains('باستا'))
    return Icons.ramen_dining_rounded;
  if (n.contains('مشروب') || n.contains('drink'))
    return Icons.local_drink_rounded;
  if (n.contains('حلويات') || n.contains('dessert')) return Icons.cake_rounded;
  if (n.contains('قهوة') || n.contains('coffee')) return Icons.coffee_rounded;
  return Icons.restaurant_menu_rounded;
}

// ══════════════════════════════════════════════
// WAITER TERMINAL — unchanged logic, cleaner UI
// ══════════════════════════════════════════════
class WaiterTerminal extends StatefulWidget {
  const WaiterTerminal({super.key});
  @override
  State<WaiterTerminal> createState() => _WaiterTerminalState();
}

class _WaiterTerminalState extends State<WaiterTerminal> {
  int _tab = 0;
  final List<Map<String, dynamic>> waiterBasket = [];
  final tableCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final searchCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  String? selectedCategory;
  String searchQuery = '';

  @override
  void dispose() {
    tableCtrl.dispose();
    nameCtrl.dispose();
    searchCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  void _playSound(String url) {
    if (kIsWeb)
      js.context.callMethod('eval', [
        "(function(){var a=new Audio('$url');a.play();})()",
      ]);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showWaiterAddDialog(Map<String, dynamic> item) {
    noteCtrl.clear();
    final sizes = item['sizes'] as List<dynamic>?;
    Map<String, dynamic>? selSize = sizes?.isNotEmpty == true
        ? sizes!.first
        : null;
    double price = selSize != null
        ? (selSize['price'] as num).toDouble()
        : (item['price'] as num).toDouble();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDS) => AlertDialog(
          backgroundColor: const Color(0xFF2E1F10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: CafeTheme.secondaryBrown.withValues(alpha: 0.7),
              width: 1.5,
            ),
          ),
          title: Text(
            'إضافة ${item['name']}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: CafeTheme.secondaryBrown,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (sizes != null && sizes.isNotEmpty) ...[
                const Text(
                  'اختر الحجم:',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.end,
                  children: sizes.map((s) {
                    final isSel = selSize == s;
                    return ChoiceChip(
                      label: Text('${s['name']} - ${s['price']} ج.م'),
                      selected: isSel,
                      selectedColor: CafeTheme.secondaryBrown,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      labelStyle: TextStyle(
                        color: isSel ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (v) {
                        if (v)
                          setDS(() {
                            selSize = s;
                            price = (s['price'] as num).toDouble();
                          });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],
              TextField(
                controller: noteCtrl,
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'ملاحظات (سكر زيادة، بدون ثلج...)',
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: CafeTheme.secondaryBrown.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(fontSize: 16)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: CafeTheme.secondaryBrown,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                setState(() {
                  final note = noteCtrl.text.isEmpty
                      ? 'بدون ملاحظات'
                      : noteCtrl.text;
                  String iName = item['name'];
                  if (selSize != null) iName += ' (${selSize!['name']})';
                  final idx = waiterBasket.indexWhere(
                    (e) =>
                        e['name'] == iName &&
                        e['note'] == note &&
                        e['price'] == price,
                  );
                  if (idx != -1)
                    waiterBasket[idx]['qty']++;
                  else
                    waiterBasket.add({
                      'name': iName,
                      'price': price,
                      'note': note,
                      'qty': 1,
                    });
                });
                Navigator.pop(ctx);
              },
              child: const Text(
                'إضافة',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendToBarista() async {
    if (waiterBasket.isEmpty) {
      _showSnack('السلة فارغة!', Colors.orangeAccent);
      return;
    }
    if (tableCtrl.text.isEmpty || nameCtrl.text.isEmpty) {
      _showSnack('يرجى إدخال رقم الطاولة واسم العميل', Colors.orangeAccent);
      return;
    }
    final itemsWithQty = waiterBasket
        .map((e) => {'name': e['name'], 'qty': e['qty']})
        .toList();
    final total = waiterBasket.fold(
      0.0,
      (p, e) => p + (e['price'] as num) * (e['qty'] as num),
    );
    final note = waiterBasket.any((e) => e['note'] != 'بدون ملاحظات')
        ? waiterBasket.firstWhere((e) => e['note'] != 'بدون ملاحظات')['note']
        : 'بدون ملاحظات';
    try {
      await apiService.createWaiterOrder(
        customerName: nameCtrl.text.trim(),
        tableNumber: tableCtrl.text.trim(),
        itemsWithQty: itemsWithQty,
        totalPrice: total,
        note: note,
      );
      final lines = waiterBasket
          .map((e) => '  • ${e['name']} × ${e['qty']}')
          .join('\n');
      await apiService.sendTelegramMessage(
        '━━━━━━━━━━━━━━━━━━\n🤵 طلب ويتر — Storm Café\n━━━━━━━━━━━━━━━━━━\n'
        '👤 العميل : ${nameCtrl.text}\n🪑 الطاولة : ${tableCtrl.text}\n━━━━━━━━━━━━━━━━━━\n'
        '🛒 الطلبات :\n$lines\n━━━━━━━━━━━━━━━━━━\n'
        '📝 ملاحظة : $note\n💰 الإجمالي : ${total.toStringAsFixed(2)} ج.م\n━━━━━━━━━━━━━━━━━━',
      );
      setState(() => waiterBasket.clear());
      _showSnack('تم إرسال الطلب للباريستا! ✅', Colors.greenAccent);
    } catch (e) {
      if (e is ApiException && e.statusCode == 401) {
        _showSnack('انتهت صلاحية الجلسة', Colors.red);
      } else {
        _showSnack('تعذر إرسال الطلب الآن', Colors.redAccent);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: CafeTheme.surface,
          title: const Text(
            'لوحة الويتر 🤵',
            style: TextStyle(
              color: CafeTheme.secondaryBrown,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          elevation: 5,
          shadowColor: CafeTheme.primaryBrown.withValues(alpha: 0.3),
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: CafeTheme.surface,
          selectedItemColor: CafeTheme.primaryBrown,
          unselectedItemColor: Colors.white54,
          currentIndex: _tab,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          onTap: (i) => setState(() => _tab = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.point_of_sale),
              label: 'نقطة البيع (POS)',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long),
              label: 'إدارة الطلبات',
            ),
          ],
        ),
        body: _tab == 0 ? _buildPOSView() : _buildOrdersView(),
      ),
    );
  }

  // POS VIEW
  Widget _buildPOSView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: _waiterField(
                  tableCtrl,
                  'رقم الطاولة',
                  TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _waiterField(nameCtrl, 'اسم العميل', TextInputType.text),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _waiterSearchField(),
        ),
        const SizedBox(height: 16),
        _waiterCategoryBar(),
        const SizedBox(height: 16),
        Expanded(child: _waiterProductGrid()),
        if (waiterBasket.isNotEmpty) _buildBasketSummary(),
      ],
    );
  }

  Widget _waiterField(
    TextEditingController ctrl,
    String label,
    TextInputType kb,
  ) {
    return TextField(
      controller: ctrl,
      keyboardType: kb,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: CafeTheme.secondaryBrown),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _waiterSearchField() {
    return TextField(
      controller: searchCtrl,
      onChanged: (v) => setState(() => searchQuery = v),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'ابحث عن منتج...',
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: const Icon(Icons.search, color: CafeTheme.secondaryBrown),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _waiterCategoryBar() {
    return SizedBox(
      height: 45,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('categories').snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const SizedBox();
          final cats = snap.data!.docs.toList()
            ..sort((a, b) {
              final ai = (a.data() as Map)['index'] ?? 999;
              final bi = (b.data() as Map)['index'] ?? 999;
              return (ai as num).compareTo(bi as num);
            });
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: cats.length + 1,
            itemBuilder: (_, i) {
              final isAll = i == 0;
              final catName = isAll ? null : cats[i - 1]['name'] as String?;
              final isSel = selectedCategory == catName;
              return GestureDetector(
                onTap: () => setState(() => selectedCategory = catName),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSel
                        ? CafeTheme.secondaryBrown
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSel
                          ? CafeTheme.secondaryBrown
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    isAll ? 'الكل' : (catName ?? ''),
                    style: TextStyle(
                      color: isSel ? Colors.black : Colors.white70,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _waiterProductGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: selectedCategory == null
          ? FirebaseFirestore.instance.collection('products').snapshots()
          : FirebaseFirestore.instance
                .collection('products')
                .where('cat', isEqualTo: selectedCategory)
                .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: CafeTheme.secondaryBrown),
          );
        }
        final items = snap.data!.docs
            .where((d) => (d['name'] ?? '').toString().contains(searchQuery))
            .toList();
        final sw = MediaQuery.of(context).size.width;
        return GridView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: sw < 600 ? 2 : 4,
            childAspectRatio: sw < 600 ? 0.85 : 1.0,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (_, i) {
            final data = items[i].data() as Map<String, dynamic>;
            return GestureDetector(
              onTap: () => _showWaiterAddDialog(data),
              child: Container(
                decoration: BoxDecoration(
                  color: CafeTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: CafeTheme.primaryBrown.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _itemImage(data, 70, 70, 14),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        data['name'] ?? '',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${data['price']} ج.م',
                      style: const TextStyle(
                        color: CafeTheme.primaryBrown,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBasketSummary() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CafeTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: const Border(
          top: BorderSide(color: CafeTheme.primaryBrown, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: CafeTheme.primaryBrown.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: waiterBasket.length,
              itemBuilder: (_, i) {
                final it = waiterBasket[i];
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              it['name'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (it['note'] != 'بدون ملاحظات')
                              Text(
                                '📝 ${it['note']}',
                                style: const TextStyle(
                                  color: Colors.orangeAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.redAccent,
                          size: 24,
                        ),
                        onPressed: () => setState(() {
                          if (it['qty'] > 1)
                            it['qty']--;
                          else
                            waiterBasket.removeAt(i);
                        }),
                      ),
                      Text(
                        '${it['qty']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.greenAccent,
                          size: 24,
                        ),
                        onPressed: () => setState(() => it['qty']++),
                      ),
                      SizedBox(
                        width: 80,
                        child: Text(
                          '${((it['qty'] as num) * (it['price'] as num)).toStringAsFixed(0)} ج.م',
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            color: CafeTheme.primaryBrown,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: CafeTheme.secondaryBrown,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 5,
                shadowColor: CafeTheme.secondaryBrown.withValues(alpha: 0.5),
              ),
              onPressed: _sendToBarista,
              child: const Text(
                'إرسال الطلب للباريستا',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ORDERS VIEW
  Widget _buildOrdersView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (_, snap) {
        if (snap.hasError) {
          return Center(
            child: Text(
              'خطأ: ${snap.error}',
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: CafeTheme.secondaryBrown),
          );
        }
        final orders = snap.data!.docs;
        if (orders.isEmpty) {
          return const Center(
            child: Text(
              'لا توجد طلبات حالياً',
              style: TextStyle(color: Colors.white54, fontSize: 18),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: orders.length,
          itemBuilder: (_, i) => _buildOrderCard(orders[i]),
        );
      },
    );
  }

  Widget _buildOrderCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] ?? 'قيد الانتظار';
    final sColor = status == 'جاهز'
        ? Colors.greenAccent
        : (status == 'جاري التجهيز' ? Colors.orangeAccent : Colors.white54);
    final items = (data['items_with_qty'] as List<dynamic>?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: CafeTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: sColor.withValues(alpha: 0.45), width: 1.5),
        boxShadow: [
          BoxShadow(color: sColor.withValues(alpha: 0.08), blurRadius: 12),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: sColor.withValues(alpha: 0.15),
                    border: Border.all(color: sColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: sColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '🪑 ${data['table_number'] ?? '?'}',
                  style: const TextStyle(
                    color: CafeTheme.primaryBrown,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '👤 ${data['customer_name'] ?? ''}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map(
              (it) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const Icon(
                      Icons.circle,
                      size: 6,
                      color: CafeTheme.primaryBrown,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${it['name']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      '× ${it['qty']}',
                      style: const TextStyle(
                        color: CafeTheme.secondaryBrown,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (data['note'] != null && data['note'] != 'بدون ملاحظات') ...[
              const SizedBox(height: 8),
              Text(
                '📝 ${data['note']}',
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 14),
            const Divider(color: Colors.white12),
            const SizedBox(height: 10),
            Row(
              children: [
                _statusButton('قيد الانتظار', Colors.white54, status, doc.id),
                const SizedBox(width: 8),
                _statusButton(
                  'جاري التجهيز',
                  Colors.orangeAccent,
                  status,
                  doc.id,
                ),
                const SizedBox(width: 8),
                _statusButton('جاهز', Colors.greenAccent, status, doc.id),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusButton(
    String label,
    Color color,
    String current,
    String docId,
  ) {
    final isSel = current == label;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          try {
            await apiService.updateOrder(docId, label);
          } catch (_) {
            _showSnack('تعذر تحديث الحالة', Colors.redAccent);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSel
                ? color.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSel ? color : Colors.white24,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSel ? color : Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
