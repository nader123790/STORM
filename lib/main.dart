// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const NeonCyberCafeApp());
}

const String _kBgImage   = 'assets/images/storm_bg.jpg';
const String _kLogoImage = 'assets/images/storm_logo.png';

// ── Shared helpers ─────────────────────────────────────────────────────────────

Widget buildstormLogo({double size = 60, Color? color}) => Image.asset(
  _kLogoImage,
  width: size,
  height: size,
  color: color,
  fit: BoxFit.contain,
  errorBuilder: (_, __, ___) =>
      Icon(Icons.restaurant_menu, size: size, color: CafeTheme.accent),
);

IconData _categoryIconByName(String name) {
  final n = name.toLowerCase();
  if (n.contains('برجر') || n.contains('burger'))   return Icons.lunch_dining_rounded;
  if (n.contains('بيتزا') || n.contains('pizza'))   return Icons.local_pizza_rounded;
  if (n.contains('مكرونة') || n.contains('باستا'))  return Icons.ramen_dining_rounded;
  if (n.contains('مشروب') || n.contains('drink'))   return Icons.local_drink_rounded;
  if (n.contains('حلويات') || n.contains('dessert')) return Icons.cake_rounded;
  return Icons.restaurant_menu_rounded;
}

// ── App ─────────────────────────────────────────────────────────────────────────

class NeonCyberCafeApp extends StatelessWidget {
  const NeonCyberCafeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Storm Café | Premium Experience',
    theme: CafeTheme.themeData,
    home: const MenuPage(),
  );
}

// ── Background (RepaintBoundary outside scroll) ─────────────────────────────────

class _MenuBackground extends StatelessWidget {
  const _MenuBackground();

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: RepaintBoundary(
      child: Stack(children: [
        Image.asset(
          _kBgImage,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: 1920,
          errorBuilder: (_, __, ___) => const ColoredBox(color: CafeTheme.deepBrown),
        ),
        const ColoredBox(color: Color(0xEE1A0F05)),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.2, -0.1),
              radius: 1.2,
              colors: [
                Color(0x1A5F3814),
                Color(0x0F987B5C),
                Colors.transparent,
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ]),
    ),
  );
}

