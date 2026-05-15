import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:ui';

import 'firebase_options.dart';
import 'services/api_service.dart';

// Utility class for Category Icons since we cannot import external non-standard files
class CategoryIcons {
  static IconData resolve(String name) {
    if (name.contains("قهوة") ||
        name.contains("اسبريسو") ||
        name.contains("كوفي")) {
      return Icons.coffee_rounded;
    } else if (name.contains("عصير") ||
        name.contains("موهيتو") ||
        name.contains("مشروب")) {
      return Icons.local_drink_rounded;
    } else if (name.contains("حلى") ||
        name.contains("كيك") ||
        name.contains("ديزرت")) {
      return Icons.cake_rounded;
    } else if (name.contains("شاي")) {
      return Icons.emoji_food_beverage_rounded;
    } else if (name.contains("ساندوتش") ||
        name.contains("طعام") ||
        name.contains("أكل")) {
      return Icons.lunch_dining_rounded;
    }
    return Icons.local_cafe_rounded;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase Init Error: $e");
  }
  runApp(const StormLuxuryApp());
}

class CafeTheme {
  static const Color primaryGold = Color(0xFFC8A96E);
  static const Color primaryGoldLight = Color(0xFFE8D5B0);
  static const Color warmBrown = Color(0xFF7B4A1E);
  static const Color deepBrown = Color(0xFF5C2F0A);
  static const Color darkBg = Color(0xFF0A0600);
  static const Color surface = Color(0xFF1A1008);
  static const Color surfaceLight = Color(0xFF2A1A0A);

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFC8A96E), Color(0xFF7B4A1E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient brownGradient = LinearGradient(
    colors: [Color(0xFF2A1A0A), Color(0xFF1A1008)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

const String localBackgroundImage = 'assets/images/storm_bg.jpg';
const String localLogoImage = 'assets/images/storm_logo.png';

class StormLuxuryApp extends StatelessWidget {
  const StormLuxuryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'storm | Luxury Experience',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: CafeTheme.darkBg,
        fontFamily: 'Tajawal',
        splashColor: CafeTheme.primaryGold.withValues(alpha: 0.3),
        highlightColor: CafeTheme.primaryGold.withValues(alpha: 0.2),
        colorScheme: ColorScheme.fromSeed(
          seedColor: CafeTheme.primaryGold,
          brightness: Brightness.dark,
          surface: CafeTheme.surface,
          onSurface: Colors.white,
        ),
      ),
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
        Icon(Icons.restaurant_menu, size: size, color: CafeTheme.primaryGold),
  );
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
  List<Map<String, dynamic>> basket = [];
  String? registeredName;
  String? currentTable;

  bool _isEntryComplete = false;
  bool _isWaiterAlertActive = false;

  late AnimationController _glowController;
  late AnimationController _devPulseController;

  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _nameEntryController = TextEditingController();
  final TextEditingController _tableEntryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _devPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    _devPulseController.dispose();
    _noteController.dispose();
    _nameEntryController.dispose();
    _tableEntryController.dispose();
    super.dispose();
  }

  void _playSound(String url) {
    debugPrint("Play sound requested: $url");
  }

  void _openUrl(String url) {
    debugPrint("Open URL requested: $url");
  }

  void _playMicrowaveWorking() =>
      _playSound("https://files.catbox.moe/ct6wzl.mp3");
  void _playMicrowaveDone() =>
      _playSound("https://files.catbox.moe/hecpqn.mp3");
  void _playWaiterBell() => _playSound("https://files.catbox.moe/y77se9.mp3");

  void _initStatusListeners() {
    if (registeredName == null) return;

    FirebaseFirestore.instance
        .collection('alerts')
        .where('customer_name', isEqualTo: registeredName)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty && _isWaiterAlertActive) {
        setState(() => _isWaiterAlertActive = false);
        _playWaiterBell();
        _showStatusSnackBar(
          "الويتر جاي لك دلوقتي يا فندم 😊",
          CafeTheme.primaryGold,
        );
      }
    });

    FirebaseFirestore.instance
        .collection('orders')
        .where('customer_name', isEqualTo: registeredName)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          var data = change.doc.data() as Map<String, dynamic>;
          String status = data['status'];
          if (status == 'جاري التجهيز') {
            _playMicrowaveWorking();
            _showStatusSnackBar(
              "بدأنا نجهز طلبك بكل حب.. ✨",
              Colors.orangeAccent,
            );
          } else if (status == 'جاهز') {
            _playMicrowaveDone();
            _showStatusSnackBar(
              "طلبك جاهز يا $registeredName! بالهناء والشفاء ✨",
              Colors.greenAccent,
            );
          }
        }
      }
    });
  }

  void _showStatusSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  void _showDeveloperContact() {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF120C05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: BorderSide(
                color: CafeTheme.primaryGold.withValues(alpha: 0.5),
                width: 0.5),
          ),
          title: const Text(
            "تواصل مع المطور 👨‍💻",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: CafeTheme.primaryGold,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Nader Soltan",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const Text(
                "AI Engineer",
                style: TextStyle(
                  fontSize: 12,
                  color: CafeTheme.primaryGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 25),
              _devLink(
                Icons.chat_bubble_outline,
                "WhatsApp",
                Colors.green,
                "https://wa.me/qr/QS4SMJ54AKJMF1",
              ),
              _devLink(
                Icons.facebook_outlined,
                "Facebook",
                Colors.blueAccent,
                "https://www.facebook.com/share/1ByWx21qNW/",
              ),
              _devLink(
                Icons.camera_alt_outlined,
                "Instagram",
                Colors.pinkAccent,
                "https://www.instagram.com/nadersoltan294?igsh=bDB5eTB3Z2NrMmF6",
              ),
              _devLink(
                Icons.video_collection_outlined,
                "TikTok",
                Colors.white,
                "https://www.tiktok.com/@nadersoltan6?_r=1&_t=ZS-93Uf8vOauIB",
              ),
              const Divider(color: Colors.white10, height: 30),
              const Text(
                "Call: 01012078944",
                style: TextStyle(
                  color: CafeTheme.primaryGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _devLink(IconData icon, String label, Color color, String url) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: () => _openUrl(url),
    );
  }

  void _showWaiterLogin() {
    final passwordCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1008),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
          side: BorderSide(
              color: CafeTheme.primaryGold.withValues(alpha: 0.5), width: 0.5),
        ),
        title: const Text(
          'دخول الويتر 🤵',
          textAlign: TextAlign.center,
          style: TextStyle(color: CafeTheme.primaryGold),
        ),
        content: TextField(
          controller: passwordCtrl,
          obscureText: true,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'أدخل كلمة السر',
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CafeTheme.primaryGold,
            ),
            onPressed: () async {
              try {
                await apiService.loginWaiter(passwordCtrl.text);
                if (!context.mounted) return;
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WaiterTerminal(),
                  ),
                );
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('كلمة السر خاطئة!'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              'دخول',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(35),
              width: 380,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: CafeTheme.primaryGold.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildstormLogo(size: 100),
                  const SizedBox(height: 10),
                  const Text(
                    "storm",
                    style: TextStyle(
                      color: CafeTheme.primaryGold,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "مرحباً بك في تجربة الرفاهية ✨",
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 30),
                  _entryField(
                    _nameEntryController,
                    "اسمك الكريم..",
                    Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 15),
                  _entryField(
                    _tableEntryController,
                    "رقم الطاولة..",
                    Icons.table_restaurant_rounded,
                    isNumber: true,
                  ),
                  const SizedBox(height: 25),
                  _buildAnimatedButton(
                    onPressed: _validateAndStart,
                    child: const Text(
                      "ابدأ تجربة الرفاهية ✨",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextButton.icon(
                    onPressed: _showWaiterLogin,
                    icon: const Icon(
                      Icons.lock_person,
                      color: CafeTheme.primaryGold,
                      size: 18,
                    ),
                    label: const Text(
                      "الدخول كويتر",
                      style: TextStyle(
                        color: CafeTheme.primaryGold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
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
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: CafeTheme.primaryGold, size: 20),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  void _validateAndStart() {
    String name = _nameEntryController.text.trim();

    if (name.isEmpty) {
      _showStatusSnackBar("يرجى إدخال الاسم", Colors.redAccent);
      return;
    }

    if (_tableEntryController.text.trim().isEmpty) {
      _showStatusSnackBar("يرجى تحديد رقم الطاولة", Colors.redAccent);
      return;
    }

    currentTable = _tableEntryController.text.trim();

    setState(() {
      registeredName = name;
      _isEntryComplete = true;
    });
    _initStatusListeners();
  }

  Widget _buildAnimatedButton({
    required VoidCallback onPressed,
    required Widget child,
    Color color = CafeTheme.primaryGold,
  }) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
            borderRadius: BorderRadius.circular(20),
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
        Positioned.fill(
          child: Image.asset(
            localBackgroundImage,
            fit: BoxFit.cover,
            color: const Color(0x99080300),
            colorBlendMode: BlendMode.darken,
            errorBuilder: (context, error, stackTrace) =>
                Container(color: CafeTheme.darkBg),
          ),
        ),
        // Frosted glass overlay - نص نص
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(
              color: Colors.black.withValues(alpha: 0.18),
            ),
          ),
        ),
        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(),
            _buildBestSellers(),
            _buildCategories(),
            _buildMenuLabel(),
            _buildProductsGrid(),
            const SliverToBoxAdapter(child: SizedBox(height: 350)),
          ],
        ),
        _buildBottomActionArea(),
      ],
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      backgroundColor: CafeTheme.surface,
      surfaceTintColor: Colors.transparent,
      pinned: true,
      elevation: 0,
      leadingWidth: 150,
      leading: Center(
        child: ScaleTransition(
          scale: Tween(begin: 0.95, end: 1.05).animate(
            CurvedAnimation(
              parent: _devPulseController,
              curve: Curves.easeInOut,
            ),
          ),
          child: GestureDetector(
            onTap: _showDeveloperContact,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: CafeTheme.primaryGold.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.code_rounded,
                    color: CafeTheme.primaryGold,
                    size: 20,
                  ),
                  SizedBox(width: 4),
                  Text(
                    "تواصل مع المطور",
                    style: TextStyle(
                      color: CafeTheme.primaryGold,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        background: Container(color: Colors.transparent),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            buildstormLogo(size: 40),
            const SizedBox(height: 5),
            const Text(
              "storm",
              style: TextStyle(
                color: CafeTheme.primaryGold,
                fontWeight: FontWeight.w900,
                letterSpacing: 5,
                fontSize: 22,
              ),
            ),
            if (registeredName != null)
              Text(
                "طاولة $currentTable | $registeredName",
                style: const TextStyle(fontSize: 10, color: Colors.white60),
              ),
            const SizedBox(height: 15),
          ],
        ),
      ),
      actions: [
        // زرار تغيير الطاولة
        if (registeredName != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: GestureDetector(
              onTap: _showChangeTableDialog,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: CafeTheme.warmBrown.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.table_restaurant_rounded,
                      color: CafeTheme.primaryGold,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "طاولة $currentTable",
                      style: const TextStyle(
                        color: CafeTheme.primaryGold,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        _buildWaiterButton(),
      ],
    );
  }

  Widget _buildWaiterButton() {
    return Padding(
      padding: const EdgeInsets.only(left: 15, top: 15),
      child: GestureDetector(
        onTap: _callWaiter,
        child: AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: CafeTheme.primaryGold.withValues(
                  alpha: 0.4 + (0.6 * _glowController.value),
                ),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Text(
                  _isWaiterAlertActive ? "جاري.." : "نداء",
                  style: const TextStyle(
                    color: CafeTheme.primaryGold,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Icon(
                  Icons.notifications_active_rounded,
                  color: CafeTheme.primaryGold,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBestSellers() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 30, 25, 15),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 18,
                  decoration: const BoxDecoration(gradient: CafeTheme.goldGradient),
                ),
                const SizedBox(width: 10),
                const Text(
                  "🔥 الأكثر طلباً",
                  style: TextStyle(
                    color: CafeTheme.primaryGold,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 210,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .limit(6)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                var items = snapshot.data!.docs;
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    var item = items[index].data() as Map<String, dynamic>;
                    String? imgUrl = item['image_url'];
                    bool hasImage = imgUrl != null && imgUrl.isNotEmpty;
                    bool hasSizes = item['sizes'] != null &&
                        (item['sizes'] as List).isNotEmpty;
                    return GestureDetector(
                      onTap: () => _showAddDialog(item),
                      child: Container(
                        width: 148,
                        margin: const EdgeInsets.symmetric(horizontal: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2A1608), Color(0xFF160D03)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: CafeTheme.primaryGold.withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: CafeTheme.primaryGold.withValues(alpha: 0.12),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // صورة أو placeholder أنيق
                            Expanded(
                              flex: 6,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(24)),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    hasImage
                                        ? Image.network(
                                            imgUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) =>
                                                _bestSellerPlaceholder(
                                                    item['name'] ?? ""),
                                          )
                                        : _bestSellerPlaceholder(
                                            item['name'] ?? ""),
                                    // gradient overlay
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.transparent,
                                              Colors.black
                                                  .withValues(alpha: 0.55),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            stops: const [0.55, 1.0],
                                          ),
                                        ),
                                      ),
                                    ),
                                    // بادج السعر أو الأحجام
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: CafeTheme.deepBrown
                                              .withValues(alpha: 0.9),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: CafeTheme.primaryGold
                                                .withValues(alpha: 0.6),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          hasSizes
                                              ? "✦ أحجام"
                                              : "${item['price']} ج",
                                          style: const TextStyle(
                                            color: CafeTheme.primaryGold,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // اسم المنتج وزرار إضافة
                            Expanded(
                              flex: 3,
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(10, 8, 10, 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['name'] ?? "",
                                        style: const TextStyle(
                                          color: CafeTheme.primaryGoldLight,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          height: 1.2,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            CafeTheme.primaryGold,
                                            CafeTheme.warmBrown
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.add_rounded,
                                          color: Colors.black, size: 18),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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

  Widget _bestSellerPlaceholder(String name) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3A1F08), Color(0xFF1E0D03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CategoryIcons.resolve(name),
            color: CafeTheme.primaryGold.withValues(alpha: 0.5),
            size: 36,
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('categories')
          .orderBy('index')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const SliverToBoxAdapter(child: SizedBox());
        var cats = snapshot.data!.docs;
        if (currentCat == null && cats.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() => currentCat = cats.first['name']);
          });
        }
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 8),
            child: SizedBox(
              height: 46,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                // نضيف عنصر إضافي في الأول لزرار "الكل"
                itemCount: cats.length + 1,
                itemBuilder: (context, index) {
                  // زرار "كل الأقسام" في الأول
                  if (index == 0) {
                    bool isAll = currentCat == null || currentCat == "__all__";
                    return GestureDetector(
                      onTap: () => setState(() => currentCat = cats.isNotEmpty
                          ? cats.first['name']
                          : null),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.only(left: 5, right: 5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF3A2010),
                              Color(0xFF1E0F05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: CafeTheme.primaryGold.withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: CafeTheme.primaryGold.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.grid_view_rounded,
                              color: CafeTheme.primaryGold,
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              "كل الأقسام",
                              style: TextStyle(
                                color: CafeTheme.primaryGold,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  // باقي الأقسام
                  String catName = cats[index - 1]['name'] ?? "";
                  bool isSelected = currentCat == catName;
                  return GestureDetector(
                    onTap: () => setState(() => currentCat = catName),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOut,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [
                                  CafeTheme.primaryGold,
                                  CafeTheme.warmBrown
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isSelected
                            ? null
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: isSelected
                              ? CafeTheme.primaryGold
                              : CafeTheme.warmBrown.withValues(alpha: 0.3),
                          width: 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: CafeTheme.primaryGold
                                      .withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CategoryIcons.resolve(catName),
                            color: isSelected
                                ? Colors.black87
                                : CafeTheme.primaryGold
                                    .withValues(alpha: 0.6),
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            catName,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.black87
                                  : Colors.white60,
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuLabel() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 18,
              decoration: const BoxDecoration(gradient: CafeTheme.goldGradient),
            ),
            const SizedBox(width: 10),
            Text(
              currentCat ?? "",
              style: const TextStyle(
                color: CafeTheme.primaryGoldLight,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Divider(
                color: CafeTheme.warmBrown.withValues(alpha: 0.4),
                thickness: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('cat', isEqualTo: currentCat)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(
            child: Center(
              child: CircularProgressIndicator(color: CafeTheme.primaryGold),
            ),
          );
        }
        var items = snapshot.data!.docs;
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                var item = items[index].data() as Map<String, dynamic>;
                String? imgUrl = item['image_url'];
                bool hasImage = imgUrl != null && imgUrl.isNotEmpty;
                bool hasSizes =
                    item['sizes'] != null && (item['sizes'] as List).isNotEmpty;

                return GestureDetector(
                  onTap: () => _showAddDialog(item),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A0F05),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: CafeTheme.warmBrown.withValues(alpha: 0.28),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // صورة المنتج (فقط لو في صورة حقيقية)
                        if (hasImage)
                          ClipRRect(
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(18),
                            ),
                            child: SizedBox(
                              width: 90,
                              height: 90,
                              child: Image.network(
                                imgUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        // المحتوى النصي
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              hasImage ? 14 : 18,
                              12,
                              14,
                              12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item['name'] ?? "",
                                  style: const TextStyle(
                                    color: CafeTheme.primaryGoldLight,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  hasSizes
                                      ? "✦ متعدد الأحجام"
                                      : "${item['price']} ج.م",
                                  style: TextStyle(
                                    color: CafeTheme.primaryGold
                                        .withValues(alpha: 0.85),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // زرار الإضافة
                        Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  CafeTheme.primaryGold,
                                  CafeTheme.warmBrown
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Colors.black,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                      ],
                    ),
                  ),
                );
              },
              childCount: items.length,
            ),
          ),
        );
      },
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
              backgroundColor: const Color(0xFF1A1008),
              title: Text(
                "تخصيص ${item['name']}",
                textAlign: TextAlign.right,
                style: const TextStyle(color: CafeTheme.primaryGold),
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
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: sizes.map((s) {
                        bool isSelected = selectedSize == s;
                        return ChoiceChip(
                          label: Text("${s['name']} - ${s['price']} ج.م"),
                          selected: isSelected,
                          selectedColor: CafeTheme.primaryGold,
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
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
                    const SizedBox(height: 20),
                  ],
                  TextField(
                    controller: _noteController,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      hintText: "أي إضافات تحب نجهزها لك؟",
                      hintStyle: const TextStyle(
                        color: Colors.white24,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("إلغاء"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CafeTheme.primaryGold,
                  ),
                  onPressed: () {
                    setState(() {
                      String userNote = _noteController.text.isEmpty
                          ? "بدون إضافات"
                          : _noteController.text;

                      String itemName = item['name'];
                      if (selectedSize != null) {
                        itemName += " (${selectedSize!['name']})";
                      }

                      int index = basket.indexWhere(
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
                  },
                  child: const Text(
                    "إضافة",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
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

  Widget _buildBottomActionArea() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(45)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xE6120C05), Color(0xF0080400)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border(
                top: BorderSide(color: CafeTheme.warmBrown, width: 1.5),
              ),
            ),
            child: SafeArea(
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
        var orders = snapshot.data!.docs;
        return Container(
          padding: const EdgeInsets.only(top: 15),
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 25),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              var data = orders[index].data() as Map<String, dynamic>;
              String status = data['status'] ?? "قيد الانتظار";
              Color sColor = status == "جاهز"
                  ? Colors.greenAccent
                  : (status == "جاري التجهيز"
                      ? Colors.orangeAccent
                      : Colors.white38);

              IconData statusIcon = status == "جاهز"
                  ? Icons.check_circle_rounded
                  : (status == "جاري التجهيز"
                      ? Icons.local_cafe_rounded
                      : Icons.hourglass_top_rounded);

              return Container(
                width: 170,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF221408), Color(0xFF1A0F05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                      color: sColor.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(statusIcon, color: sColor, size: 24),
                    const SizedBox(height: 6),
                    Text(
                      status,
                      style: TextStyle(
                        color: sColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    if (data['items_with_qty'] != null)
                      Text(
                        "${(data['items_with_qty'] as List).length} صنف",
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
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
    return Container(
      height: 150,
      padding: const EdgeInsets.only(top: 15),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: basket.length,
        itemBuilder: (context, index) => Container(
          width: 180,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF221408), Color(0xFF1A0F05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
                color: CafeTheme.primaryGold.withValues(alpha: 0.35)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  basket[index]['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
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
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.redAccent),
                    onPressed: () => setState(() {
                      if (basket[index]['quantity'] > 1) {
                        basket[index]['quantity']--;
                      } else {
                        basket.removeAt(index);
                      }
                    }),
                  ),
                  Text(
                    "${basket[index]['quantity']}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline,
                        color: Colors.greenAccent),
                    onPressed: () =>
                        setState(() => basket[index]['quantity']++),
                  ),
                ],
              ),
              if (basket[index]['note'] != "بدون إضافات")
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    "📝 ${basket[index]['note']}",
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.orangeAccent,
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
    double currentBasketTotal = basket.fold(
      0.0,
      (previousValue, item) =>
          previousValue + ((item['price'] as num) * (item['quantity'] as num)),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(35, 20, 35, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "المبلغ الحالي",
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
              Text(
                "${currentBasketTotal.toStringAsFixed(2)} ج.م",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: CafeTheme.primaryGold,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: basket.isEmpty ? null : _sendOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: CafeTheme.warmBrown,
              disabledBackgroundColor:
                  CafeTheme.warmBrown.withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(
                horizontal: 30,
                vertical: 18,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: basket.isEmpty
                      ? Colors.transparent
                      : CafeTheme.primaryGold,
                  width: 1.5,
                ),
              ),
            ),
            child: const Text(
              "تأكيد الطلب ⚡",
              style: TextStyle(
                color: CafeTheme.primaryGoldLight,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendOrder() async {
    if (basket.isEmpty || registeredName == null) return;

    await apiService.createOrder(
      customerName: registeredName!,
      tableNumber: currentTable ?? '?',
      itemsWithQty:
          basket.map((e) => {'name': e['name'], 'qty': e['quantity']}).toList(),
      totalPrice: basket.fold(
        0.0,
        (prev, item) =>
            prev + ((item['price'] as num) * (item['quantity'] as num)),
      ),
      note: basket.any((e) => e['note'] != "بدون إضافات")
          ? basket.firstWhere((e) => e['note'] != "بدون إضافات")['note']
          : "بدون إضافات",
    );

    final itemLines =
        basket.map((e) => '  • ${e['name']} × ${e['quantity']}').join('\n');
    await apiService.sendTelegramMessage(
      '━━━━━━━━━━━━━━━━━━\n'
      '✨ طلب جديد — storm\n'
      '━━━━━━━━━━━━━━━━━━\n'
      '👤 العميل : $registeredName\n'
      '🪑 الطاولة : $currentTable\n'
      '━━━━━━━━━━━━━━━━━━\n'
      '🛒 الطلبات :\n$itemLines\n'
      '━━━━━━━━━━━━━━━━━━\n'
      '💰 الإجمالي : ${basket.fold(0.0, (p, e) => p + ((e['price'] as num) * (e['quantity'] as num))).toStringAsFixed(2)} ج.م\n'
      '━━━━━━━━━━━━━━━━━━',
    );

    setState(() {
      basket.clear();
    });
    _showStatusSnackBar("تم إرسال طلبك! 🚀", Colors.greenAccent);
  }

  // ==========================================
  // تغيير الطاولة
  // ==========================================
  void _showChangeTableDialog() {
    final tableCtrl = TextEditingController(text: currentTable);
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1008),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(
              color: CafeTheme.primaryGold.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          title: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.table_restaurant_rounded,
                  color: CafeTheme.primaryGold, size: 22),
              SizedBox(width: 8),
              Text(
                "تغيير الطاولة",
                style: TextStyle(
                  color: CafeTheme.primaryGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "أنت حالياً على طاولة $currentTable",
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tableCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: "رقم الطاولة الجديدة",
                  hintStyle:
                      const TextStyle(color: Colors.white24, fontSize: 14),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء", style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: CafeTheme.primaryGold,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () {
                String newTable = tableCtrl.text.trim();
                if (newTable.isNotEmpty) {
                  setState(() => currentTable = newTable);
                  Navigator.pop(context);
                  _showStatusSnackBar(
                    "تم التحويل لطاولة $newTable ✨",
                    CafeTheme.primaryGold,
                  );
                }
              },
              child: const Text(
                "تأكيد",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ✦ الإضافة الأولى: بانر ترحيبي ذكي يختفي تلقائياً
  // ==========================================
  Widget _buildWelcomeBanner() {
    if (registeredName == null) return const SizedBox();
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 18, 18, 0),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2A1608), Color(0xFF1E1005)],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: CafeTheme.primaryGold.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [CafeTheme.primaryGold, CafeTheme.warmBrown],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child:
                  const Icon(Icons.waving_hand_rounded, color: Colors.black, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "أهلاً يا $registeredName 👋",
                    style: const TextStyle(
                      color: CafeTheme.primaryGoldLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Text(
                    "اتفضل اختار اللي يعجبك من منيو storm",
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ✦ الإضافة الثانية: شريط "توقيت المطبخ" - وقت الذروة
  // ==========================================
  Widget _buildKitchenStatusBanner() {
    final hour = DateTime.now().hour;
    bool isPeak = (hour >= 12 && hour <= 14) || (hour >= 20 && hour <= 22);
    if (!isPeak) return const SliverToBoxAdapter(child: SizedBox());
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 10, 18, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.orangeAccent.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_fire_department_rounded,
                color: Colors.orangeAccent, size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                "وقت الذروة 🔥 ممكن يتأخر التجهيز شوية — شكراً لصبرك!",
                style: TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ✦ الإضافة الثالثة: قسم "اقتراح اليوم" Premium
  // ==========================================
  Widget _buildDailySpecial() {
    final dayOfWeek = DateTime.now().weekday;
    final specials = [
      {"name": "كولد برو مع كراميل", "emoji": "☕", "note": "عرض الأسبوع"},
      {"name": "موهيتو توت أحمر", "emoji": "🍹", "note": "الأكثر طلباً"},
      {"name": "لاتيه القرفة", "emoji": "🌿", "note": "جديد"},
      {"name": "شوكولاتة بلجيكية", "emoji": "🍫", "note": "مميز"},
      {"name": "فرابتشينو كراميل", "emoji": "🧊", "note": "صيفي"},
      {"name": "ماتشا لاتيه", "emoji": "🍵", "note": "ترند"},
      {"name": "قهوة تركي بالهيل", "emoji": "✨", "note": "كلاسيك"},
    ];
    final special = specials[(dayOfWeek - 1) % specials.length];
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 10, 18, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              CafeTheme.primaryGold.withValues(alpha: 0.15),
              const Color(0xFF1A0F05),
            ],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: CafeTheme.primaryGold.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Text(special['emoji']!, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: CafeTheme.primaryGold,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          special['note']!,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    special['name']!,
                    style: const TextStyle(
                      color: CafeTheme.primaryGoldLight,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    "اقتراح storm لهذا اليوم ✦",
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: CafeTheme.primaryGold, size: 14),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ✦ الإضافة الرابعة: Floating Basket Counter مصغر
  // ==========================================
  int get _basketItemCount =>
      basket.fold(0, (sum, item) => sum + (item['quantity'] as int));

  // ==========================================
  // ✦ الإضافة الخامسة: تحية الوقت في AppBar
  // ==========================================
  String get _timeGreeting {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return "صباح الخير ☀️";
    if (hour >= 12 && hour < 17) return "مساء الخير 🌤️";
    if (hour >= 17 && hour < 21) return "مساء النور 🌙";
    return "ليلة طيبة ✨";
  }

  void _callWaiter() async {
    if (_isWaiterAlertActive || registeredName == null) return;
    setState(() => _isWaiterAlertActive = true);
    await apiService.callWaiter(
      customerName: registeredName!,
      tableNumber: currentTable ?? '?',
    );
    await apiService.sendTelegramMessage(
      '━━━━━━━━━━━━━━━━━━\n'
      '🔔 نداء ويتر — storm\n'
      '━━━━━━━━━━━━━━━━━━\n'
      '👤 العميل : $registeredName\n'
      '🪑 الطاولة : $currentTable\n'
      '━━━━━━━━━━━━━━━━━━\n'
      '⚡ العميل يطلب مساعدة الويتر!',
    );
  }
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
  void initState() {
    super.initState();
    _initWaiterAlerts();
  }

  void _playSound(String url) {
    debugPrint("Playing sound in WaiterTerminal: $url");
  }

  void _playBell() => _playSound(
        "https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3",
      );

  void _playWorkingSound() =>
      _playSound("https://www.soundjay.com/misc/sounds/microwave-hum-1.mp3");

  void _initWaiterAlerts() {
    FirebaseFirestore.instance.collection('orders').snapshots().listen((
      snapshot,
    ) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          var data = change.doc.data() as Map<String, dynamic>;
          String status = data['status'] ?? "";
          String customer = data['customer_name'] ?? "عميل";
          String table = data['table_number']?.toString() ?? "?";

          if (status == 'جاهز') {
            _playBell();
            _showSnack(
              "✅ طلب $customer (طاولة $table) جاهز الآن!",
              Colors.green,
            );
          } else if (status == 'جاري التجهيز') {
            _playWorkingSound();
            _showSnack(
              "☕ بدأ تجهيز طلب $customer (طاولة $table)",
              Colors.orangeAccent,
            );
          }
        }
      }
    });
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
              backgroundColor: const Color(0xFF1A1008),
              title: Text(
                "إضافة ${item['name']}",
                textAlign: TextAlign.right,
                style: const TextStyle(color: CafeTheme.primaryGold),
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
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: sizes.map((s) {
                        bool isSelected = selectedSize == s;
                        return ChoiceChip(
                          label: Text("${s['name']} - ${s['price']} ج.م"),
                          selected: isSelected,
                          selectedColor: CafeTheme.primaryGold,
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
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
                    const SizedBox(height: 20),
                  ],
                  TextField(
                    controller: noteCtrl,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      hintText: "ملاحظات (سكر زيادة، بدون ثلج...)",
                      hintStyle: const TextStyle(
                        color: Colors.white24,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("إلغاء"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CafeTheme.primaryGold,
                  ),
                  onPressed: () {
                    setState(() {
                      String note = noteCtrl.text.isEmpty
                          ? "بدون ملاحظات"
                          : noteCtrl.text;

                      String itemName = item['name'];
                      if (selectedSize != null) {
                        itemName += " (${selectedSize!['name']})";
                      }

                      int idx = waiterBasket.indexWhere(
                        (e) =>
                            e['name'] == itemName &&
                            e['note'] == note &&
                            e['price'] == currentPrice,
                      );

                      if (idx != -1) {
                        waiterBasket[idx]['qty']++;
                      } else {
                        waiterBasket.add({
                          'name': itemName,
                          'price': currentPrice,
                          'qty': 1,
                          'note': note,
                        });
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "إضافة للسلة",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
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
    if (tableCtrl.text.isEmpty || waiterBasket.isEmpty) {
      _showSnack("حدد الطاولة والأصناف أولاً", Colors.orange);
      return;
    }

    double total = waiterBasket.fold(
      0.0,
      (previousValue, e) =>
          previousValue + ((e['price'] as num) * (e['qty'] as num)),
    );

    List<String> notesList = [];
    for (var item in waiterBasket) {
      if (item['note'] != "بدون ملاحظات") {
        notesList.add("${item['name']}: ${item['note']}");
      }
    }

    String notesStr =
        notesList.isEmpty ? "بدون ملاحظات" : notesList.join(" | ");
    String customerName = nameCtrl.text.isEmpty ? "عميل" : nameCtrl.text;

    await apiService.createOrder(
      customerName: customerName,
      tableNumber: tableCtrl.text,
      itemsWithQty: waiterBasket
          .map((e) => {'name': e['name'], 'qty': e['qty']})
          .toList(),
      totalPrice: total,
      note: notesStr,
      orderType: 'داخل المكان (ويتر)',
    );

    final itemLines =
        waiterBasket.map((e) => '  • ${e['name']} × ${e['qty']}').join('\n');
    await apiService.sendTelegramMessage(
      '━━━━━━━━━━━━━━━━━━\n'
      '🤵 طلب ويتر — storm\n'
      '━━━━━━━━━━━━━━━━━━\n'
      '👤 العميل : $customerName\n'
      '🪑 الطاولة : ${tableCtrl.text}\n'
      '━━━━━━━━━━━━━━━━━━\n'
      '🛒 الطلبات :\n$itemLines\n'
      '━━━━━━━━━━━━━━━━━━\n'
      '📝 ملاحظة : $notesStr\n'
      '💰 الإجمالي : ${total.toStringAsFixed(2)} ج.م\n'
      '━━━━━━━━━━━━━━━━━━',
    );

    setState(() => waiterBasket.clear());
    _showSnack("تم الإرسال للباريستا ✅", Colors.green);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  Widget _buildPOSView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: tableCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "رقم الطاولة",
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(
                      Icons.table_restaurant,
                      color: CafeTheme.primaryGold,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "اسم العميل",
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(
                      Icons.person,
                      color: CafeTheme.primaryGold,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  onChanged: (v) => setState(() => searchQuery = v),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "ابحث عن منتج...",
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: CafeTheme.primaryGold,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('categories')
              .orderBy('index')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            var cats = snapshot.data!.docs;
            return SizedBox(
              height: 45,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: cats.length,
                itemBuilder: (c, i) {
                  bool isSelected = selectedCategory == cats[i]['name'];
                  return GestureDetector(
                    onTap: () =>
                        setState(() => selectedCategory = cats[i]['name']),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? CafeTheme.primaryGold
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        cats[i]['name'] ?? "",
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .where('cat', isEqualTo: selectedCategory)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: CafeTheme.primaryGold,
                  ),
                );
              }
              var prods = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                return searchQuery.isEmpty ||
                    (data['name'] ?? "").toString().contains(searchQuery);
              }).toList();

              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: prods.length,
                itemBuilder: (c, i) {
                  var prod = prods[i].data() as Map<String, dynamic>;
                  bool hasSizes = prod['sizes'] != null &&
                      (prod['sizes'] as List).isNotEmpty;
                  String? imgUrl = prod['image_url'];

                  return GestureDetector(
                    onTap: () => _showWaiterAddDialog(prod),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: (imgUrl != null && imgUrl.isNotEmpty)
                                ? Image.network(
                                    imgUrl,
                                    width: 55,
                                    height: 55,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(
                                    Icons.fastfood,
                                    color: CafeTheme.primaryGold,
                                    size: 40,
                                  ),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
                            child: Text(
                              prod['name'],
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            hasSizes ? "أحجام مختلفة" : "${prod['price']} ج.م",
                            style: TextStyle(
                              color: hasSizes
                                  ? Colors.orangeAccent
                                  : CafeTheme.primaryGold,
                              fontWeight: FontWeight.bold,
                              fontSize: hasSizes ? 11 : 12,
                            ),
                          ),
                        ],
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
      stream: FirebaseFirestore.instance
          .collection('orders')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: CafeTheme.primaryGold),
          );
        }
        var orders = snapshot.data!.docs;
        if (orders.isEmpty) {
          return const Center(
            child: Text(
              "لا توجد طلبات حالياً",
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          itemBuilder: (c, i) {
            var data = orders[i].data() as Map<String, dynamic>;
            String status = data['status'] ?? "قيد الانتظار";
            Color sColor = status == "جاهز"
                ? Colors.greenAccent
                : (status == "جاري التجهيز"
                    ? Colors.orangeAccent
                    : Colors.white38);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: sColor.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "طاولة ${data['table_number'] ?? '?'}",
                        style: const TextStyle(
                          color: CafeTheme.primaryGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: sColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: sColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: sColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data['customer_name'] ?? "",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _statusButton(
                        "قيد الانتظار",
                        Colors.white38,
                        status,
                        orders[i].id,
                      ),
                      const SizedBox(width: 8),
                      _statusButton(
                        "جاري التجهيز",
                        Colors.orangeAccent,
                        status,
                        orders[i].id,
                      ),
                      const SizedBox(width: 8),
                      _statusButton(
                        "جاهز",
                        Colors.greenAccent,
                        status,
                        orders[i].id,
                      ),
                    ],
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
    bool isSelected = currentStatus == label;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          await FirebaseFirestore.instance
              .collection('orders')
              .doc(docId)
              .update({'status': label});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? color : Colors.white10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? color : Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.bold,
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
        backgroundColor: const Color(0xFF0A0600),
        appBar: AppBar(
          backgroundColor: CafeTheme.surface,
          title: const Text(
            "لوحة الويتر 🤵",
            style: TextStyle(
              color: CafeTheme.primaryGold,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: const Color(0xFF120C05),
          selectedItemColor: CafeTheme.primaryGold,
          unselectedItemColor: Colors.white54,
          currentIndex: _currentTabIndex,
          onTap: (index) {
            setState(() {
              _currentTabIndex = index;
            });
          },
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
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: CafeTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: waiterBasket.length,
              itemBuilder: (context, index) {
                var item = waiterBasket[index];
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  padding: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
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
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                if (item['qty'] > 1) {
                                  item['qty']--;
                                } else {
                                  waiterBasket.removeAt(index);
                                }
                              });
                            },
                          ),
                          Text(
                            "${item['qty']}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: Colors.greenAccent,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                item['qty']++;
                              });
                            },
                          ),
                          SizedBox(
                            width: 70,
                            child: Text(
                              "${(item['qty'] as num) * (item['price'] as num)} ج.م",
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontSize: 12,
                                color: CafeTheme.primaryGold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (item['note'] != null &&
                          item['note'] != "بدون ملاحظات")
                        Padding(
                          padding: const EdgeInsets.only(right: 5, bottom: 5),
                          child: Text(
                            "📝 ${item['note']}",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 25),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: _sendToBarista,
              child: const Text(
                "إرسال للباريستا 🚀",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
