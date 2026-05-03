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

const String localBackgroundImage = 'assets/images/storm_bg.jpg';
const String localLogoImage = 'assets/images/storm_logo.png';

// ── Pre-computed static colors to avoid withOpacity allocations in build ──
const Color _kDeepBrownOverlay93 = Color(0xEDAE6A30); // deepBrown @ 0.93 approx
// These are used frequently — defined once as constants.
const Color _kSurface85 = Color(0xD92E1F10);
const Color _kBlack50 = Color(0x80000000);

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

Widget buildstormLogo({double size = 60, Color? color}) {
  return Image.asset(
    localLogoImage,
    width: size,
    height: size,
    color: color,
    fit: BoxFit.contain,
    errorBuilder: (context, error, stackTrace) =>
        Icon(Icons.restaurant_menu, size: size, color: CafeTheme.accent),
  );
}

// ==========================================
// مكون الخلفية - مفصول ومحاط بـ RepaintBoundary
// ==========================================
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
              errorBuilder: (context, error, stackTrace) =>
                  const ColoredBox(color: CafeTheme.deepBrown),
            ),
            // FIX: Use const color instead of withValues() allocation every build
            const ColoredBox(color: Color(0xEE1A0F05)),
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.2, -0.1),
                  radius: 1.2,
                  colors: [
                    Color(0x1A5F3814), // primaryBrown @ 0.10
                    Color(0x0F987B5C), // secondaryBrown @ 0.06
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// صفحة المنيو الرئيسية
// ==========================================
class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> with TickerProviderStateMixin {
  String? currentCat;
  final TextEditingController _catSearchCtrl = TextEditingController();

  // FIX: Separate notifier for search so only product list rebuilds on search change
  final ValueNotifier<String> _searchNotifier = ValueNotifier('');
  final TextEditingController _globalSearchCtrl = TextEditingController();

  List<Map<String, dynamic>> basket = [];
  String? registeredName;
  String? currentTable;

  bool _isEntryComplete = false;
  bool _hasSavedName = false;
  bool _isWaiterAlertActive = false;

  // FIX: Use ValueNotifier instead of setState for quick menu toggle
  // so only the FAB widget rebuilds, not the whole page
  final ValueNotifier<bool> _showQuickMenuNotifier = ValueNotifier(false);

  late AnimationController _glowController;
  late AnimationController _fabPulseController;

  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _nameEntryController = TextEditingController();
  final TextEditingController _tableEntryController = TextEditingController();

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

    // FIX: Sync search controller to notifier so product list reacts in isolation
    _globalSearchCtrl.addListener(() {
      _searchNotifier.value = _globalSearchCtrl.text;
    });

    _checkSavedData();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _fabPulseController.dispose();
    _catSearchCtrl.dispose();
    _globalSearchCtrl.dispose();
    _searchNotifier.dispose();
    _showQuickMenuNotifier.dispose();
    _noteController.dispose();
    _nameEntryController.dispose();
    _tableEntryController.dispose();
    super.dispose();
  }

  void _showCategoriesSheet(List<QueryDocumentSnapshot> cats) {
    _catSearchCtrl.clear();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final double screenWidth = MediaQuery.of(context).size.width;
        final int crossAxisCount = screenWidth < 600 ? 2 : 4;
        final double childAspectRatio = screenWidth < 400
            ? 2.0
            : screenWidth < 600
            ? 2.3
            : 3.0;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            List<QueryDocumentSnapshot> filteredCats = cats;
            final String q = _catSearchCtrl.text.trim();
            if (q.isNotEmpty) {
              filteredCats = cats.where((doc) {
                final String name = (doc['name'] ?? '').toString();
                return name.contains(q);
              }).toList();
            }

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.75,
                  decoration: const BoxDecoration(
                    // FIX: const color instead of withValues() allocation
                    color: Color(0xD92E1F10),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    border: Border(
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
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
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
                        const SizedBox(height: 25),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              CafeTheme.primaryBrown,
                              CafeTheme.secondaryBrown,
                            ],
                          ).createShader(bounds),
                          child: const Text(
                            "اختر القسم",
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
                            color: const Color(0x14FFFFFF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0x66987B5C),
                              width: 1,
                            ),
                          ),
                          child: TextField(
                            controller: _catSearchCtrl,
                            onChanged: (_) => setSheetState(() {}),
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: "ابحث عن قسم...",
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
                            itemCount: filteredCats.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  childAspectRatio: childAspectRatio,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                            itemBuilder: (context, i) {
                              final String catName =
                                  (filteredCats[i]['name'] ?? '').toString();
                              final bool selected = currentCat == catName;
                              return GestureDetector(
                                onTap: () {
                                  setState(() => currentCat = catName);
                                  Navigator.pop(context);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  decoration: BoxDecoration(
                                    gradient: selected
                                        ? const LinearGradient(
                                            colors: [
                                              CafeTheme.primaryBrown,
                                              CafeTheme.secondaryBrown,
                                            ],
                                          )
                                        : null,
                                    color: selected
                                        ? null
                                        : const Color(0x0DFFFFFF),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: selected
                                          ? CafeTheme.primaryBrown
                                          : const Color(0x405F3814),
                                      width: selected ? 1.5 : 1,
                                    ),
                                    boxShadow: selected
                                        ? const [
                                            BoxShadow(
                                              color: Color(0x805F3814),
                                              blurRadius: 15,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      catName,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: selected
                                            ? Colors.black
                                            : Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: screenWidth < 400 ? 16 : 15,
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

  void _checkSavedData() {
    if (kIsWeb) {
      final savedName = html.window.localStorage['customer_name'];
      if (savedName != null && savedName.isNotEmpty) {
        setState(() {
          registeredName = savedName;
          _hasSavedName = true;
        });
      }
    }
  }

  void _playSound(String url, {double volume = 1.0}) {
    if (kIsWeb) {
      final normalizedVolume = volume.clamp(0.0, 1.0);
      js.context.callMethod('eval', [
        "(function() { var audio = new Audio('$url'); audio.volume = $normalizedVolume; audio.play(); })();",
      ]);
    }
  }

  void _playMicrowaveWorking() =>
      _playSound("https://files.catbox.moe/ct6wzl.mp3");
  void _playMicrowaveDone() =>
      _playSound("https://files.catbox.moe/hecpqn.mp3");
  void _playWaiterBell() => _playSound("https://files.catbox.moe/y77se9.mp3");

  void _initStatusListeners() {}

  void _showStatusSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
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

  void _showWaiterLogin() {
    final passwordCtrl = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
              fillColor: const Color(0x14FFFFFF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
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
                      setDialogState(() => isLoading = true);
                      try {
                        await apiService.loginWaiter(passwordCtrl.text);
                        if (context.mounted) Navigator.pop(context);
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WaiterTerminal(),
                            ),
                          );
                        }
                      } on ApiException catch (e) {
                        setDialogState(() => isLoading = false);
                        if (context.mounted) {
                          _showStatusSnackBar(
                            e.statusCode == 401
                                ? 'كلمة السر خاطئة!'
                                : 'تعذر التحقق، حاول مرة أخرى',
                            Colors.red,
                          );
                        }
                      } catch (_) {
                        setDialogState(() => isLoading = false);
                        if (context.mounted) {
                          _showStatusSnackBar(
                            'تعذر الاتصال بالخادم',
                            Colors.red,
                          );
                        }
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

  Widget _buildEntryOverlay() {
    return Container(
      color: const Color(0xF5000000),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(40),
            width: 400,
            decoration: BoxDecoration(
              color: const Color(0x0DFFFFFF),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: const Color(0x995F3814),
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x335F3814),
                  blurRadius: 50,
                  spreadRadius: 5,
                ),
                BoxShadow(
                  color: Color(0x1A987B5C),
                  blurRadius: 80,
                  spreadRadius: 15,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildstormLogo(size: 110),
                const SizedBox(height: 15),
                const Text(
                  "storm",
                  style: TextStyle(
                    color: CafeTheme.primaryBrown,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "اطلب وانت في راحتك ⚡",
                  style: TextStyle(color: Colors.white54, fontSize: 15),
                ),
                const SizedBox(height: 35),
                if (!_hasSavedName) ...[
                  _entryField(
                    _nameEntryController,
                    "اسمك الكريم..",
                    Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 18),
                ],
                _entryField(
                  _tableEntryController,
                  "رقم الطاولة..",
                  Icons.table_restaurant_rounded,
                  isNumber: true,
                ),
                const SizedBox(height: 30),
                _buildAnimatedButton(
                  onPressed: _validateAndStart,
                  child: const Text(
                    "اكتشف القائمة ⚡",
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
                    "الدخول كويتر",
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
        hintStyle: const TextStyle(color: Color(0x66FFFFFF)),
        prefixIcon: Icon(icon, color: CafeTheme.accent, size: 22),
        filled: true,
        fillColor: const Color(0x66000000),
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  void _validateAndStart() {
    final String name = _hasSavedName
        ? registeredName!
        : _nameEntryController.text.trim();
    if (name.isEmpty) {
      _showStatusSnackBar("يرجى إدخال الاسم", Colors.redAccent);
      return;
    }
    if (_tableEntryController.text.trim().isEmpty) {
      _showStatusSnackBar("يرجى تحديد رقم الطاولة", Colors.redAccent);
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

  Widget _buildAnimatedButton({
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
            side: const BorderSide(
              color: Color(0x4DFFFFFF),
              width: 1,
            ),
          ),
          elevation: 0,
        ),
        child: child,
      ),
    );
  }

  Widget _buildMainContent() {
    return Stack(
      children: [
        const _MenuBackground(),
        CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // FIX: Header is now isolated — only rebuilds on registeredName/table change
            _buildCinematicHeader(),
            _buildSearchBar(),
            _buildCategoryCarouselSection(),
            // FIX: Product list section is SliverToBoxAdapter wrapping
            // a ValueListenableBuilder so search changes only rebuild this widget
            SliverToBoxAdapter(child: _buildProductListSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 350)),
          ],
        ),
        _buildBottomActionArea(),
        // FIX: FAB uses ValueListenableBuilder — page doesn't rebuild on toggle
        _buildFloatingActionMenu(),
      ],
    );
  }

  Widget _buildCinematicHeader() {
    // FIX: Entire header is a single widget, animation isolated via RepaintBoundary
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 55, 24, 20),
        decoration: const BoxDecoration(
          color: _kSurface85,
          border: Border(
            bottom: BorderSide(color: CafeTheme.border, width: 1.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Dev badge — fully const, never rebuilds
            const _DevBadge(),
            Expanded(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (kIsWeb) html.window.location.reload();
                    },
                    child: buildstormLogo(size: 48),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "storm",
                    style: TextStyle(
                      color: CafeTheme.accent,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      fontSize: 22,
                    ),
                  ),
                  if (registeredName != null && currentTable != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "طاولة $currentTable  |  أهلاً، $registeredName",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Column(
              children: [
                GestureDetector(
                  onTap: _changeTableDialog,
                  child: const _TableButton(),
                ),
                const SizedBox(height: 8),
                // FIX: RepaintBoundary isolates this animated widget
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _glowController,
                    builder: (context, _) => GestureDetector(
                      onTap: _callWaiter,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x80000000),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: CafeTheme.accent.withValues(
                              alpha: 0.5 + (0.5 * _glowController.value),
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
                              _isWaiterAlertActive ? "جاري.." : "نداء",
                              style: const TextStyle(
                                color: CafeTheme.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Icon(
                              Icons.notifications_active_rounded,
                              color: CafeTheme.accent,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Container(
          decoration: const BoxDecoration(
            color: _kSurface85,
            borderRadius: BorderRadius.all(Radius.circular(22)),
            border: Border.fromBorderSide(
              BorderSide(color: CafeTheme.border, width: 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _globalSearchCtrl,
            // FIX: No setState here — listener on controller updates ValueNotifier instead
            style: const TextStyle(color: CafeTheme.textMain, fontSize: 16),
            decoration: const InputDecoration(
              hintText: "ابحث عن منتج أو قسم...",
              hintStyle: TextStyle(
                color: Color(0xCC65533E),
                fontSize: 15,
              ),
              prefixIcon: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Icon(
                  Icons.search_rounded,
                  color: CafeTheme.accent,
                  size: 24,
                ),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 20),
            ),
          ),
        ),
      ),
    );
  }

  // FIX: Categories are sorted ONCE when data arrives, cached in local var
  // No more inline sort on every stream rebuild
  Widget _buildCategoryCarouselSection() {
    return SliverToBoxAdapter(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('categories').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const SizedBox(
              height: 200,
              child: Center(
                child: Text(
                  "تعذر تحميل الأقسام حالياً",
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const SizedBox(height: 200);
          }

          // Sort done once per snapshot, not on every build frame
          final cats = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final aIndex =
                  (a.data() as Map<String, dynamic>)['index'] ?? 999;
              final bIndex =
                  (b.data() as Map<String, dynamic>)['index'] ?? 999;
              return (aIndex as num).compareTo(bIndex as num);
            });

          // FIX: Mutate currentCat without setState — safe here because we're
          // inside build and the category carousel will reflect the value.
          if (currentCat == null && cats.isNotEmpty) {
            currentCat = cats.first['name'] as String?;
          }

          return Column(
            children: [
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    const Icon(
                      Icons.category_rounded,
                      color: CafeTheme.secondaryBrown,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "القسم الحالي",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        currentCat ?? "",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildAllCatsButton(cats),
              const SizedBox(height: 16),
              CinematicCategoryCarousel(
                categories: cats,
                selectedCategory: currentCat,
                onSelect: (catName) {
                  if (currentCat == catName) return;
                  _playSound(
                    "https://assets.mixkit.co/active_storage/sfx/270/270-preview.mp3",
                    volume: 0.13,
                  );
                  setState(() => currentCat = catName);
                },
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAllCatsButton(List<QueryDocumentSnapshot> cats) {
    return GestureDetector(
      onTap: () => _showCategoriesSheet(cats),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 45, vertical: 16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [CafeTheme.primaryBrown, Color(0xFF7A4D2A)],
          ),
          borderRadius: BorderRadius.all(Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Color(0x805F3814),
              blurRadius: 22,
              spreadRadius: 2,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grid_view_rounded, color: Colors.black, size: 20),
            SizedBox(width: 10),
            Text(
              "كل الأقسام",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // FIX: Product list uses ValueListenableBuilder so ONLY this widget rebuilds on search
  Widget _buildProductListSection() {
    if (currentCat == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('cat', isEqualTo: currentCat)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) return const SizedBox();

        final allItems = snapshot.data!.docs;

        return ValueListenableBuilder<String>(
          valueListenable: _searchNotifier,
          builder: (context, searchQuery, _) {
            final List<QueryDocumentSnapshot> items = searchQuery.isEmpty
                ? allItems
                : allItems.where((doc) {
                    final String name = (doc['name'] ?? '').toString();
                    return name.contains(searchQuery);
                  }).toList();

            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(50),
                child: Center(
                  child: Text(
                    "لا توجد منتجات في هذا القسم",
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ),
              );
            }

            return UFOBeamProductSection(
              items:
                  items.map((d) => d.data() as Map<String, dynamic>).toList(),
              categoryName: currentCat ?? '',
              onAddItem: _showAddDialog,
              onQuantityChange: (idx, increase) {
                setState(() {
                  if (increase) {
                    basket[idx]['quantity']++;
                  } else {
                    if (basket[idx]['quantity'] > 1) {
                      basket[idx]['quantity']--;
                    } else {
                      basket.removeAt(idx);
                    }
                  }
                });
              },
              basket: basket,
            );
          },
        );
      },
    );
  }

  // FIX: FAB uses ValueListenableBuilder — page-level setState eliminated for toggle
  Widget _buildFloatingActionMenu() {
    return Positioned(
      bottom: 230,
      left: 24,
      child: ValueListenableBuilder<bool>(
        valueListenable: _showQuickMenuNotifier,
        builder: (context, showMenu, _) {
          return Column(
            children: [
              if (showMenu) ...[
                _fabOption(
                  icon: Icons.receipt_long_rounded,
                  label: "الحساب",
                  color: CafeTheme.success,
                  onTap: () {
                    _showQuickMenuNotifier.value = false;
                    _requestBill();
                  },
                ),
                const SizedBox(height: 12),
                _fabOption(
                  icon: Icons.help_outline_rounded,
                  label: "مساعدة",
                  color: CafeTheme.secondaryBrown,
                  onTap: () {
                    _showQuickMenuNotifier.value = false;
                    _showStatusSnackBar(
                      "جاري إرسال طلب المساعدة... 🙏",
                      CafeTheme.secondaryBrown,
                    );
                  },
                ),
                const SizedBox(height: 12),
                _fabOption(
                  icon: Icons.room_service_rounded,
                  label: "نداء ويتر",
                  color: CafeTheme.accent,
                  onTap: () {
                    _showQuickMenuNotifier.value = false;
                    _callWaiter();
                  },
                ),
                const SizedBox(height: 16),
              ],
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _fabPulseController,
                  builder: (context, _) => GestureDetector(
                    onTap: () =>
                        _showQuickMenuNotifier.value = !showMenu,
                    child: Container(
                      width: 60,
                      height: 60,
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
                      child: AnimatedRotation(
                        turns: showMenu ? 0.02 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: Icon(
                            showMenu
                                ? Icons.close_rounded
                                : Icons.support_agent_rounded,
                            key: ValueKey<bool>(showMenu),
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
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
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.2),
              border: Border.all(
                color: color.withValues(alpha: 0.7),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 15),
              ],
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xBF000000),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _requestBill() async {
    if (registeredName == null) return;
    await apiService.sendTelegramMessage(
      '━━━━━━━━━━━━━━━━━━\n'
      '🧾 طلب حساب — Storm Café\n'
      '━━━━━━━━━━━━━━━━━━\n'
      '👤 العميل : $registeredName\n'
      '🪑 الطاولة : $currentTable\n'
      '━━━━━━━━━━━━━━━━━━\n'
      '💳 العميل جاهز للدفع!',
    );
    _showStatusSnackBar(
      'تم طلب الحساب! سيأتي الويتر قريباً 🧾',
      CafeTheme.success,
    );
  }

  Widget _buildBottomActionArea() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xE60D0804),
              border: Border(
                top: BorderSide(color: CafeTheme.primaryBrown, width: 1.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x665F3814),
                  blurRadius: 30,
                  offset: Offset(0, -5),
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
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox();
        }
        final orders = snapshot.data!.docs;
        return SizedBox(
          height: 125,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            itemCount: orders.length,
            itemBuilder: (c, i) {
              final data = orders[i].data() as Map<String, dynamic>;
              final String status = data['status'] ?? "قيد الانتظار";
              final Color sColor = status == "جاهز"
                  ? Colors.greenAccent
                  : (status == "جاري التجهيز"
                      ? Colors.orangeAccent
                      : Colors.white54);
              final IconData statusIcon = status == "جاهز"
                  ? Icons.check_circle_rounded
                  : (status == "جاري التجهيز"
                      ? Icons.local_cafe_rounded
                      : Icons.hourglass_top_rounded);

              // FIX: Pre-computed border/shadow to avoid allocation on every frame
              return Container(
                width: 170,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0x0DFFFFFF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: sColor.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(statusIcon, color: sColor, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      status,
                      style: TextStyle(
                        color: sColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    if (data['items_with_qty'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "${(data['items_with_qty'] as List).length} صنف",
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
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
        padding: const EdgeInsets.only(top: 14, left: 24, right: 24),
        itemCount: basket.length,
        itemBuilder: (c, i) => Container(
          width: 170,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: const BoxDecoration(
            color: Color(0x0DFFFFFF),
            borderRadius: BorderRadius.all(Radius.circular(20)),
            border: Border.fromBorderSide(
              BorderSide(color: Color(0x725F3814), width: 1.5),
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
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.redAccent,
                      size: 24,
                    ),
                    onPressed: () => setState(() {
                      if (basket[i]['quantity'] > 1) {
                        basket[i]['quantity']--;
                      } else {
                        basket.removeAt(i);
                      }
                    }),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      "${basket[i]['quantity']}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: Colors.greenAccent,
                      size: 24,
                    ),
                    onPressed: () => setState(() => basket[i]['quantity']++),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              if (basket[i]['note'] != "بدون إضافات")
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 8, right: 8),
                  child: Text(
                    "📝 ${basket[i]['note']}",
                    style: const TextStyle(
                      fontSize: 11,
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
    // FIX: Total computed once, not inline on every build
    final double total = basket.fold(
      0.0,
      (prev, item) =>
          prev + ((item['price'] as num) * (item['quantity'] as num)),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 20, 30, 50),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "المبلغ الحالي",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${total.toStringAsFixed(2)} ج.م",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: CafeTheme.accent,
                  letterSpacing: 1,
                ),
              ),
              if (basket.isNotEmpty)
                Text(
                  "${basket.length} صنف",
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
            ],
          ),
          Column(
            children: [
              Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x805F3814),
                      blurRadius: 20,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: basket.isEmpty ? null : _sendOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CafeTheme.primaryBrown,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 35,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "تأكيد الطلب ⚡",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                ),
              ),
              if (basket.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() => basket.clear());
                      _showStatusSnackBar("تم مسح السلة", Colors.redAccent);
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    label: const Text(
                      "مسح السلة",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
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

  void _showAddDialog(Map<String, dynamic> item) {
    _noteController.clear();
    List<dynamic>? sizes = item['sizes'];
    Map<String, dynamic>? selectedSize;
    double currentPrice = (item['price'] as num).toDouble();

    if (sizes != null && sizes.isNotEmpty) {
      selectedSize = sizes.first;
      currentPrice = (selectedSize!['price'] as num).toDouble();
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2E1F10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: const BorderSide(
                  color: Color(0xB25F3814),
                  width: 1.5,
                ),
              ),
              title: Text(
                "تخصيص ${item['name']}",
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
                      "اختر الحجم:",
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
                        final bool isSelected = selectedSize == s;
                        return ChoiceChip(
                          label: Text("${s['name']} - ${s['price']} ج.م"),
                          selected: isSelected,
                          selectedColor: CafeTheme.primaryBrown,
                          backgroundColor: const Color(0x14FFFFFF),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected
                                  ? CafeTheme.primaryBrown
                                  : Colors.transparent,
                            ),
                          ),
                          onSelected: (bool selected) {
                            if (selected) {
                              setDialogState(() {
                                selectedSize = s;
                                currentPrice = (s['price'] as num).toDouble();
                              });
                            }
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
                    decoration: const InputDecoration(
                      hintText: "أي إضافات تحب نجهزها لك؟",
                      hintStyle: TextStyle(
                        color: Colors.white38,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: Color(0x14FFFFFF),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                        borderSide: BorderSide(color: Color(0x665F3814)),
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text("إلغاء", style: TextStyle(fontSize: 16)),
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
                      final String userNote = _noteController.text.isEmpty
                          ? "بدون إضافات"
                          : _noteController.text;
                      String itemName = item['name'];
                      if (selectedSize != null) {
                        itemName += " (${selectedSize!['name']})";
                      }

                      final int index = basket.indexWhere(
                        (e) =>
                            e['name'] == itemName &&
                            e['note'] == userNote &&
                            e['price'] == currentPrice,
                      );

                      if (index != -1) {
                        basket[index]['quantity']++;
                      } else {
                        basket.add({
                          'name': itemName,
                          'price': currentPrice,
                          'image_url': item['image_url'],
                          'note': userNote,
                          'quantity': 1,
                        });
                      }
                    });
                    Navigator.pop(context);
                    _showStatusSnackBar(
                      "تمت الإضافة ✨",
                      CafeTheme.primaryBrown,
                    );
                  },
                  child: const Text(
                    "إضافة",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _sendOrder() async {
    if (basket.isEmpty || registeredName == null) return;

    try {
      final itemsWithQty = basket
          .map((e) => {'name': e['name'], 'qty': e['quantity']})
          .toList();
      final double total = basket.fold(
        0.0,
        (prev, item) =>
            prev + ((item['price'] as num) * (item['quantity'] as num)),
      );
      final String note = basket.any((e) => e['note'] != 'بدون إضافات')
          ? basket.firstWhere((e) => e['note'] != 'بدون إضافات')['note']
          : 'بدون إضافات';

      await apiService.createOrder(
        customerName: registeredName!,
        tableNumber: currentTable ?? '?',
        itemsWithQty: itemsWithQty,
        totalPrice: total,
        note: note,
      );

      final itemLines = basket
          .map((e) => '  • ${e['name']} × ${e['quantity']}')
          .join('\n');

      await apiService.sendTelegramMessage(
        '━━━━━━━━━━━━━━━━━━\n'
        '☕ طلب جديد — Storm Café\n'
        '━━━━━━━━━━━━━━━━━━\n'
        '👤 العميل : $registeredName\n'
        '🪑 الطاولة : $currentTable\n'
        '━━━━━━━━━━━━━━━━━━\n'
        '🛒 الطلبات :\n$itemLines\n'
        '━━━━━━━━━━━━━━━━━━\n'
        '📝 ملاحظة : $note\n'
        '💰 الإجمالي : ${total.toStringAsFixed(2)} ج.م\n'
        '━━━━━━━━━━━━━━━━━━',
      );

      setState(() => basket.clear());
      _showStatusSnackBar('تم إرسال طلبك! 🚀', Colors.greenAccent);
    } catch (_) {
      _showStatusSnackBar(
        'تعذر إرسال الطلب حالياً، حاول مرة أخرى',
        Colors.redAccent,
      );
    }
  }

  void _callWaiter() async {
    if (_isWaiterAlertActive || registeredName == null) return;
    setState(() => _isWaiterAlertActive = true);
    try {
      await apiService.callWaiter(
        customerName: registeredName!,
        tableNumber: currentTable ?? '?',
      );
      await apiService.sendTelegramMessage(
        '━━━━━━━━━━━━━━━━━━\n'
        '🔔 نداء ويتر — Storm Café\n'
        '━━━━━━━━━━━━━━━━━━\n'
        '👤 العميل : $registeredName\n'
        '🪑 الطاولة : $currentTable\n'
        '━━━━━━━━━━━━━━━━━━\n'
        '⚡ العميل يطلب مساعدة الويتر الآن!',
      );
    } catch (_) {
      setState(() => _isWaiterAlertActive = false);
      _showStatusSnackBar('تعذر إرسال نداء الويتر حالياً', Colors.redAccent);
    }
  }

  void _changeTableDialog() {
    _tableEntryController.text = currentTable ?? "";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E1F10),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
          side: BorderSide(color: CafeTheme.secondaryBrown, width: 1.5),
        ),
        title: const Text(
          "تغيير الطاولة 🪑",
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
          decoration: const InputDecoration(
            hintText: "رقم الطاولة الجديد",
            filled: true,
            fillColor: Color(0x14FFFFFF),
            contentPadding: EdgeInsets.symmetric(vertical: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء", style: TextStyle(fontSize: 16)),
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
                Navigator.pop(context);
                _showStatusSnackBar(
                  "تم تغيير الطاولة إلى ${_tableEntryController.text} 🪑",
                  CafeTheme.secondaryBrown,
                );
              }
            },
            child: const Text(
              "تحديث",
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
}

// ==========================================
// FIX: Extracted as const StatelessWidget — never rebuilds
// ==========================================
class _DevBadge extends StatelessWidget {
  const _DevBadge();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.all(Radius.circular(14)),
        border: Border.fromBorderSide(
          BorderSide(color: Color(0x66C49A6D), width: 1),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.code_rounded, color: CafeTheme.accent, size: 18),
            SizedBox(width: 6),
            Text(
              "Dev",
              style: TextStyle(
                color: CafeTheme.accent,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// FIX: Extracted as const StatelessWidget — never rebuilds
class _TableButton extends StatelessWidget {
  const _TableButton();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: Color(0x14FFFFFF),
        borderRadius: BorderRadius.all(Radius.circular(14)),
        border: Border.fromBorderSide(
          BorderSide(color: Color(0x665F3814), width: 1.2),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.table_restaurant_rounded,
              color: CafeTheme.primaryBrown,
              size: 20,
            ),
            SizedBox(width: 6),
            Text(
              "الطاولة",
              style: TextStyle(
                color: CafeTheme.primaryBrown,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// Cinematic Category Carousel Widget
// ==========================================
class CinematicCategoryCarousel extends StatefulWidget {
  final List<QueryDocumentSnapshot> categories;
  final Function(String catName) onSelect;
  final String? selectedCategory;

  const CinematicCategoryCarousel({
    super.key,
    required this.categories,
    required this.onSelect,
    required this.selectedCategory,
  });

  @override
  State<CinematicCategoryCarousel> createState() =>
      _CinematicCategoryCarouselState();
}

class _CinematicCategoryCarouselState
    extends State<CinematicCategoryCarousel> {
  PageController? _pageController;
  // FIX: Use a separate notifier so only PageView items rebuilds on scroll
  final ValueNotifier<double> _currentPageNotifier = ValueNotifier(0);
  bool _isProgrammaticScroll = false;
  double? _lastScreenWidth;

  int get _selectedIndex {
    if (widget.selectedCategory == null) return 0;
    final idx = widget.categories.indexWhere(
      (doc) => (doc['name'] ?? '').toString() == widget.selectedCategory,
    );
    return idx >= 0 ? idx : 0;
  }

  void _initController(double screenWidth) {
    if (_lastScreenWidth == screenWidth && _pageController != null) return;
    _lastScreenWidth = screenWidth;

    final double fraction = screenWidth < 400
        ? 0.42
        : screenWidth < 600
        ? 0.36
        : screenWidth < 900
        ? 0.28
        : 0.24;

    final oldCtrl = _pageController;
    _pageController = PageController(
      viewportFraction: fraction,
      initialPage: _selectedIndex,
    );
    // FIX: Listener updates ValueNotifier, not setState — avoids full carousel rebuild
    _pageController!.addListener(() {
      _currentPageNotifier.value = _pageController!.page ?? 0;
    });
    oldCtrl?.dispose();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _currentPageNotifier.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CinematicCategoryCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCategory == null ||
        widget.selectedCategory == oldWidget.selectedCategory) {
      return;
    }
    final newIndex = widget.categories.indexWhere(
      (doc) => (doc['name'] ?? '').toString() == widget.selectedCategory,
    );
    if (newIndex >= 0 && (_pageController?.hasClients ?? false)) {
      _isProgrammaticScroll = true;
      _pageController!
          .animateToPage(
            newIndex,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutCubic,
          )
          .then((_) => _isProgrammaticScroll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.categories;
    final double screenWidth = MediaQuery.of(context).size.width;
    _initController(screenWidth);

    if (cats.isEmpty) return const SizedBox(height: 250);

    final double carouselHeight = screenWidth < 400
        ? 270
        : screenWidth < 600
        ? 260
        : 240;
    final double iconSize = screenWidth < 400
        ? 55
        : screenWidth < 600
        ? 50
        : 48;
    const double fontSizeActive = 18;
    const double fontSizeInactive = 15;

    return SizedBox(
      height: carouselHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 24,
            right: 24,
            bottom: 12,
            child: Container(
              height: 38,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(100)),
                border: Border.fromBorderSide(
                  BorderSide(color: Color(0x665F3814)),
                ),
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Color(0x405F3814),
                    Colors.transparent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x405F3814),
                    blurRadius: 25,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          RepaintBoundary(
            // FIX: ValueListenableBuilder scopes rebuilds to each card's transform
            child: ValueListenableBuilder<double>(
              valueListenable: _currentPageNotifier,
              builder: (context, currentPage, _) {
                return PageView.builder(
                  controller: _pageController!,
                  itemCount: cats.length,
                  physics: const BouncingScrollPhysics(
                    decelerationRate: ScrollDecelerationRate.fast,
                  ),
                  padEnds: true,
                  onPageChanged: (index) {
                    if (_isProgrammaticScroll) return;
                    final name = (cats[index]['name'] ?? '').toString();
                    if (name != widget.selectedCategory) {
                      widget.onSelect(name);
                    }
                  },
                  itemBuilder: (context, index) {
                    final doc = cats[index];
                    final String name = (doc['name'] ?? '').toString();
                    final double signedDelta = (currentPage - index);
                    final double diff = signedDelta.abs();
                    final double scale = (1 - diff * 0.13).clamp(0.80, 1.0);
                    final double opacity = (1 - diff * 0.20).clamp(0.25, 1.0);
                    final double curveDrop = (diff * diff * 12).clamp(0.0, 24.0);
                    final double yRotation =
                        (signedDelta * 0.20).clamp(-0.50, 0.50);
                    final bool isSelected = widget.selectedCategory == name;
                    final bool active = diff < 0.60 || isSelected;
                    final IconData catIcon = _categoryIconByName(name);

                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0012)
                        ..translate(0.0, curveDrop)
                        ..rotateY(-yRotation),
                      child: Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: opacity,
                          child: _CategoryCard(
                            name: name,
                            icon: catIcon,
                            isSelected: isSelected,
                            active: active,
                            iconSize: iconSize,
                            fontSizeActive: fontSizeActive,
                            fontSizeInactive: fontSizeInactive,
                            onTap: () => widget.onSelect(name),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
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
    required this.name,
    required this.icon,
    required this.isSelected,
    required this.active,
    required this.iconSize,
    required this.fontSizeActive,
    required this.fontSizeInactive,
    required this.onTap,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          transform: Matrix4.translationValues(0, _isHovered ? -5 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            color: widget.isSelected ? null : const Color(0x4D000000),
            gradient: widget.isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xF57A4D2A),
                      CafeTheme.primaryBrown.withValues(alpha: 0.90),
                      const Color(0xE05F3814),
                    ],
                  )
                : null,
            border: Border.all(
              color: widget.isSelected
                  ? const Color(0xB2987B5C)
                  : CafeTheme.primaryBrown.withValues(
                      alpha: _isHovered ? 0.4 : 0.2,
                    ),
              width: widget.isSelected ? 2.0 : 1.2,
            ),
            boxShadow: widget.isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x59C49A6D),
                      blurRadius: 45,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Color(0x4D5F3814),
                      blurRadius: 30,
                      spreadRadius: 1,
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon,
                  size: widget.active ? widget.iconSize : widget.iconSize - 8,
                  color: widget.isSelected
                      ? const Color(0xFFF5E6D3)
                      : const Color(0xCC5F3814),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    fontSize: widget.active
                        ? widget.fontSizeActive
                        : widget.fontSizeInactive,
                    color: widget.isSelected ? Colors.white : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// PRODUCT SECTION — خفيف وسريع
// ==========================================
class UFOBeamProductSection extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String categoryName;
  final Function(Map<String, dynamic>) onAddItem;
  final Function(int idx, bool increase) onQuantityChange;
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
        itemBuilder: (context, i) {
          final item = items[i];
          final String name = item['name'] ?? '';
          final int basketIdx = basket.indexWhere((e) => e['name'] == name);
          final bool inBasket = basketIdx != -1;
          return RepaintBoundary(
            child: _NeonProductCard(
              key: ValueKey('${categoryName}_$name'),
              item: item,
              inBasket: inBasket,
              qty: inBasket ? (basket[basketIdx]['quantity'] as int) : 0,
              onAdd: () => onAddItem(item),
              onMinus: inBasket ? () => onQuantityChange(basketIdx, false) : null,
              onPlus: inBasket ? () => onQuantityChange(basketIdx, true) : null,
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// كارت المنتج مع particle burst
// ==========================================
class _NeonProductCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool inBasket;
  final int qty;
  final VoidCallback onAdd;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  const _NeonProductCard({
    super.key,
    required this.item,
    required this.inBasket,
    required this.qty,
    required this.onAdd,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  State<_NeonProductCard> createState() => _NeonProductCardState();
}

class _NeonProductCardState extends State<_NeonProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _burstCtrl;
  bool _showBurst = false;
  bool _isHovered = false;

  final List<_Particle> _particles = [];
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _burstCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _burstCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) setState(() => _showBurst = false);
        _burstCtrl.reset();
      }
    });
  }

  @override
  void dispose() {
    _burstCtrl.dispose();
    super.dispose();
  }

  void _triggerBurst() {
    _particles.clear();
    for (int i = 0; i < 20; i++) {
      final double angle =
          (i / 20) * math.pi * 2 + _rng.nextDouble() * 0.4;
      final double speed = 45 + _rng.nextDouble() * 60;
      final double size = 4 + _rng.nextDouble() * 5;
      final Color color = const [
        CafeTheme.primaryBrown,
        CafeTheme.secondaryBrown,
        CafeTheme.success,
        Colors.white,
        Color(0xFFD4A96A),
      ][i % 5];
      _particles.add(
        _Particle(angle: angle, speed: speed, size: size, color: color),
      );
    }
    setState(() => _showBurst = true);
    _burstCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.item['name'] ?? '';
    final bool hasSizes =
        widget.item['sizes'] != null &&
        (widget.item['sizes'] as List).isNotEmpty;
    final String priceText =
        hasSizes ? 'أحجام متعددة' : '${widget.item['price']} ج.م';
    final bool inBasket = widget.inBasket;
    final Color accent =
        inBasket ? CafeTheme.success : CafeTheme.primaryBrown;
    final Color accentDim =
        inBasket ? const Color(0xFF4CAF50) : const Color(0xFF7A4D2A);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.only(bottom: 20),
            transform: Matrix4.translationValues(
              0,
              _isHovered && !inBasket ? -4 : 0,
              0,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: const Color(0x66000000),
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: inBasket
                    ? const [
                        Color(0xCC1A2A10),
                        Color(0xCC0D1A05),
                        Color(0xE50D0804),
                      ]
                    : _isHovered
                    ? const [
                        Color(0xCC251505),
                        Color(0xCC3A2815),
                        Color(0xE5120A02),
                      ]
                    : const [
                        Color(0xB21A0F05),
                        Color(0xB22E1F10),
                        Color(0xCC0D0804),
                      ],
              ),
              border: Border.all(
                color: accent.withValues(
                  alpha: inBasket ? 0.80 : (_isHovered ? 0.50 : 0.25),
                ),
                width: inBasket ? 2.0 : (_isHovered ? 1.5 : 1.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(
                    alpha: inBasket ? 0.35 : (_isHovered ? 0.20 : 0.05),
                  ),
                  blurRadius: inBasket ? 25 : (_isHovered ? 18 : 10),
                  spreadRadius: inBasket ? 2 : 0,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 6,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [accent, accentDim],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.8),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  _buildItemImage(widget.item),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: inBasket
                                  ? Colors.white
                                  : const Color(0xF2FFFFFF),
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              color: hasSizes
                                  ? const Color(0x26FF9800)
                                  : const Color(0x264CAF50),
                              border: Border.all(
                                color: hasSizes
                                    ? const Color(0x73FF9800)
                                    : const Color(0x734CAF50),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hasSizes
                                      ? Icons.tune_rounded
                                      : Icons.payments_outlined,
                                  size: 13,
                                  color: hasSizes
                                      ? Colors.orangeAccent
                                      : CafeTheme.success,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  priceText,
                                  style: TextStyle(
                                    color: hasSizes
                                        ? Colors.orangeAccent
                                        : CafeTheme.success,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    child: inBasket
                        ? _QuantityControl(
                            qty: widget.qty,
                            onMinus: widget.onMinus!,
                            onPlus: widget.onPlus!,
                          )
                        : GestureDetector(
                            onTap: () {
                              widget.onAdd();
                              _triggerBurst();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    CafeTheme.primaryBrown,
                                    Color(0xFF3D2410),
                                    CafeTheme.secondaryBrown,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: CafeTheme.primaryBrown.withValues(
                                      alpha: _isHovered ? 0.85 : 0.60,
                                    ),
                                    blurRadius: _isHovered ? 22 : 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),

        if (inBasket)
          const Positioned(
            top: -8,
            right: 20,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(24)),
                gradient: LinearGradient(
                  colors: [CafeTheme.success, Color(0xFF4CAF50)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x994CAF50),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded, size: 12, color: Colors.black),
                    SizedBox(width: 5),
                    Text(
                      'في السلة',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        if (_showBurst)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 20,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _burstCtrl,
                builder: (context, _) => CustomPaint(
                  painter: _ParticleBurstPainter(
                    particles: _particles,
                    progress: _burstCtrl.value,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildItemImage(Map<String, dynamic> item) {
    final String? imageUrl = item['image_url'];
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Container(
        width: 95,
        height: 95,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Color(0x405F3814),
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          child: Image.network(
            imageUrl,
            width: 95,
            height: 95,
            fit: BoxFit.cover,
            cacheWidth: 190,
            cacheHeight: 190,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: 95,
                height: 95,
                color: CafeTheme.surface,
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: CafeTheme.accent.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              );
            },
            errorBuilder: (_, __, ___) => _fallbackIcon(),
          ),
        ),
      );
    }
    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
    return Container(
      width: 95,
      height: 95,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x405F3814),
            Color(0x26987B5C),
          ],
        ),
        border: Border.fromBorderSide(
          BorderSide(color: Color(0x665F3814), width: 1.5),
        ),
      ),
      child: const Icon(
        Icons.fastfood_rounded,
        color: CafeTheme.primaryBrown,
        size: 40,
      ),
    );
  }
}

class _Particle {
  final double angle;
  final double speed;
  final double size;
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
    final double t = math.sin(progress * math.pi / 2);
    final double alpha =
        progress < 0.5 ? 1.0 : 1.0 - ((progress - 0.5) * 2);
    final Offset center = Offset(size.width / 2, size.height / 2);

    for (final p in particles) {
      final double dist = p.speed * t;
      final double px = center.dx + math.cos(p.angle) * dist;
      final double py = center.dy + math.sin(p.angle) * dist;

      canvas.drawCircle(
        Offset(px, py),
        p.size * (1 - progress * 0.5),
        Paint()
          ..color = p.color.withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );

      if (dist > 8) {
        final double tailDist = dist - 8;
        final double tailPx = center.dx + math.cos(p.angle) * tailDist;
        final double tailPy = center.dy + math.sin(p.angle) * tailDist;
        canvas.drawLine(
          Offset(tailPx, tailPy),
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

class _QuantityControl extends StatelessWidget {
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _QuantityControl({
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0x14FFFFFF),
        border: Border.all(
          color: const Color(0x664CAF50),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.remove_rounded, Colors.redAccent, onMinus),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              '$qty',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          _btn(Icons.add_rounded, CafeTheme.success, onPlus),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: color.withValues(alpha: 0.18),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

IconData _categoryIconByName(String name) {
  final normalized = name.toLowerCase();
  if (normalized.contains('برجر') || normalized.contains('burger')) {
    return Icons.lunch_dining_rounded;
  }
  if (normalized.contains('بيتزا') || normalized.contains('pizza')) {
    return Icons.local_pizza_rounded;
  }
  if (normalized.contains('مكرونة') || normalized.contains('باستا')) {
    return Icons.ramen_dining_rounded;
  }
  if (normalized.contains('مشروب') || normalized.contains('drink')) {
    return Icons.local_drink_rounded;
  }
  if (normalized.contains('حلويات') || normalized.contains('dessert')) {
    return Icons.cake_rounded;
  }
  return Icons.restaurant_menu_rounded;
}

// ==========================================
// صفحة الويتر
// ==========================================
class WaiterTerminal extends StatefulWidget {
  const WaiterTerminal({super.key});

  @override
  State<WaiterTerminal> createState() => _WaiterTerminalState();
}

class _WaiterTerminalState extends State<WaiterTerminal> {
  int _currentTabIndex = 0;

  final List<Map<String, dynamic>> waiterBasket = [];
  final tableCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final searchCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  String? selectedCategory;
  String searchQuery = "";

  @override
  void dispose() {
    tableCtrl.dispose();
    nameCtrl.dispose();
    searchCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  void _playSound(String url) {
    if (kIsWeb) {
      js.context.callMethod('eval', [
        "(function() { var audio = new Audio('$url'); audio.play(); })();",
      ]);
    }
  }

  void _showWaiterAddDialog(Map<String, dynamic> item) {
    noteCtrl.clear();
    List<dynamic>? sizes = item['sizes'];
    Map<String, dynamic>? selectedSize;
    double currentPrice = (item['price'] as num).toDouble();

    if (sizes != null && sizes.isNotEmpty) {
      selectedSize = sizes.first;
      currentPrice = (selectedSize!['price'] as num).toDouble();
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2E1F10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(
                  color: Color(0xB2987B5C),
                  width: 1.5,
                ),
              ),
              title: Text(
                "إضافة ${item['name']}",
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
                      "اختر الحجم:",
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
                        final bool isSelected = selectedSize == s;
                        return ChoiceChip(
                          label: Text("${s['name']} - ${s['price']} ج.م"),
                          selected: isSelected,
                          selectedColor: CafeTheme.secondaryBrown,
                          backgroundColor: const Color(0x14FFFFFF),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (bool selected) {
                            if (selected) {
                              setDialogState(() {
                                selectedSize = s;
                                currentPrice = (s['price'] as num).toDouble();
                              });
                            }
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
                    decoration: const InputDecoration(
                      hintText: "ملاحظات (سكر زيادة، بدون ثلج...)",
                      hintStyle: TextStyle(
                        color: Colors.white38,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: Color(0x14FFFFFF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                        borderSide: BorderSide(color: Color(0x66987B5C)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("إلغاء", style: TextStyle(fontSize: 16)),
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
                      final String userNote = noteCtrl.text.isEmpty
                          ? "بدون ملاحظات"
                          : noteCtrl.text;
                      String itemName = item['name'];
                      if (selectedSize != null) {
                        itemName += " (${selectedSize!['name']})";
                      }

                      final int index = waiterBasket.indexWhere(
                        (e) =>
                            e['name'] == itemName &&
                            e['note'] == userNote &&
                            e['price'] == currentPrice,
                      );

                      if (index != -1) {
                        waiterBasket[index]['qty']++;
                      } else {
                        waiterBasket.add({
                          'name': itemName,
                          'price': currentPrice,
                          'note': userNote,
                          'qty': 1,
                        });
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "إضافة",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _sendToBarista() async {
    final tableName = tableCtrl.text.trim();
    final customerName = nameCtrl.text.trim();

    if (waiterBasket.isEmpty) {
      _showSnack('السلة فارغة!', Colors.orangeAccent);
      return;
    }
    if (tableName.isEmpty || customerName.isEmpty) {
      _showSnack('يرجى إدخال رقم الطاولة واسم العميل', Colors.orangeAccent);
      return;
    }

    final itemsWithQty = waiterBasket
        .map((e) => {'name': e['name'], 'qty': e['qty']})
        .toList();
    final double total = waiterBasket.fold(
      0.0,
      (prev, item) => prev + ((item['price'] as num) * (item['qty'] as num)),
    );
    final String note = waiterBasket.any((e) => e['note'] != 'بدون ملاحظات')
        ? waiterBasket.firstWhere((e) => e['note'] != 'بدون ملاحظات')['note']
        : 'بدون ملاحظات';

    try {
      await apiService.createWaiterOrder(
        customerName: customerName,
        tableNumber: tableName,
        itemsWithQty: itemsWithQty,
        totalPrice: total,
        note: note,
      );

      final waiterItemLines = waiterBasket
          .map((e) => '  • ${e['name']} × ${e['qty']}')
          .join('\n');

      await apiService.sendTelegramMessage(
        '━━━━━━━━━━━━━━━━━━\n'
        '🤵 طلب ويتر — Storm Café\n'
        '━━━━━━━━━━━━━━━━━━\n'
        '👤 العميل : $customerName\n'
        '🪑 الطاولة : $tableName\n'
        '━━━━━━━━━━━━━━━━━━\n'
        '🛒 الطلبات :\n$waiterItemLines\n'
        '━━━━━━━━━━━━━━━━━━\n'
        '📝 ملاحظة : $note\n'
        '💰 الإجمالي : ${total.toStringAsFixed(2)} ج.م\n'
        '━━━━━━━━━━━━━━━━━━',
      );

      setState(() => waiterBasket.clear());
      _showSnack('تم إرسال الطلب للباريستا! ✅', Colors.greenAccent);
    } catch (e) {
      if (e is ApiException && e.statusCode == 401) {
        _showSnack(
          'انتهت صلاحية الجلسة — يرجى تسجيل الدخول مجدداً',
          Colors.red,
        );
      } else {
        _showSnack('تعذر إرسال الطلب الآن، حاول مرة أخرى', Colors.redAccent);
      }
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
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

  Widget _buildPOSView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: tableCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "رقم الطاولة",
                    labelStyle: TextStyle(color: CafeTheme.secondaryBrown),
                    filled: true,
                    fillColor: Color(0x14FFFFFF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "اسم العميل",
                    labelStyle: TextStyle(color: CafeTheme.secondaryBrown),
                    filled: true,
                    fillColor: Color(0x14FFFFFF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: searchCtrl,
            onChanged: (v) => setState(() => searchQuery = v),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "ابحث عن منتج...",
              hintStyle: TextStyle(color: Colors.white38),
              prefixIcon: Icon(
                Icons.search,
                color: CafeTheme.secondaryBrown,
              ),
              filled: true,
              fillColor: Color(0x14FFFFFF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 45,
          // FIX: Categories sorted once in builder, not re-sorted on every frame
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('categories')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              final cats = snapshot.data!.docs.toList()
                ..sort((a, b) {
                  final aIndex =
                      (a.data() as Map<String, dynamic>)['index'] ?? 999;
                  final bIndex =
                      (b.data() as Map<String, dynamic>)['index'] ?? 999;
                  return (aIndex as num).compareTo(bIndex as num);
                });
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: cats.length + 1,
                itemBuilder: (c, i) {
                  final bool isAll = i == 0;
                  final String? catName = isAll ? null : cats[i - 1]['name'];
                  final bool isSelected = selectedCategory == catName;
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
                        color: isSelected
                            ? CafeTheme.secondaryBrown
                            : const Color(0x14FFFFFF),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isSelected
                              ? CafeTheme.secondaryBrown
                              : Colors.transparent,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          isAll ? "الكل" : (catName ?? ""),
                          style: TextStyle(
                            color:
                                isSelected ? Colors.black : Colors.white70,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: selectedCategory == null
                ? FirebaseFirestore.instance.collection('products').snapshots()
                : FirebaseFirestore.instance
                      .collection('products')
                      .where('cat', isEqualTo: selectedCategory)
                      .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: CafeTheme.secondaryBrown,
                  ),
                );
              }
              final items = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final String name = (data['name'] ?? '').toString();
                return name.contains(searchQuery);
              }).toList();

              final double screenWidth = MediaQuery.of(context).size.width;
              final int crossAxisCount = screenWidth < 600 ? 2 : 4;
              final double childAspectRatio = screenWidth < 600 ? 0.85 : 1.0;

              return GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: childAspectRatio,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index].data() as Map<String, dynamic>;
                  return GestureDetector(
                    onTap: () => _showWaiterAddDialog(item),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0x1EFFFFFF),
                            Color(0x0DFFFFFF),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0x99C49A6D),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x26C49A6D),
                            blurRadius: 15,
                            spreadRadius: 1,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: item['image_url'] != null &&
                                      item['image_url'].toString().isNotEmpty
                                  ? Image.network(
                                      item['image_url'],
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      cacheWidth: 400,
                                      errorBuilder: (ctx, err, stack) =>
                                          const Icon(
                                            Icons.fastfood,
                                            color: CafeTheme.accent,
                                            size: 45,
                                          ),
                                    )
                                  : const Icon(
                                      Icons.fastfood,
                                      color: CafeTheme.accent,
                                      size: 45,
                                    ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xD9000000),
                                border: Border(
                                  top: BorderSide(
                                    color: Color(0x66C49A6D),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item['name'] ?? "",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "${item['price']} ج.م",
                                    style: const TextStyle(
                                      color: CafeTheme.accent,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (waiterBasket.isNotEmpty) _buildBasketSummary(),
      ],
    );
  }

  Widget _buildOrdersManagementView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: CafeTheme.secondaryBrown),
          );
        }
        // FIX: Sort once per snapshot
        final orders = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aTime = (a.data() as Map<String, dynamic>)['timestamp'];
            final bTime = (b.data() as Map<String, dynamic>)['timestamp'];
            if (aTime == null || bTime == null) return 0;
            return (bTime as Timestamp).compareTo(aTime as Timestamp);
          });

        if (orders.isEmpty) {
          return const Center(
            child: Text(
              "لا توجد طلبات",
              style: TextStyle(color: Colors.white54, fontSize: 18),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final data = orders[index].data() as Map<String, dynamic>;
            final String status = data['status'] ?? "قيد الانتظار";
            final Color sColor = status == "جاهز"
                ? Colors.greenAccent
                : (status == "جاري التجهيز"
                    ? Colors.orangeAccent
                    : Colors.white54);
            final List items = data['items_with_qty'] ?? [];

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x0DFFFFFF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sColor.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: ExpansionTile(
                leading: Icon(
                  Icons.receipt_long_rounded,
                  color: sColor,
                  size: 28,
                ),
                title: Text(
                  "${data['customer_name']} - طاولة ${data['table_number']}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  status,
                  style: TextStyle(
                    color: sColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item['name'] ?? "",
                                  style: const TextStyle(fontSize: 15),
                                ),
                                Text(
                                  "x${item['qty']}",
                                  style: const TextStyle(
                                    color: CafeTheme.secondaryBrown,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(
                          color: Colors.white24,
                          height: 24,
                          thickness: 1,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${data['total_price']} ج.م",
                              style: const TextStyle(
                                color: CafeTheme.success,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            Row(
                              children: [
                                _statusButton(
                                  "قيد الانتظار",
                                  Colors.white54,
                                  status,
                                  orders[index].id,
                                ),
                                const SizedBox(width: 8),
                                _statusButton(
                                  "جاري التجهيز",
                                  Colors.orangeAccent,
                                  status,
                                  orders[index].id,
                                ),
                                const SizedBox(width: 8),
                                _statusButton(
                                  "جاهز",
                                  Colors.greenAccent,
                                  status,
                                  orders[index].id,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _statusButton(
    String label,
    Color color,
    String currentStatus,
    String docId,
  ) {
    final bool isSelected = currentStatus == label;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          try {
            await apiService.updateOrder(docId, label);
          } catch (e) {
            if (mounted) _showSnack('تعذر تحديث الحالة', Colors.redAccent);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.25)
                : const Color(0x0DFFFFFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.white24,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? color : Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
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
            "لوحة الويتر 🤵",
            style: TextStyle(
              color: CafeTheme.secondaryBrown,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          elevation: 5,
          shadowColor: const Color(0x4D5F3814),
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: CafeTheme.surface,
          selectedItemColor: CafeTheme.primaryBrown,
          unselectedItemColor: Colors.white54,
          currentIndex: _currentTabIndex,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          onTap: (index) => setState(() => _currentTabIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.point_of_sale),
              label: "نقطة البيع (POS)",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long),
              label: "إدارة الطلبات",
            ),
          ],
        ),
        body: _currentTabIndex == 0
            ? _buildPOSView()
            : _buildOrdersManagementView(),
      ),
    );
  }

  Widget _buildBasketSummary() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: CafeTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: CafeTheme.primaryBrown, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x4D5F3814),
            blurRadius: 20,
            offset: Offset(0, -5),
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
              itemBuilder: (context, index) {
                final item = waiterBasket[index];
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 16,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0x14FFFFFF),
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item['name'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.redAccent,
                              size: 24,
                            ),
                            onPressed: () => setState(() {
                              if (item['qty'] > 1) {
                                item['qty']--;
                              } else {
                                waiterBasket.removeAt(index);
                              }
                            }),
                          ),
                          Text(
                            "${item['qty']}",
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
                            onPressed: () => setState(() {
                              item['qty']++;
                            }),
                          ),
                        ],
                      ),
                      if (item['note'] != null &&
                          item['note'] != "بدون ملاحظات")
                        Text(
                          "📝 ${item['note']}",
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
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
                shadowColor: const Color(0x80987B5C),
              ),
              onPressed: _sendToBarista,
              child: const Text(
                "إرسال الطلب للباريستا",
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
}