// ── MenuPage ────────────────────────────────────────────────────────────────────

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> with TickerProviderStateMixin {
  String? _currentCat;
  final _catSearchCtrl    = TextEditingController();
  final _globalSearchCtrl = TextEditingController();
  final _noteController   = TextEditingController();
  final _nameEntryCtrl    = TextEditingController();
  final _tableEntryCtrl   = TextEditingController();

  List<Map<String, dynamic>> _basket = [];
  String? _registeredName;
  String? _currentTable;
  bool _isEntryComplete    = false;
  bool _hasSavedName       = false;
  bool _isWaiterAlertActive = false;
  bool _showQuickMenu      = false;

  late final AnimationController _glowCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  late final AnimationController _fabPulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _checkSavedData();
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _fabPulseCtrl.dispose();
    _catSearchCtrl.dispose();
    _globalSearchCtrl.dispose();
    _noteController.dispose();
    _nameEntryCtrl.dispose();
    _tableEntryCtrl.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  void _checkSavedData() {
    if (!kIsWeb) return;
    final saved = html.window.localStorage['customer_name'];
    if (saved != null && saved.isNotEmpty) {
      setState(() { _registeredName = saved; _hasSavedName = true; });
    }
  }

  void _playSound(String url, {double volume = 1.0}) {
    if (!kIsWeb) return;
    final v = volume.clamp(0.0, 1.0);
    js.context.callMethod('eval', [
      "(function(){var a=new Audio('$url');a.volume=$v;a.play();})();"
    ]);
  }

  void _playWaiterBell() => _playSound("https://files.catbox.moe/y77se9.mp3");

  void _validateAndStart() {
    final name = _hasSavedName ? _registeredName! : _nameEntryCtrl.text.trim();
    if (name.isEmpty) { _showSnack("يرجى إدخال الاسم", Colors.redAccent); return; }
    if (_tableEntryCtrl.text.trim().isEmpty) {
      _showSnack("يرجى تحديد رقم الطاولة", Colors.redAccent); return;
    }
    _currentTable = _tableEntryCtrl.text.trim();
    if (kIsWeb) html.window.localStorage['customer_name'] = name;
    setState(() { _registeredName = name; _isEntryComplete = true; });
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(
        fontWeight: FontWeight.bold, color: Colors.black, fontSize: 15)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 10,
    ));
  }

  // ── Waiter login ───────────────────────────────────────────────────────────

  void _showWaiterLogin() {
    final pwCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) {
          bool loading = false;
          return AlertDialog(
            backgroundColor: CafeTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: CafeTheme.primaryBrown, width: 1.5),
            ),
            title: const Text('دخول الويتر 🤵',
              textAlign: TextAlign.center,
              style: TextStyle(color: CafeTheme.secondaryBrown, fontWeight: FontWeight.bold)),
            content: TextField(
              controller: pwCtrl,
              obscureText: true,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                hintText: 'أدخل كلمة السر',
                filled: true,
                fillColor: const Color(0x14FFFFFF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء', style: TextStyle(fontSize: 16))),
              StatefulBuilder(builder: (ctx2, setBtn) => ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: CafeTheme.primaryBrown,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: loading ? null : () async {
                  setBtn(() => loading = true);
                  try {
                    await apiService.loginWaiter(pwCtrl.text);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const WaiterTerminal()));
                  } on ApiException catch (e) {
                    setBtn(() => loading = false);
                    if (context.mounted) _showSnack(
                      e.statusCode == 401 ? 'كلمة السر خاطئة!' : 'تعذر التحقق',
                      Colors.red);
                  } catch (_) {
                    setBtn(() => loading = false);
                    if (context.mounted) _showSnack('تعذر الاتصال بالخادم', Colors.red);
                  }
                },
                child: loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('دخول', style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
              )),
            ],
          );
        },
      ),
    );
  }

  // ── Categories sheet ────────────────────────────────────────────────────────

  void _showCategoriesSheet(List<QueryDocumentSnapshot> cats) {
    _catSearchCtrl.clear();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final sw = MediaQuery.of(ctx).size.width;
        final cross  = sw < 600 ? 2 : 4;
        final aspect = sw < 400 ? 2.0 : sw < 600 ? 2.3 : 3.0;
        return StatefulBuilder(builder: (ctx, ss) {
          final q = _catSearchCtrl.text.trim();
          final filtered = q.isEmpty ? cats
              : cats.where((d) => (d['name'] ?? '').toString().contains(q)).toList();
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: MediaQuery.of(ctx).size.height * 0.75,
                decoration: const BoxDecoration(
                  color: Color(0xD92E1F10),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  border: Border(
                    top:   BorderSide(color: CafeTheme.primaryBrown, width: 1.5),
                    left:  BorderSide(color: CafeTheme.primaryBrown, width: 0.5),
                    right: BorderSide(color: CafeTheme.primaryBrown, width: 0.5),
                  ),
                  boxShadow: [BoxShadow(
                    color: Color(0x665F3814), blurRadius: 40, spreadRadius: 5)],
                ),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                  left: 20, right: 20, top: 15),
                child: Column(children: [
                  Container(
                    width: 60, height: 5,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [CafeTheme.primaryBrown, CafeTheme.secondaryBrown]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 25),
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      colors: [CafeTheme.primaryBrown, CafeTheme.secondaryBrown])
                        .createShader(b),
                    child: const Text("اختر القسم", style: TextStyle(
                      color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.w900, letterSpacing: 2)),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0x14FFFFFF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0x66987B5C)),
                    ),
                    child: TextField(
                      controller: _catSearchCtrl,
                      onChanged: (_) => ss(() {}),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "ابحث عن قسم...",
                        hintStyle: TextStyle(color: Colors.white38),
                        prefixIcon: Icon(Icons.search, color: CafeTheme.secondaryBrown),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(child: GridView.builder(
                    itemCount: filtered.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cross, childAspectRatio: aspect,
                      crossAxisSpacing: 16, mainAxisSpacing: 16),
                    itemBuilder: (_, i) {
                      final cn = (filtered[i]['name'] ?? '').toString();
                      final sel = _currentCat == cn;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _currentCat = cn);
                          Navigator.pop(ctx);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          decoration: BoxDecoration(
                            gradient: sel ? const LinearGradient(
                              colors: [CafeTheme.primaryBrown, CafeTheme.secondaryBrown]) : null,
                            color: sel ? null : const Color(0x0DFFFFFF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel ? CafeTheme.primaryBrown
                                         : const Color(0x405F3814),
                              width: sel ? 1.5 : 1),
                            boxShadow: sel ? [const BoxShadow(
                              color: Color(0x805F3814), blurRadius: 15, spreadRadius: 1)] : null,
                          ),
                          child: Center(child: Text(cn,
                            textAlign: TextAlign.center,
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: sel ? Colors.black : Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: sw < 400 ? 16 : 15))),
                        ),
                      );
                    },
                  )),
                ]),
              ),
            ),
          );
        });
      },
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(children: [
        _buildMainContent(),
        if (!_isEntryComplete) _buildEntryOverlay(),
      ]),
    ),
  );

  Widget _buildEntryOverlay() => Container(
    color: const Color(0xF5000000),
    child: Center(child: SingleChildScrollView(child: Container(
      padding: const EdgeInsets.all(40),
      width: 400,
      decoration: BoxDecoration(
        color: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0x995F3814), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x335F3814), blurRadius: 50, spreadRadius: 5),
          BoxShadow(color: Color(0x1A987B5C), blurRadius: 80, spreadRadius: 15),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        buildstormLogo(size: 110),
        const SizedBox(height: 15),
        const Text("storm", style: TextStyle(
          color: CafeTheme.primaryBrown, fontSize: 36,
          fontWeight: FontWeight.w900, letterSpacing: 6)),
        const SizedBox(height: 8),
        const Text("اطلب وانت في راحتك ⚡",
          style: TextStyle(color: Colors.white54, fontSize: 15)),
        const SizedBox(height: 35),
        if (!_hasSavedName) ...[
          _EntryField(ctrl: _nameEntryCtrl, hint: "اسمك الكريم..", icon: Icons.person_outline_rounded),
          const SizedBox(height: 18),
        ],
        _EntryField(ctrl: _tableEntryCtrl, hint: "رقم الطاولة..",
          icon: Icons.table_restaurant_rounded, isNumber: true),
        const SizedBox(height: 30),
        _AnimatedButton(
          onPressed: _validateAndStart,
          child: const Text("اكتشف القائمة ⚡", style: TextStyle(
            color: Colors.black, fontWeight: FontWeight.w900, fontSize: 20))),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: _showWaiterLogin,
          icon: const Icon(Icons.lock_person, color: CafeTheme.accent, size: 20),
          label: const Text("الدخول كويتر", style: TextStyle(
            color: CafeTheme.accent, fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ]),
    ))),
  );

  Widget _buildMainContent() => Stack(children: [
    const _MenuBackground(),
    CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        _buildCinematicHeader(),
        _buildSearchBar(),
        _buildCategoryCarouselSection(),
        SliverToBoxAdapter(child: _buildProductListSection()),
        const SliverToBoxAdapter(child: SizedBox(height: 350)),
      ],
    ),
    _buildBottomActionArea(),
    _buildFloatingActionMenu(),
  ]);

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildCinematicHeader() => SliverToBoxAdapter(
    child: Container(
      padding: const EdgeInsets.fromLTRB(24, 55, 24, 20),
      decoration: BoxDecoration(
        color: CafeTheme.surface.withValues(alpha: 0.85),
        border: const Border(bottom: BorderSide(color: CafeTheme.border, width: 1.5)),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 15, offset: Offset(0, 5))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Dev badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x66C49A6D)),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.code_rounded, color: CafeTheme.accent, size: 18),
            SizedBox(width: 6),
            Text("Dev", style: TextStyle(
              color: CafeTheme.accent, fontSize: 12, fontWeight: FontWeight.w900)),
          ]),
        ),
        // Logo center
        Expanded(child: Column(children: [
          GestureDetector(
            onTap: () { if (kIsWeb) html.window.location.reload(); },
            child: buildstormLogo(size: 48),
          ),
          const SizedBox(height: 6),
          const Text("storm", style: TextStyle(
            color: CafeTheme.accent, fontWeight: FontWeight.w900,
            letterSpacing: 6, fontSize: 22)),
          if (_registeredName != null && _currentTable != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text("طاولة $_currentTable  |  أهلاً، $_registeredName",
                style: const TextStyle(
                  fontSize: 12, color: Colors.white70,
                  letterSpacing: 0.5, fontWeight: FontWeight.bold)),
            ),
        ])),
        // Right controls
        Column(children: [
          GestureDetector(
            onTap: _changeTableDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0x14FFFFFF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x665F3814), width: 1.2),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.table_restaurant_rounded, color: CafeTheme.primaryBrown, size: 20),
                SizedBox(width: 6),
                Text("الطاولة", style: TextStyle(
                  color: CafeTheme.primaryBrown, fontSize: 12, fontWeight: FontWeight.w900)),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          RepaintBoundary(child: AnimatedBuilder(
            animation: _glowCtrl,
            builder: (_, __) => GestureDetector(
              onTap: _callWaiter,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: CafeTheme.accent.withValues(alpha: 0.5 + 0.5 * _glowCtrl.value),
                    width: 1.8),
                  boxShadow: _isWaiterAlertActive ? [BoxShadow(
                    color: CafeTheme.accent.withValues(alpha: 0.3 * _glowCtrl.value),
                    blurRadius: 10, spreadRadius: 1)] : null,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_isWaiterAlertActive ? "جاري.." : "نداء",
                    style: const TextStyle(
                      color: CafeTheme.accent, fontSize: 12, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 5),
                  const Icon(Icons.notifications_active_rounded,
                    color: CafeTheme.accent, size: 16),
                ]),
              ),
            ),
          )),
        ]),
      ]),
    ),
  );

  // ── Search bar ──────────────────────────────────────────────────────────────

  Widget _buildSearchBar() => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Container(
        decoration: BoxDecoration(
          color: CafeTheme.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: CafeTheme.border, width: 1.5),
          boxShadow: const [BoxShadow(
            color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: TextField(
          controller: _globalSearchCtrl,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: CafeTheme.textMain, fontSize: 16),
          decoration: InputDecoration(
            hintText: "ابحث عن منتج أو قسم...",
            hintStyle: TextStyle(color: CafeTheme.mutedText.withValues(alpha: 0.8), fontSize: 15),
            prefixIcon: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Icon(Icons.search_rounded, color: CafeTheme.accent, size: 24)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 20),
          ),
        ),
      ),
    ),
  );

  // ── Category carousel section ───────────────────────────────────────────────

  Widget _buildCategoryCarouselSection() => SliverToBoxAdapter(
    child: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('categories').snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) return const SizedBox(height: 200,
          child: Center(child: Text("تعذر تحميل الأقسام حالياً",
            style: TextStyle(color: Colors.white54, fontSize: 16))));
        if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox(height: 200);

        final cats = snap.data!.docs.toList()
          ..sort((a, b) {
            final ai = (a.data() as Map<String, dynamic>)['index'] ?? 999;
            final bi = (b.data() as Map<String, dynamic>)['index'] ?? 999;
            return (ai as num).compareTo(bi as num);
          });

        _currentCat ??= cats.first['name'] as String?;

        return Column(children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(children: [
              const Icon(Icons.category_rounded, color: CafeTheme.secondaryBrown, size: 22),
              const SizedBox(width: 10),
              const Text("القسم الحالي", style: TextStyle(
                color: Colors.white70, fontSize: 14,
                letterSpacing: 1.5, fontWeight: FontWeight.w900)),
              const SizedBox(width: 12),
              Expanded(child: Text(_currentCat ?? "",
                style: const TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          ),
          const SizedBox(height: 16),
          _buildAllCatsButton(cats),
          const SizedBox(height: 16),
          CinematicCategoryCarousel(
            categories: cats,
            selectedCategory: _currentCat,
            onSelect: (cn) {
              if (_currentCat == cn) return;
              _playSound("https://assets.mixkit.co/active_storage/sfx/270/270-preview.mp3", volume: 0.13);
              setState(() => _currentCat = cn);
            },
          ),
          const SizedBox(height: 12),
        ]);
      },
    ),
  );

  Widget _buildAllCatsButton(List<QueryDocumentSnapshot> cats) => GestureDetector(
    onTap: () => _showCategoriesSheet(cats),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 45, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [CafeTheme.primaryBrown, Color(0xFF7A4D2A)]),
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [BoxShadow(
          color: Color(0x805F3814), blurRadius: 22, spreadRadius: 2, offset: Offset(0, 4))],
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.grid_view_rounded, color: Colors.black, size: 20),
        SizedBox(width: 10),
        Text("كل الأقسام", style: TextStyle(
          color: Colors.black, fontWeight: FontWeight.w900,
          fontSize: 16, letterSpacing: 1)),
      ]),
    ),
  );

  // ── Product list ────────────────────────────────────────────────────────────

  Widget _buildProductListSection() {
    if (_currentCat == null) return const SizedBox();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products').where('cat', isEqualTo: _currentCat).snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError || !snap.hasData) return const SizedBox();
        var docs = snap.data!.docs;
        final q = _globalSearchCtrl.text.trim();
        if (q.isNotEmpty) {
          docs = docs.where((d) => (d['name'] ?? '').toString().contains(q)).toList();
        }
        if (docs.isEmpty) return const Padding(
          padding: EdgeInsets.all(50),
          child: Center(child: Text("لا توجد منتجات في هذا القسم",
            style: TextStyle(color: Colors.white54, fontSize: 16))));

        return UFOBeamProductSection(
          items: docs.map((d) => d.data() as Map<String, dynamic>).toList(),
          categoryName: _currentCat ?? '',
          onAddItem: _showAddDialog,
          onQuantityChange: (idx, increase) => setState(() {
            if (increase) {
              _basket[idx]['quantity']++;
            } else {
              if (_basket[idx]['quantity'] > 1) _basket[idx]['quantity']--;
              else _basket.removeAt(idx);
            }
          }),
          basket: _basket,
        );
      },
    );
  }

  // ── Floating action menu ────────────────────────────────────────────────────

  Widget _buildFloatingActionMenu() => Positioned(
    bottom: 230, left: 24,
    child: Column(children: [
      if (_showQuickMenu) ...[
        _FabOption(icon: Icons.receipt_long_rounded, label: "الحساب",
          color: CafeTheme.success, onTap: () { setState(() => _showQuickMenu = false); _requestBill(); }),
        const SizedBox(height: 12),
        _FabOption(icon: Icons.help_outline_rounded, label: "مساعدة",
          color: CafeTheme.secondaryBrown, onTap: () {
            setState(() => _showQuickMenu = false);
            _showSnack("جاري إرسال طلب المساعدة... 🙏", CafeTheme.secondaryBrown);
          }),
        const SizedBox(height: 12),
        _FabOption(icon: Icons.room_service_rounded, label: "نداء ويتر",
          color: CafeTheme.accent, onTap: () { setState(() => _showQuickMenu = false); _callWaiter(); }),
        const SizedBox(height: 16),
      ],
      RepaintBoundary(child: AnimatedBuilder(
        animation: _fabPulseCtrl,
        builder: (_, __) => GestureDetector(
          onTap: () => setState(() => _showQuickMenu = !_showQuickMenu),
          child: Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [CafeTheme.primaryBrown, CafeTheme.secondaryBrown],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: [BoxShadow(
                color: CafeTheme.primaryBrown.withValues(alpha: 0.5 + 0.3 * _fabPulseCtrl.value),
                blurRadius: 25, spreadRadius: 4)],
            ),
            child: AnimatedRotation(
              turns: _showQuickMenu ? 0.02 : 0,
              duration: const Duration(milliseconds: 300),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
                child: Icon(
                  _showQuickMenu ? Icons.close_rounded : Icons.support_agent_rounded,
                  key: ValueKey(_showQuickMenu),
                  color: Colors.white, size: 30),
              ),
            ),
          ),
        ),
      )),
    ]),
  );

  // ── Bottom action area ──────────────────────────────────────────────────────

  Widget _buildBottomActionArea() => Positioned(
    bottom: 0, left: 0, right: 0,
    child: ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xE60D0804),
            border: Border(top: BorderSide(color: CafeTheme.primaryBrown, width: 1.5)),
            boxShadow: [BoxShadow(
              color: Color(0x665F3814), blurRadius: 30, offset: Offset(0, -5))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _buildActiveOrdersTracker(),
            _buildBasketRow(),
            _buildCheckoutBar(),
          ]),
        ),
      ),
    ),
  );

  Widget _buildActiveOrdersTracker() {
    if (_registeredName == null) return const SizedBox();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders')
          .where('customer_name', isEqualTo: _registeredName).snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox();
        final orders = snap.data!.docs;
        return SizedBox(
          height: 125,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            itemCount: orders.length,
            itemBuilder: (_, i) {
              final data = orders[i].data() as Map<String, dynamic>;
              final status = data['status'] ?? "قيد الانتظار";
              final sColor = status == "جاهز" ? Colors.greenAccent
                  : status == "جاري التجهيز" ? Colors.orangeAccent : Colors.white54;
              final icon = status == "جاهز" ? Icons.check_circle_rounded
                  : status == "جاري التجهيز" ? Icons.local_cafe_rounded : Icons.hourglass_top_rounded;
              return Container(
                width: 170,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0x0DFFFFFF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sColor.withValues(alpha: 0.6), width: 1.5),
                  boxShadow: [BoxShadow(color: sColor.withValues(alpha: 0.12), blurRadius: 12)],
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, color: sColor, size: 28),
                  const SizedBox(height: 8),
                  Text(status, style: TextStyle(
                    color: sColor, fontWeight: FontWeight.w900, fontSize: 14)),
                  if (data['items_with_qty'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text("${(data['items_with_qty'] as List).length} صنف",
                        style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                ]),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBasketRow() {
    if (_basket.isEmpty) return const SizedBox();
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(top: 14, left: 24, right: 24),
        itemCount: _basket.length,
        itemBuilder: (_, i) => Container(
          width: 170,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0x0DFFFFFF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x735F3814), width: 1.5),
            boxShadow: const [BoxShadow(color: Color(0x1F5F3814), blurRadius: 10)],
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(_basket[i]['name'],
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 24),
                onPressed: () => setState(() {
                  if (_basket[i]['quantity'] > 1) _basket[i]['quantity']--;
                  else _basket.removeAt(i);
                }),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text("${_basket[i]['quantity']}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.greenAccent, size: 24),
                onPressed: () => setState(() => _basket[i]['quantity']++),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
            if (_basket[i]['note'] != "بدون إضافات")
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 8, right: 8),
                child: Text("📝 ${_basket[i]['note']}",
                  style: const TextStyle(fontSize: 11, color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ),
    );
  }

  Widget _buildCheckoutBar() {
    final total = _basket.fold<double>(0.0,
      (p, e) => p + (e['price'] as num) * (e['quantity'] as num));
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 20, 30, 50),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("المبلغ الحالي",
            style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold)),
          Text("${total.toStringAsFixed(2)} ج.م",
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
              color: CafeTheme.accent, letterSpacing: 1)),
          if (_basket.isNotEmpty)
            Text("${_basket.length} صنف",
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ]),
        Column(children: [
          Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(18)),
              boxShadow: [BoxShadow(
                color: Color(0x805F3814), blurRadius: 20, offset: Offset(0, 4))],
            ),
            child: ElevatedButton(
              onPressed: _basket.isEmpty ? null : _sendOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: CafeTheme.primaryBrown,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0),
              child: const Text("تأكيد الطلب ⚡",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            ),
          ),
          if (_basket.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton.icon(
                onPressed: () {
                  setState(() => _basket.clear());
                  _showSnack("تم مسح السلة", Colors.redAccent);
                },
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                label: const Text("مسح السلة",
                  style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
        ]),
      ]),
    );
  }

  // ── Add dialog ──────────────────────────────────────────────────────────────

  void _showAddDialog(Map<String, dynamic> item) {
    _noteController.clear();
    List<dynamic>? sizes = item['sizes'];
    Map<String, dynamic>? selectedSize =
        (sizes != null && sizes.isNotEmpty) ? sizes.first : null;
    double currentPrice = selectedSize != null
        ? (selectedSize['price'] as num).toDouble()
        : (item['price'] as num).toDouble();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
        backgroundColor: CafeTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: CafeTheme.primaryBrown.withValues(alpha: 0.7), width: 1.5)),
        title: Text("تخصيص ${item['name']}", textAlign: TextAlign.right,
          style: const TextStyle(color: CafeTheme.secondaryBrown, fontSize: 18, fontWeight: FontWeight.w900)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (sizes != null && sizes.isNotEmpty) ...[
            const Text("اختر الحجم:", textAlign: TextAlign.right,
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10, runSpacing: 10, alignment: WrapAlignment.end,
              children: sizes.map((s) {
                final sel = selectedSize == s;
                return ChoiceChip(
                  label: Text("${s['name']} - ${s['price']} ج.م"),
                  selected: sel,
                  selectedColor: CafeTheme.primaryBrown,
                  backgroundColor: const Color(0x14FFFFFF),
                  labelStyle: TextStyle(
                    color: sel ? Colors.black : Colors.white, fontWeight: FontWeight.w900),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: sel ? CafeTheme.primaryBrown : Colors.transparent)),
                  onSelected: (v) { if (v) ss(() {
                    selectedSize = s; currentPrice = (s['price'] as num).toDouble(); }); },
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
              hintText: "أي إضافات تحب نجهزها لك؟",
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
              filled: true, fillColor: const Color(0x14FFFFFF),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: CafeTheme.primaryBrown.withValues(alpha: 0.4))),
            ),
          ),
        ]),
        actionsPadding: const EdgeInsets.only(bottom: 20, right: 20, left: 20),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء", style: TextStyle(fontSize: 16))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CafeTheme.primaryBrown,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              setState(() {
                final note = _noteController.text.isEmpty ? "بدون إضافات" : _noteController.text;
                String name = item['name'];
                if (selectedSize != null) name += " (${selectedSize!['name']})";
                final idx = _basket.indexWhere((e) =>
                  e['name'] == name && e['note'] == note && e['price'] == currentPrice);
                if (idx != -1) _basket[idx]['quantity']++;
                else _basket.add({'name': name, 'price': currentPrice,
                  'image_url': item['image_url'], 'note': note, 'quantity': 1});
              });
              Navigator.pop(ctx);
              _showSnack("تمت الإضافة ✨", CafeTheme.primaryBrown);
            },
            child: const Text("إضافة",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
          ),
        ],
      )),
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  void _sendOrder() async {
    if (_basket.isEmpty || _registeredName == null) return;
    try {
      final itemsWithQty = _basket.map((e) => {'name': e['name'], 'qty': e['quantity']}).toList();
      final total = _basket.fold<double>(0, (p, e) => p + (e['price'] as num) * (e['quantity'] as num));
      final note = _basket.any((e) => e['note'] != 'بدون إضافات')
          ? _basket.firstWhere((e) => e['note'] != 'بدون إضافات')['note'] : 'بدون إضافات';

      await apiService.createOrder(
        customerName: _registeredName!, tableNumber: _currentTable ?? '?',
        itemsWithQty: itemsWithQty, totalPrice: total, note: note);

      final lines = _basket.map((e) => '  • ${e['name']} × ${e['quantity']}').join('\n');
      await apiService.sendTelegramMessage(
        '━━━━━━━━━━━━━━━━━━\n☕ طلب جديد — Storm Café\n━━━━━━━━━━━━━━━━━━\n'
        '👤 العميل : $_registeredName\n🪑 الطاولة : $_currentTable\n━━━━━━━━━━━━━━━━━━\n'
        '🛒 الطلبات :\n$lines\n━━━━━━━━━━━━━━━━━━\n'
        '📝 ملاحظة : $note\n💰 الإجمالي : ${total.toStringAsFixed(2)} ج.م\n━━━━━━━━━━━━━━━━━━');

      setState(() => _basket.clear());
      _showSnack('تم إرسال طلبك! 🚀', Colors.greenAccent);
    } catch (_) {
      _showSnack('تعذر إرسال الطلب حالياً، حاول مرة أخرى', Colors.redAccent);
    }
  }

  void _callWaiter() async {
    if (_isWaiterAlertActive || _registeredName == null) return;
    setState(() => _isWaiterAlertActive = true);
    try {
      await apiService.callWaiter(customerName: _registeredName!, tableNumber: _currentTable ?? '?');
      await apiService.sendTelegramMessage(
        '━━━━━━━━━━━━━━━━━━\n🔔 نداء ويتر — Storm Café\n━━━━━━━━━━━━━━━━━━\n'
        '👤 العميل : $_registeredName\n🪑 الطاولة : $_currentTable\n━━━━━━━━━━━━━━━━━━\n'
        '⚡ العميل يطلب مساعدة الويتر الآن!');
      _playWaiterBell();
    } catch (_) {
      setState(() => _isWaiterAlertActive = false);
      _showSnack('تعذر إرسال نداء الويتر حالياً', Colors.redAccent);
    }
  }

  void _requestBill() async {
    if (_registeredName == null) return;
    await apiService.sendTelegramMessage(
      '━━━━━━━━━━━━━━━━━━\n🧾 طلب حساب — Storm Café\n━━━━━━━━━━━━━━━━━━\n'
      '👤 العميل : $_registeredName\n🪑 الطاولة : $_currentTable\n━━━━━━━━━━━━━━━━━━\n'
      '💳 العميل جاهز للدفع!');
    _showSnack('تم طلب الحساب! سيأتي الويتر قريباً 🧾', CafeTheme.success);
  }

  void _changeTableDialog() {
    _tableEntryCtrl.text = _currentTable ?? "";
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: CafeTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: CafeTheme.secondaryBrown, width: 1.5)),
      title: const Text("تغيير الطاولة 🪑", textAlign: TextAlign.center,
        style: TextStyle(color: CafeTheme.secondaryBrown, fontWeight: FontWeight.bold)),
      content: TextField(
        controller: _tableEntryCtrl,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: "رقم الطاولة الجديد",
          filled: true, fillColor: const Color(0x14FFFFFF),
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
          child: const Text("إلغاء", style: TextStyle(fontSize: 16))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: CafeTheme.secondaryBrown,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () {
            if (_tableEntryCtrl.text.isNotEmpty) {
              setState(() => _currentTable = _tableEntryCtrl.text);
              Navigator.pop(context);
              _showSnack("تم تغيير الطاولة إلى ${_tableEntryCtrl.text} 🪑", CafeTheme.secondaryBrown);
            }
          },
          child: const Text("تحديث",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
        ),
      ],
    ));
  }
}

// ── Small stateless helper widgets ─────────────────────────────────────────────

class _EntryField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final bool isNumber;
  const _EntryField({
    required this.ctrl, required this.hint, required this.icon, this.isNumber = false});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    textAlign: TextAlign.center,
    keyboardType: isNumber ? TextInputType.number : TextInputType.text,
    style: const TextStyle(color: Colors.white, fontSize: 16),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0x66FFFFFF)),
      prefixIcon: Icon(icon, color: CafeTheme.accent, size: 22),
      filled: true, fillColor: const Color(0x66000000),
      contentPadding: const EdgeInsets.symmetric(vertical: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
    ),
  );
}

class _AnimatedButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final Color color;
  const _AnimatedButton({required this.onPressed, required this.child, this.color = CafeTheme.primaryBrown});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, height: 65,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(
        color: color.withValues(alpha: 0.4), blurRadius: 25, spreadRadius: 2, offset: const Offset(0, 5))],
    ),
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color, foregroundColor: Colors.black,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x4DFFFFFF))),
        elevation: 0),
      child: child,
    ),
  );
}

class _FabOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _FabOption({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Row(children: [
      Container(
        width: 50, height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.2),
          border: Border.all(color: color.withValues(alpha: 0.7), width: 1.5),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 15)],
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      const SizedBox(width: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xBF000000),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label, style: TextStyle(
          color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    ]),
  );
}

// ── Cinematic Category Carousel ─────────────────────────────────────────────────

class CinematicCategoryCarousel extends StatefulWidget {
  final List<QueryDocumentSnapshot> categories;
  final Function(String) onSelect;
  final String? selectedCategory;

  const CinematicCategoryCarousel({
    super.key,
    required this.categories,
    required this.onSelect,
    required this.selectedCategory,
  });

  @override
  State<CinematicCategoryCarousel> createState() => _CinematicCategoryCarouselState();
}

class _CinematicCategoryCarouselState extends State<CinematicCategoryCarousel> {
  PageController? _pageCtrl;
  double _currentPage = 0;
  bool _isProgrammatic = false;
  double? _lastWidth;

  int get _selectedIdx {
    if (widget.selectedCategory == null) return 0;
    final i = widget.categories.indexWhere(
      (d) => (d['name'] ?? '').toString() == widget.selectedCategory);
    return i >= 0 ? i : 0;
  }

  void _initCtrl(double w) {
    if (_lastWidth == w && _pageCtrl != null) return;
    _lastWidth = w;
    final frac = w < 400 ? 0.42 : w < 600 ? 0.36 : w < 900 ? 0.28 : 0.24;
    _pageCtrl?.dispose();
    _pageCtrl = PageController(viewportFraction: frac, initialPage: _selectedIdx)
      ..addListener(() { if (mounted) setState(() => _currentPage = _pageCtrl!.page ?? 0); });
  }

  @override
  void dispose() { _pageCtrl?.dispose(); super.dispose(); }

  @override
  void didUpdateWidget(covariant CinematicCategoryCarousel old) {
    super.didUpdateWidget(old);
    if (widget.selectedCategory == null || widget.selectedCategory == old.selectedCategory) return;
    final ni = widget.categories.indexWhere(
      (d) => (d['name'] ?? '').toString() == widget.selectedCategory);
    if (ni >= 0 && (_pageCtrl?.hasClients ?? false)) {
      _isProgrammatic = true;
      _pageCtrl!.animateToPage(ni,
        duration: const Duration(milliseconds: 500), curve: Curves.easeInOutCubic)
        .then((_) => _isProgrammatic = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.categories;
    final sw = MediaQuery.of(context).size.width;
    _initCtrl(sw);
    if (cats.isEmpty) return const SizedBox(height: 250);

    final h    = sw < 400 ? 270.0 : sw < 600 ? 260.0 : 240.0;
    final ico  = sw < 400 ? 55.0  : sw < 600 ? 50.0  : 48.0;
    final fsA  = 18.0;
    final fsI  = 15.0;

    return SizedBox(
      height: h,
      child: Stack(alignment: Alignment.center, children: [
        Positioned(
          left: 24, right: 24, bottom: 12,
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: const Color(0x665F3814)),
              gradient: const LinearGradient(colors: [
                Colors.transparent, Color(0x405F3814), Colors.transparent]),
              boxShadow: const [BoxShadow(
                color: Color(0x405F3814), blurRadius: 25, spreadRadius: 2)],
            ),
          ),
        ),
        RepaintBoundary(child: PageView.builder(
          controller: _pageCtrl!,
          itemCount: cats.length,
          physics: const BouncingScrollPhysics(decelerationRate: ScrollDecelerationRate.fast),
          padEnds: true,
          onPageChanged: (i) {
            if (_isProgrammatic) return;
            final n = (cats[i]['name'] ?? '').toString();
            if (n != widget.selectedCategory) widget.onSelect(n);
          },
          itemBuilder: (_, i) {
            final n = (cats[i]['name'] ?? '').toString();
            final sd = (_currentPage - i);
            final diff = sd.abs();
            final scale   = (1 - diff * 0.13).clamp(0.80, 1.0);
            final opacity = (1 - diff * 0.20).clamp(0.25, 1.0);
            final drop    = (diff * diff * 12).clamp(0.0, 24.0);
            final yRot    = (sd * 0.20).clamp(-0.50, 0.50);
            final isSel   = widget.selectedCategory == n;
            final active  = diff < 0.60 || isSel;

            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..translate(0.0, drop)
                ..rotateY(-yRot),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: _CategoryCard(
                    name: n, icon: _categoryIconByName(n),
                    isSelected: isSel, active: active,
                    iconSize: ico, fontSizeActive: fsA, fontSizeInactive: fsI,
                    onTap: () => widget.onSelect(n),
                  ),
                ),
              ),
            );
          },
        )),
      ]),
    );
  }
}

class _CategoryCard extends StatefulWidget {
  final String name;
  final IconData icon;
  final bool isSelected;
  final bool active;
  final double iconSize;
  final double fontSizeActive;
  final double fontSizeInactive;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.name, required this.icon, required this.isSelected,
    required this.active, required this.iconSize, required this.fontSizeActive,
    required this.fontSizeInactive, required this.onTap,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit:  (_) => setState(() => _hovered = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        transform: Matrix4.translationValues(0, _hovered ? -5 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: widget.isSelected ? null : const Color(0x4D000000),
          gradient: widget.isSelected ? LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [
              const Color(0xF57A4D2A),
              CafeTheme.primaryBrown.withValues(alpha: 0.90),
              const Color(0xE05F3814),
            ]) : null,
          border: Border.all(
            color: widget.isSelected
                ? const Color(0xB2987B5C)
                : CafeTheme.primaryBrown.withValues(alpha: _hovered ? 0.4 : 0.2),
            width: widget.isSelected ? 2.0 : 1.2),
          boxShadow: widget.isSelected ? const [
            BoxShadow(color: Color(0x59C49A6D), blurRadius: 45, spreadRadius: 2),
            BoxShadow(color: Color(0x4D5F3814), blurRadius: 30, spreadRadius: 1),
          ] : [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(widget.icon,
              size: widget.active ? widget.iconSize : widget.iconSize - 8,
              color: widget.isSelected ? CafeTheme.textMain
                  : CafeTheme.primaryBrown.withValues(alpha: 0.8)),
            const SizedBox(height: 14),
            Text(widget.name,
              textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w900, letterSpacing: 1.0,
                fontSize: widget.active ? widget.fontSizeActive : widget.fontSizeInactive,
                color: widget.isSelected ? Colors.white : Colors.white70)),
          ]),
        ),
      ),
    ),
  );
}

// ── Product Section ─────────────────────────────────────────────────────────────

class UFOBeamProductSection extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String categoryName;
  final Function(Map<String, dynamic>) onAddItem;
  final Function(int, bool) onQuantityChange;
  final List<Map<String, dynamic>> basket;

  const UFOBeamProductSection({
    super.key,
    required this.items,
    required this.categoryName,
    required this.onAddItem,
    required this.onQuantityChange,
    required this.basket,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          final name = item['name'] ?? '';
          final bIdx = basket.indexWhere((e) => e['name'] == name);
          final inBasket = bIdx != -1;
          return RepaintBoundary(
            child: _NeonProductCard(
              key: ValueKey('${categoryName}_$name'),
              item: item, inBasket: inBasket,
              qty: inBasket ? (basket[bIdx]['quantity'] as int) : 0,
              onAdd: () => onAddItem(item),
              onMinus: inBasket ? () => onQuantityChange(bIdx, false) : null,
              onPlus:  inBasket ? () => onQuantityChange(bIdx, true)  : null,
            ),
          );
        },
      ),
    );
  }
}

// ── Product Card ────────────────────────────────────────────────────────────────

class _NeonProductCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool inBasket;
  final int qty;
  final VoidCallback onAdd;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  const _NeonProductCard({
    super.key, required this.item, required this.inBasket,
    required this.qty, required this.onAdd, required this.onMinus, required this.onPlus,
  });

  @override
  State<_NeonProductCard> createState() => _NeonProductCardState();
}

class _NeonProductCardState extends State<_NeonProductCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burstCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 700))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _showBurst = false);
        _burstCtrl.reset();
      }
    });

  bool _showBurst = false;
  bool _isHovered = false;
  final _particles = <_Particle>[];
  final _rng = math.Random();

  @override
  void dispose() { _burstCtrl.dispose(); super.dispose(); }

  void _triggerBurst() {
    _particles.clear();
    final colors = [CafeTheme.primaryBrown, CafeTheme.secondaryBrown,
      CafeTheme.success, Colors.white, const Color(0xFFD4A96A)];
    for (int i = 0; i < 20; i++) {
      _particles.add(_Particle(
        angle: (i / 20) * math.pi * 2 + _rng.nextDouble() * 0.4,
        speed: 45 + _rng.nextDouble() * 60,
        size:  4  + _rng.nextDouble() * 5,
        color: colors[i % 5],
      ));
    }
    setState(() => _showBurst = true);
    _burstCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.item['name'] ?? '';
    final hasSizes = widget.item['sizes'] != null && (widget.item['sizes'] as List).isNotEmpty;
    final priceText = hasSizes ? 'أحجام متعددة' : '${widget.item['price']} ج.م';
    final ib = widget.inBasket;
    final ac = ib ? CafeTheme.success : CafeTheme.primaryBrown;
    final acD = ib ? const Color(0xFF4CAF50) : const Color(0xFF7A4D2A);

    return Stack(clipBehavior: Clip.none, children: [
      MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit:  (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 20),
          transform: Matrix4.translationValues(0, _isHovered && !ib ? -4 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.centerRight, end: Alignment.centerLeft,
              colors: ib ? const [Color(0xCC1A2A10), Color(0xCC0D1A05), Color(0xE60D0804)]
                  : _isHovered ? const [Color(0xCC251505), Color(0xCC3A2815), Color(0xE6120A02)]
                  : const [Color(0xB21A0F05), Color(0xB22E1F10), Color(0xCC0D0804)]),
            border: Border.all(
              color: ac.withValues(alpha: ib ? 0.80 : (_isHovered ? 0.50 : 0.25)),
              width: ib ? 2.0 : (_isHovered ? 1.5 : 1.2)),
            boxShadow: [BoxShadow(
              color: ac.withValues(alpha: ib ? 0.35 : (_isHovered ? 0.20 : 0.05)),
              blurRadius: ib ? 25 : (_isHovered ? 18 : 10),
              spreadRadius: ib ? 2 : 0, offset: const Offset(0, 5))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 6, height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [ac, acD]),
                  boxShadow: [BoxShadow(color: ac.withValues(alpha: 0.8), blurRadius: 10, spreadRadius: 2)],
                ),
              ),
              const SizedBox(width: 18),
              _buildItemImage(widget.item),
              const SizedBox(width: 20),
              Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ib ? Colors.white : const Color(0xF2FFFFFF),
                      fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: hasSizes ? const Color(0x26FF9800) : const Color(0x264CAF50),
                      border: Border.all(
                        color: hasSizes ? const Color(0x73FF9800) : const Color(0x734CAF50))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(hasSizes ? Icons.tune_rounded : Icons.payments_outlined,
                        size: 13, color: hasSizes ? Colors.orangeAccent : CafeTheme.success),
                      const SizedBox(width: 6),
                      Text(priceText, style: TextStyle(
                        color: hasSizes ? Colors.orangeAccent : CafeTheme.success,
                        fontWeight: FontWeight.w900, fontSize: 14)),
                    ]),
                  ),
                ]),
              )),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: ib
                  ? _QuantityControl(qty: widget.qty, onMinus: widget.onMinus!, onPlus: widget.onPlus!)
                  : GestureDetector(
                      onTap: () { widget.onAdd(); _triggerBurst(); },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                            colors: [CafeTheme.primaryBrown, Color(0xFF3D2410), CafeTheme.secondaryBrown]),
                          boxShadow: [BoxShadow(
                            color: CafeTheme.primaryBrown.withValues(alpha: _isHovered ? 0.85 : 0.60),
                            blurRadius: _isHovered ? 22 : 15, offset: const Offset(0, 5))],
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                      ),
                    ),
              ),
            ]),
          ),
        ),
      ),
      if (ib) Positioned(
        top: -8, right: 20,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(colors: [CafeTheme.success, Color(0xFF4CAF50)]),
            boxShadow: const [BoxShadow(color: Color(0x994CAF50), blurRadius: 10, offset: Offset(0, 2))],
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_rounded, size: 12, color: Colors.black),
            SizedBox(width: 5),
            Text('في السلة', style: TextStyle(
              color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ]),
        ),
      ),
      if (_showBurst) Positioned(
        left: 0, right: 0, top: 0, bottom: 20,
        child: IgnorePointer(child: AnimatedBuilder(
          animation: _burstCtrl,
          builder: (_, __) => CustomPaint(
            painter: _ParticleBurstPainter(particles: _particles, progress: _burstCtrl.value)),
        )),
      ),
    ]);
  }

  Widget _buildItemImage(Map<String, dynamic> item) {
    final url = item['image_url'] as String?;
    if (url != null && url.isNotEmpty) {
      return Container(
        width: 95, height: 95,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x405F3814), blurRadius: 15, offset: Offset(0, 5))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.network(url, width: 95, height: 95, fit: BoxFit.cover,
            cacheWidth: 190, cacheHeight: 190,
            loadingBuilder: (_, child, prog) => prog == null ? child
                : Container(width: 95, height: 95, color: CafeTheme.surface,
                    child: Center(child: SizedBox(width: 24, height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: CafeTheme.accent.withValues(alpha: 0.6))))),
            errorBuilder: (_, __, ___) => _fallbackIcon()),
        ),
      );
    }
    return _fallbackIcon();
  }

  Widget _fallbackIcon() => Container(
    width: 95, height: 95,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [CafeTheme.primaryBrown.withValues(alpha: 0.25), CafeTheme.secondaryBrown.withValues(alpha: 0.15)]),
      border: Border.all(color: CafeTheme.primaryBrown.withValues(alpha: 0.40), width: 1.5),
    ),
    child: const Icon(Icons.fastfood_rounded, color: CafeTheme.primaryBrown, size: 40),
  );
}

// ── Particles ───────────────────────────────────────────────────────────────────

class _Particle {
  final double angle, speed, size;
  final Color color;
  const _Particle({required this.angle, required this.speed, required this.size, required this.color});
}

class _ParticleBurstPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  const _ParticleBurstPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final t     = math.sin(progress * math.pi / 2);
    final alpha = progress < 0.5 ? 1.0 : 1.0 - (progress - 0.5) * 2;
    final c     = Offset(size.width / 2, size.height / 2);
    for (final p in particles) {
      final dist = p.speed * t;
      final px = c.dx + math.cos(p.angle) * dist;
      final py = c.dy + math.sin(p.angle) * dist;
      canvas.drawCircle(Offset(px, py), p.size * (1 - progress * 0.5),
        Paint()..color = p.color.withValues(alpha: alpha)
               ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      if (dist > 8) {
        final td = dist - 8;
        canvas.drawLine(
          Offset(c.dx + math.cos(p.angle) * td, c.dy + math.sin(p.angle) * td),
          Offset(px, py),
          Paint()..color = p.color.withValues(alpha: alpha * 0.4)
                 ..strokeWidth = p.size * 0.6..strokeCap = StrokeCap.round);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleBurstPainter old) => old.progress != progress;
}

// ── Quantity control ────────────────────────────────────────────────────────────

class _QuantityControl extends StatelessWidget {
  final int qty;
  final VoidCallback onMinus, onPlus;
  const _QuantityControl({required this.qty, required this.onMinus, required this.onPlus});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      color: const Color(0x14FFFFFF),
      border: Border.all(color: const Color(0x664CAF50), width: 1.5),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      _btn(Icons.remove_rounded, Colors.redAccent, onMinus),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text('$qty', style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18))),
      _btn(Icons.add_rounded, CafeTheme.success, onPlus),
    ]),
  );

  Widget _btn(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.18)),
      child: Icon(icon, color: color, size: 20),
    ),
  );
}

// ── Waiter Terminal ─────────────────────────────────────────────────────────────

class WaiterTerminal extends StatefulWidget {
  const WaiterTerminal({super.key});
  @override
  State<WaiterTerminal> createState() => _WaiterTerminalState();
}

class _WaiterTerminalState extends State<WaiterTerminal> {
  int _tabIdx = 0;
  final _basket    = <Map<String, dynamic>>[];
  final _tableCtrl = TextEditingController();
  final _nameCtrl  = TextEditingController();
  final _searchCtrl= TextEditingController();
  final _noteCtrl  = TextEditingController();
  String? _selectedCat;
  String _searchQ  = "";

  @override
  void dispose() {
    _tableCtrl.dispose(); _nameCtrl.dispose();
    _searchCtrl.dispose(); _noteCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg, Color color) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(
        color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ));

  void _showWaiterAddDialog(Map<String, dynamic> item) {
    _noteCtrl.clear();
    List<dynamic>? sizes = item['sizes'];
    Map<String, dynamic>? selSize = (sizes != null && sizes.isNotEmpty) ? sizes.first : null;
    double price = selSize != null ? (selSize['price'] as num).toDouble()
        : (item['price'] as num).toDouble();

    showDialog(context: context, builder: (_) => StatefulBuilder(
      builder: (ctx, ss) => AlertDialog(
        backgroundColor: CafeTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: CafeTheme.secondaryBrown.withValues(alpha: 0.7), width: 1.5)),
        title: Text("إضافة ${item['name']}", textAlign: TextAlign.right,
          style: const TextStyle(color: CafeTheme.secondaryBrown, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (sizes != null && sizes.isNotEmpty) ...[
            const Text("اختر الحجم:", textAlign: TextAlign.right,
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.end,
              children: sizes.map((s) {
                final sel = selSize == s;
                return ChoiceChip(
                  label: Text("${s['name']} - ${s['price']} ج.م"), selected: sel,
                  selectedColor: CafeTheme.secondaryBrown,
                  backgroundColor: const Color(0x14FFFFFF),
                  labelStyle: TextStyle(color: sel ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                  onSelected: (v) { if (v) ss(() { selSize = s; price = (s['price'] as num).toDouble(); }); },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
          TextField(
            controller: _noteCtrl, textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "ملاحظات (سكر زيادة، بدون ثلج...)",
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
              filled: true, fillColor: const Color(0x14FFFFFF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: CafeTheme.secondaryBrown.withValues(alpha: 0.4))),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء", style: TextStyle(fontSize: 16))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CafeTheme.secondaryBrown,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              setState(() {
                final note = _noteCtrl.text.isEmpty ? "بدون ملاحظات" : _noteCtrl.text;
                String name = item['name'];
                if (selSize != null) name += " (${selSize!['name']})";
                final idx = _basket.indexWhere((e) =>
                  e['name'] == name && e['note'] == note && e['price'] == price);
                if (idx != -1) _basket[idx]['qty']++;
                else _basket.add({'name': name, 'price': price, 'note': note, 'qty': 1});
              });
              Navigator.pop(ctx);
            },
            child: const Text("إضافة",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
          ),
        ],
      ),
    ));
  }

  void _sendToBarista() async {
    final table = _tableCtrl.text.trim();
    final cname = _nameCtrl.text.trim();
    if (_basket.isEmpty) { _showSnack('السلة فارغة!', Colors.orangeAccent); return; }
    if (table.isEmpty || cname.isEmpty) {
      _showSnack('يرجى إدخال رقم الطاولة واسم العميل', Colors.orangeAccent); return;
    }
    final itemsWithQty = _basket.map((e) => {'name': e['name'], 'qty': e['qty']}).toList();
    final total = _basket.fold<double>(0, (p, e) => p + (e['price'] as num) * (e['qty'] as num));
    final note = _basket.any((e) => e['note'] != 'بدون ملاحظات')
        ? _basket.firstWhere((e) => e['note'] != 'بدون ملاحظات')['note'] : 'بدون ملاحظات';
    try {
      await apiService.createWaiterOrder(customerName: cname, tableNumber: table,
        itemsWithQty: itemsWithQty, totalPrice: total, note: note);
      final lines = _basket.map((e) => '  • ${e['name']} × ${e['qty']}').join('\n');
      await apiService.sendTelegramMessage(
        '━━━━━━━━━━━━━━━━━━\n🤵 طلب ويتر — Storm Café\n━━━━━━━━━━━━━━━━━━\n'
        '👤 العميل : $cname\n🪑 الطاولة : $table\n━━━━━━━━━━━━━━━━━━\n'
        '🛒 الطلبات :\n$lines\n━━━━━━━━━━━━━━━━━━\n'
        '📝 ملاحظة : $note\n💰 الإجمالي : ${total.toStringAsFixed(2)} ج.م\n━━━━━━━━━━━━━━━━━━');
      setState(() => _basket.clear());
      _showSnack('تم إرسال الطلب للباريستا! ✅', Colors.greenAccent);
    } catch (e) {
      if (e is ApiException && e.statusCode == 401)
        _showSnack('انتهت صلاحية الجلسة — يرجى تسجيل الدخول مجدداً', Colors.red);
      else _showSnack('تعذر إرسال الطلب الآن، حاول مرة أخرى', Colors.redAccent);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: CafeTheme.surface,
        title: const Text("لوحة الويتر 🤵", style: TextStyle(
          color: CafeTheme.secondaryBrown, fontWeight: FontWeight.w900, fontSize: 20)),
        elevation: 5,
        shadowColor: const Color(0x4D5F3814),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: CafeTheme.surface,
        selectedItemColor: CafeTheme.primaryBrown,
        unselectedItemColor: Colors.white54,
        currentIndex: _tabIdx,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        onTap: (i) => setState(() => _tabIdx = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.point_of_sale), label: "نقطة البيع (POS)"),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: "إدارة الطلبات"),
        ],
      ),
      body: _tabIdx == 0 ? _buildPOSView() : _buildOrdersView(),
    ),
  );

  Widget _buildPOSView() => Column(children: [
    Padding(
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        Expanded(child: TextField(
          controller: _tableCtrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: "رقم الطاولة",
            labelStyle: const TextStyle(color: CafeTheme.secondaryBrown),
            filled: true, fillColor: const Color(0x14FFFFFF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
        )),
        const SizedBox(width: 16),
        Expanded(child: TextField(
          controller: _nameCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: "اسم العميل",
            labelStyle: const TextStyle(color: CafeTheme.secondaryBrown),
            filled: true, fillColor: const Color(0x14FFFFFF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
        )),
      ]),
    ),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _searchQ = v),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "ابحث عن منتج...",
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: CafeTheme.secondaryBrown),
          filled: true, fillColor: const Color(0x14FFFFFF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
      ),
    ),
    const SizedBox(height: 16),
    SizedBox(
      height: 45,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('categories').snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const SizedBox();
          final cats = snap.data!.docs.toList()
            ..sort((a, b) {
              final ai = (a.data() as Map<String, dynamic>)['index'] ?? 999;
              final bi = (b.data() as Map<String, dynamic>)['index'] ?? 999;
              return (ai as num).compareTo(bi as num);
            });
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: cats.length + 1,
            itemBuilder: (_, i) {
              final isAll = i == 0;
              final cn = isAll ? null : cats[i - 1]['name'] as String?;
              final sel = _selectedCat == cn;
              return GestureDetector(
                onTap: () => setState(() => _selectedCat = cn),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? CafeTheme.secondaryBrown : const Color(0x14FFFFFF),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: sel ? CafeTheme.secondaryBrown : Colors.transparent)),
                  child: Center(child: Text(isAll ? "الكل" : (cn ?? ""),
                    style: TextStyle(
                      color: sel ? Colors.black : Colors.white70,
                      fontWeight: FontWeight.w900, fontSize: 14))),
                ),
              );
            },
          );
        },
      ),
    ),
    const SizedBox(height: 16),
    Expanded(child: StreamBuilder<QuerySnapshot>(
      stream: _selectedCat == null
          ? FirebaseFirestore.instance.collection('products').snapshots()
          : FirebaseFirestore.instance.collection('products')
              .where('cat', isEqualTo: _selectedCat).snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(
          child: CircularProgressIndicator(color: CafeTheme.secondaryBrown));
        final items = snap.data!.docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return (data['name'] ?? '').toString().contains(_searchQ);
        }).toList();
        final sw = MediaQuery.of(ctx).size.width;
        return GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: sw < 600 ? 2 : 4,
            childAspectRatio: sw < 600 ? 0.85 : 1.0,
            crossAxisSpacing: 16, mainAxisSpacing: 16),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final item = items[i].data() as Map<String, dynamic>;
            return GestureDetector(
              onTap: () => _showWaiterAddDialog(item),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0x1FFFFFFF), Color(0x0DFFFFFF)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0x99C49A6D), width: 1.5),
                  boxShadow: const [BoxShadow(
                    color: Color(0x26C49A6D), blurRadius: 15, spreadRadius: 1, offset: Offset(0, 4))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(child:
                      item['image_url'] != null && item['image_url'].toString().isNotEmpty
                        ? Image.network(item['image_url'], fit: BoxFit.cover,
                            width: double.infinity, cacheWidth: 400,
                            errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, color: CafeTheme.accent, size: 45))
                        : const Icon(Icons.fastfood, color: CafeTheme.accent, size: 45)
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xD9000000),
                        border: Border(top: BorderSide(color: Color(0x66C49A6D), width: 1.5))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                        Text(item['name'] ?? "",
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.white),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Text("${item['price']} ج.م",
                          style: const TextStyle(color: CafeTheme.accent, fontWeight: FontWeight.w900, fontSize: 14)),
                      ]),
                    ),
                  ]),
                ),
              ),
            );
          },
        );
      },
    )),
    if (_basket.isNotEmpty) _buildBasketSummary(),
  ]);

  Widget _buildBasketSummary() => Container(
    padding: const EdgeInsets.all(24),
    decoration: const BoxDecoration(
      color: CafeTheme.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      border: Border(top: BorderSide(color: CafeTheme.primaryBrown, width: 1.5)),
      boxShadow: [BoxShadow(color: Color(0x4D5F3814), blurRadius: 20, offset: Offset(0, -5))],
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 250),
        child: ListView.builder(
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          itemCount: _basket.length,
          itemBuilder: (_, i) {
            final item = _basket[i];
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(item['name'],
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 24),
                    onPressed: () => setState(() {
                      if (item['qty'] > 1) item['qty']--;
                      else _basket.removeAt(i);
                    }),
                  ),
                  Text("${item['qty']}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.greenAccent, size: 24),
                    onPressed: () => setState(() => item['qty']++),
                  ),
                ]),
                if (item['note'] != "بدون ملاحظات")
                  Text("📝 ${item['note']}", style: const TextStyle(
                    color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold)),
              ]),
            );
          },
        ),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity, height: 55,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: CafeTheme.secondaryBrown,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 5, shadowColor: const Color(0x80987B5C)),
          onPressed: _sendToBarista,
          child: const Text("إرسال الطلب للباريستا",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
        ),
      ),
    ]),
  );

  Widget _buildOrdersView() => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('orders').snapshots(),
    builder: (_, snap) {
      if (!snap.hasData) return const Center(
        child: CircularProgressIndicator(color: CafeTheme.secondaryBrown));
      final orders = snap.data!.docs.toList()
        ..sort((a, b) {
          final at = (a.data() as Map<String, dynamic>)['timestamp'];
          final bt = (b.data() as Map<String, dynamic>)['timestamp'];
          if (at == null || bt == null) return 0;
          return (bt as Timestamp).compareTo(at as Timestamp);
        });
      if (orders.isEmpty) return const Center(
        child: Text("لا توجد طلبات", style: TextStyle(color: Colors.white54, fontSize: 18)));

      return ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: orders.length,
        itemBuilder: (_, i) {
          final data = orders[i].data() as Map<String, dynamic>;
          final status = data['status'] ?? "قيد الانتظار";
          final sc = status == "جاهز" ? Colors.greenAccent
              : status == "جاري التجهيز" ? Colors.orangeAccent : Colors.white54;
          final items = data['items_with_qty'] ?? [];
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0x0DFFFFFF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sc.withValues(alpha: 0.5), width: 1.5),
              boxShadow: [BoxShadow(color: sc.withValues(alpha: 0.1), blurRadius: 10)],
            ),
            child: ExpansionTile(
              leading: Icon(Icons.receipt_long_rounded, color: sc, size: 28),
              title: Text("${data['customer_name']} - طاولة ${data['table_number']}",
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              subtitle: Text(status, style: TextStyle(
                color: sc, fontSize: 14, fontWeight: FontWeight.bold)),
              children: [Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  ...items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(item['name'] ?? "", style: const TextStyle(fontSize: 15)),
                      Text("x${item['qty']}", style: const TextStyle(
                        color: CafeTheme.secondaryBrown, fontWeight: FontWeight.w900, fontSize: 16)),
                    ]),
                  )),
                  const Divider(color: Colors.white24, height: 24, thickness: 1),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text("${data['total_price']} ج.م", style: const TextStyle(
                      color: CafeTheme.success, fontWeight: FontWeight.w900, fontSize: 18)),
                    Row(children: [
                      _statusBtn("قيد الانتظار", Colors.white54, status, orders[i].id),
                      const SizedBox(width: 8),
                      _statusBtn("جاري التجهيز", Colors.orangeAccent, status, orders[i].id),
                      const SizedBox(width: 8),
                      _statusBtn("جاهز", Colors.greenAccent, status, orders[i].id),
                    ]),
                  ]),
                ]),
              )],
            ),
          );
        },
      );
    },
  );

  Widget _statusBtn(String label, Color color, String current, String docId) {
    final sel = current == label;
    return Expanded(child: GestureDetector(
      onTap: () async {
        try { await apiService.updateOrder(docId, label); }
        catch (_) { if (mounted) _showSnack('تعذر تحديث الحالة', Colors.redAccent); }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: sel ? color.withValues(alpha: 0.25) : const Color(0x0DFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? color : Colors.white24, width: 1.5),
        ),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(
          color: sel ? color : Colors.white54, fontSize: 12, fontWeight: FontWeight.w900)),
      ),
    ));
  }
}
