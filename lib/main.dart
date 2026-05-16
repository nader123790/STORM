import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:ui';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

import 'firebase_options.dart';
import 'services/api_service.dart';

// ==========================================
// Singleton ApiService
// ==========================================
final ApiService apiService = ApiService();

// ==========================================
// Utility class for Category Icons
// ==========================================
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

// ==========================================
// Optimized image widget - lightweight & smooth
// ==========================================
class FastNetworkImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final Widget Function(BuildContext) placeholder;
  final int? cacheWidth;
  final int? cacheHeight;
  const FastNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    required this.placeholder,
    this.cacheWidth,
    this.cacheHeight,
  });
  @override
  State<FastNetworkImage> createState() => _FastNetworkImageState();
}

class _FastNetworkImageState extends State<FastNetworkImage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Image.network(
      widget.url,
      fit: widget.fit,
      cacheWidth: widget.cacheWidth ?? 400,
      cacheHeight: widget.cacheHeight ?? 400,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        if (frame != null) {
          _fadeCtrl.forward();
          return FadeTransition(opacity: _fadeAnim, child: child);
        }
        return widget.placeholder(context);
      },
      errorBuilder: (c, e, s) => widget.placeholder(c),
    );
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
  bool _nameLoadedFromStorage = false; // ✦ هل الاسم محفوظ من زيارة سابقة؟

  // ✦ ميزة 1: بحث في المنيو
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  bool _showSearch = false;

  // ✦ ميزة 2: المفضلة
  final Set<String> _favorites = {};
  bool _showFavoritesOnly = false;

  // ✦ ميزة 4: وضع العرض
  bool _isGridView = false;

  // ✦ عدد الأكثر طلباً المعروض (قابل للتوسيع بالسهم)
  int _bestSellersLimit = 5;

  // ✦ ميزة جديدة 1: عداد الوقت (clock) يُعرض في الهيدر
  String _currentTime = "";
  // ✦ ميزة جديدة 2: تتبع آخر صنف تم إضافته (toast أنيق)
  String? _lastAddedItem;
  // ✦ ميزة جديدة 3: وضع المظهر الليلي الإضافي (تعتيم أكثر)
  bool _isDimMode = false;

  // ✦ الطقس الذكي للاقتراح اليومي
  double? _weatherTemp;
  String _weatherCondition = "";
  String _weatherEmoji = "🌤️";
  // ✦ ميزة جديدة 4: العروض والخصومات بانر دوّار
  int _promoBannerIndex = 0;
  final List<String> _promoMessages = [
    "☕ اشرب قهوتك بكل راحة ✨",
    "🔥 جرب الأكثر طلباً النهارده!",
    "🎉 اطلب أكتر من 3 أصناف واستمتع بتجربة مميزة",
    "⭐ رأيك يهمنا - شاركنا تقييمك",
    "💛 storm | تجربة الرفاهية الحقيقية",
  ];

  late AnimationController _glowController;
  late AnimationController _devPulseController;
  late AnimationController _promoController;

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

    // ✦ تحميل الاسم المحفوظ من localStorage
    _loadSavedName();
    _fetchWeather();

    _devPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // ✦ ميزة جديدة 1: ساعة حية
    _updateTime();
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 30));
      if (!mounted) return false;
      _updateTime();
      return true;
    });

    // ✦ ميزة جديدة 4: بانر عروض دوّار
    _promoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) return false;
      _promoController.forward(from: 0);
      setState(() {
        _promoBannerIndex = (_promoBannerIndex + 1) % _promoMessages.length;
      });
      return true;
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    setState(() => _currentTime = "$h:$m");
  }

  // ==========================================
  // ✦ حفظ وتحميل الاسم من localStorage
  // ==========================================
  void _loadSavedName() {
    try {
      final saved = js.context.callMethod('eval', [
        'window.localStorage.getItem("storm_customer_name")'
      ]);
      if (saved != null && saved.toString().isNotEmpty) {
        final name = saved.toString();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              registeredName = name;
              _nameEntryController.text = name;
              _nameLoadedFromStorage = true;
            });
          }
        });
      }
    } catch (e) {
      debugPrint("localStorage load error: $e");
    }
  }

  void _saveNameToStorage(String name) {
    try {
      js.context.callMethod('eval', [
        'window.localStorage.setItem("storm_customer_name", "${name.replaceAll('"', '\\"')}")'
      ]);
    } catch (e) {
      debugPrint("localStorage save error: $e");
    }
  }

  // ==========================================
  // ✦ جلب الطقس من Open-Meteo (مجاني بدون API key)
  // المنطق: القاهرة/مصر بشكل افتراضي — إحداثيات 30.06°N 31.22°E
  // ==========================================
  void _fetchWeather() {
    try {
      // نستخدم Open-Meteo API — مجانية 100%
      // current_weather يرجع: temperature, weathercode, windspeed
      const url =
          'https://api.open-meteo.com/v1/forecast'
          '?latitude=31.4&longitude=31.1'
          '&current_weather=true'
          '&temperature_unit=celsius';

      js.context.callMethod('eval', ['''
        (async function() {
          try {
            const r = await fetch("$url");
            const d = await r.json();
            const t = d.current_weather.temperature;
            const c = d.current_weather.weathercode;
            window._stormWeatherTemp = t;
            window._stormWeatherCode = c;
          } catch(e) {
            window._stormWeatherTemp = null;
            window._stormWeatherCode = null;
          }
        })();
      '''.replaceAll('\$url', url)]);

      // نقرأ النتيجة بعد ٣ ثواني
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        try {
          final temp = js.context['_stormWeatherTemp'];
          final code = js.context['_stormWeatherCode'];
          if (temp != null) {
            final t = (temp as num).toDouble();
            final c = (code as num?)?.toInt() ?? 0;
            setState(() {
              _weatherTemp = t;
              _weatherCondition = _mapWeatherCode(c);
              _weatherEmoji = _mapWeatherEmoji(c, t);
            });
          }
        } catch (e) {
          debugPrint("Weather read error: $e");
        }
      });
    } catch (e) {
      debugPrint("Weather fetch error: $e");
    }
  }

  // ✦ ترجمة weather code لحالة مقروءة
  String _mapWeatherCode(int code) {
    if (code == 0) return "صافي";
    if (code <= 3) return "غائم جزئياً";
    if (code <= 49) return "ضبابي";
    if (code <= 67) return "ممطر";
    if (code <= 77) return "ثلجي";
    if (code <= 82) return "أمطار غزيرة";
    if (code <= 99) return "عاصفة";
    return "متغير";
  }

  // ✦ إيموجي الطقس
  String _mapWeatherEmoji(int code, double temp) {
    if (code == 0 && temp > 30) return "🔥";
    if (code == 0) return "☀️";
    if (code <= 3) return "⛅";
    if (code <= 49) return "🌫️";
    if (code <= 67) return "🌧️";
    if (code <= 77) return "❄️";
    if (code <= 82) return "⛈️";
    return "🌩️";
  }

  // ==========================================
  // ✦ المنطق الذكي للاقتراح — يجمع ٣ عوامل:
  //   ١. الطقس (حار/بارد/ممطر)
  //   ٢. الوقت في اليوم (صباح/ظهر/مساء/ليل)
  //   ٣. الأكثر طلباً من Firebase
  // ==========================================
  Map<String, dynamic> _buildSmartSuggestion(
      List<Map<String, dynamic>> topProducts) {
    final hour = DateTime.now().hour;
    final temp = _weatherTemp ?? 25.0;
    final condition = _weatherCondition;

    // ── تحديد الوقت ──
    String timeSlot;
    String timeLabel;
    if (hour >= 5 && hour < 10) {
      timeSlot = "morning";
      timeLabel = "الصبح";
    } else if (hour >= 10 && hour < 14) {
      timeSlot = "noon";
      timeLabel = "الضهر";
    } else if (hour >= 14 && hour < 19) {
      timeSlot = "afternoon";
      timeLabel = "بعد الضهر";
    } else if (hour >= 19 && hour < 23) {
      timeSlot = "evening";
      timeLabel = "المساء";
    } else {
      timeSlot = "night";
      timeLabel = "الليل";
    }

    // ── تحديد حالة الطقس ──
    bool isHot = temp > 28;
    bool isCold = temp < 18;
    bool isRainy = condition.contains("ممطر") || condition.contains("عاصفة");

    // ── بناء قائمة أولويات الكلمات المفتاحية ──
    // بناءً على الطقس + الوقت
    List<String> preferredKeywords = [];

    if (isRainy || isCold) {
      // طقس بارد أو ممطر → يفضل المشروبات الساخنة
      if (timeSlot == "morning" || timeSlot == "noon") {
        preferredKeywords = ["قهوة", "اسبريسو", "شاي", "لاتيه", "كابتشينو", "موكا"];
      } else {
        preferredKeywords = ["شاي", "قهوة", "لاتيه", "شوكولاتة", "هوت"];
      }
    } else if (isHot) {
      // طقس حار → يفضل المشروبات الباردة
      if (timeSlot == "morning") {
        preferredKeywords = ["قهوة", "كولد برو", "آيس", "لاتيه"];
      } else {
        preferredKeywords = ["عصير", "موهيتو", "فرابتشينو", "كولد", "آيس", "مثلجات", "سموزي", "ليمون"];
      }
    } else {
      // طقس معتدل
      if (timeSlot == "morning") {
        preferredKeywords = ["قهوة", "اسبريسو", "لاتيه", "كابتشينو"];
      } else if (timeSlot == "noon" || timeSlot == "afternoon") {
        preferredKeywords = ["عصير", "موهيتو", "كولد", "آيس"];
      } else {
        preferredKeywords = ["شاي", "قهوة", "حلى", "كيك", "ديزرت"];
      }
    }

    // ── ابحث عن أفضل منتج من الأكثر طلباً يطابق الكلمات المفضلة ──
    Map<String, dynamic>? bestMatch;
    int bestScore = -1;

    for (var product in topProducts) {
      final name = (product['name'] ?? '').toString().toLowerCase();
      int score = 0;

      // الأكثر طلباً له أولوية أساسية
      final orderCount = (product['order_count'] as num?)?.toInt() ?? 0;
      score += (orderCount > 50 ? 3 : orderCount > 20 ? 2 : orderCount > 5 ? 1 : 0);

      // مطابقة الكلمات المفضلة
      for (int ki = 0; ki < preferredKeywords.length; ki++) {
        if (name.contains(preferredKeywords[ki])) {
          score += (preferredKeywords.length - ki) * 2; // الأول له أعلى وزن
          break;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = product;
      }
    }

    final product = bestMatch ?? (topProducts.isNotEmpty ? topProducts.first : {});
    final productName = product['name'] ?? "اكتشف أحلى طلب";
    final orderCount = (product['order_count'] as num?)?.toInt() ?? 0;

    // ── بناء السبب الذكي ──
    String reason;
    if (isRainy) {
      reason = "الجو ممطر — $productName مثالي 🌧️";
    } else if (isCold) {
      reason = "الجو برد — $productName يدفيك ☕";
    } else if (isHot) {
      reason = "الجو حر — $productName يبردك 🧊";
    } else {
      reason = "طقس $condition — اقتراح $timeLabel ✨";
    }

    String badge = orderCount > 0
        ? "🔥 طُلب $orderCount مرة"
        : "⭐ اقتراح $timeLabel";

    return {
      'product': product,
      'name': productName,
      'reason': reason,
      'badge': badge,
      'timeLabel': timeLabel,
      'weatherInfo': _weatherTemp != null
          ? "${_weatherTemp!.toStringAsFixed(0)}° $condition $_weatherEmoji"
          : "",
    };
  }


  @override
  void dispose() {
    _glowController.dispose();
    _devPulseController.dispose();
    _promoController.dispose();
    _noteController.dispose();
    _nameEntryController.dispose();
    _tableEntryController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _playSound(String url) {
    try {
      js.context.callMethod('eval', [
        'try { var a = new Audio("$url"); a.play().catch(function(){}); } catch(e){}'
      ]);
    } catch (e) {
      debugPrint("Sound error: $e");
    }
  }

  void _openUrl(String url) {
    try {
      js.context.callMethod('open', [url, '_blank']);
    } catch (e) {
      debugPrint("URL open error: $e");
    }
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
          String status = data['status'] ?? '';
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
    if (!mounted) return;
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
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A1008), Color(0xFF0D0904)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: CafeTheme.primaryGold.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: CafeTheme.primaryGold.withValues(alpha: 0.15),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        CafeTheme.primaryGold.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    children: [
                      AnimatedBuilder(
                        animation: _devPulseController,
                        builder: (context, child) => Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                CafeTheme.primaryGold,
                                CafeTheme.warmBrown,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: CafeTheme.primaryGold.withValues(
                                  alpha: 0.3 + 0.3 * _devPulseController.value,
                                ),
                                blurRadius: 20,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: Colors.black,
                            size: 46,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Nader Soltan",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              CafeTheme.primaryGold,
                              CafeTheme.warmBrown
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "✦ AI Engineer & Flutter Dev",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Column(
                    children: [
                      _devContactTile(
                        Icons.chat_rounded,
                        "WhatsApp",
                        "تواصل مباشرة",
                        const Color(0xFF25D366),
                        const Color(0xFF128C7E),
                        "https://wa.me/qr/QS4SMJ54AKJMF1",
                      ),
                      _devContactTile(
                        Icons.facebook_rounded,
                        "Facebook",
                        "تابعني على فيسبوك",
                        const Color(0xFF1877F2),
                        const Color(0xFF0D47A1),
                        "https://www.facebook.com/share/1ByWx21qNW/",
                      ),
                      _devContactTile(
                        Icons.camera_alt_rounded,
                        "Instagram",
                        "شوف أعمالي",
                        const Color(0xFFE1306C),
                        const Color(0xFF833AB4),
                        "https://www.instagram.com/nadersoltan294?igsh=bDB5eTB3Z2NrMmF6",
                      ),
                      _devContactTile(
                        Icons.music_note_rounded,
                        "TikTok",
                        "محتوى تقني حلو",
                        Colors.white,
                        Colors.grey.shade800,
                        "https://www.tiktok.com/@nadersoltan6?_r=1&_t=ZS-93Uf8vOauIB",
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: CafeTheme.primaryGold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: CafeTheme.primaryGold.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.phone_rounded,
                        color: CafeTheme.primaryGold,
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Text(
                        "01012078944",
                        style: TextStyle(
                          color: CafeTheme.primaryGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1,
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
    );
  }

  Widget _devContactTile(
    IconData icon,
    String platform,
    String subtitle,
    Color colorFrom,
    Color colorTo,
    String url,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _openUrl(url);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorFrom.withValues(alpha: 0.12),
              colorTo.withValues(alpha: 0.06),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colorFrom.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorFrom, colorTo],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    platform,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: colorFrom.withValues(alpha: 0.7),
              size: 14,
            ),
          ],
        ),
      ),
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
                  // ✦ لو الاسم محفوظ نرحب بيه بالاسم
                  if (_nameLoadedFromStorage && registeredName != null)
                    Column(
                      children: [
                        Text(
                          "أهلاً بعودتك يا $registeredName 👋",
                          style: const TextStyle(
                            color: CafeTheme.primaryGoldLight,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "تفضل اكتب رقم طاولتك ✨",
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    )
                  else
                    const Text(
                      "مرحباً بك في تجربة الرفاهية ✨",
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  const SizedBox(height: 30),
                  // ✦ حقل الاسم: يظهر بس لو مش محفوظ
                  if (!_nameLoadedFromStorage) ...[
                    _entryField(
                      _nameEntryController,
                      "اسمك الكريم..",
                      Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 15),
                  ],
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
                  const SizedBox(height: 10),
                  // ✦ زرار تغيير الاسم لو كان محفوظ
                  if (_nameLoadedFromStorage)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _nameLoadedFromStorage = false;
                          _nameEntryController.clear();
                          registeredName = null;
                        });
                      },
                      child: const Text(
                        "مش أنا؟ غيّر الاسم",
                        style: TextStyle(
                          color: Colors.white30,
                          fontSize: 11,
                        ),
                      ),
                    ),
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
    // لو الاسم محفوظ من قبل، نستخدمه مباشرة
    String name = _nameLoadedFromStorage && registeredName != null
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

    // ✦ حفظ الاسم في localStorage للمرات القادمة
    _saveNameToStorage(name);

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
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(
              color: Colors.black.withValues(alpha: _isDimMode ? 0.45 : 0.18),
            ),
          ),
        ),
        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(),
            _buildWelcomeBanner(),
            // ✦ ميزة جديدة 4: بانر العروض الدوّار
            _buildPromoBanner(),
            _buildKitchenStatusBanner(),
            _buildDailySpecial(),
            _buildBestSellers(),
            // ✦ ميزة 1: شريط البحث والفلاتر
            _buildSearchAndFilterBar(),
            _buildCategories(),
            _buildMenuLabel(),
            _buildProductsGrid(),
            const SliverToBoxAdapter(child: SizedBox(height: 350)),
          ],
        ),
        // ✦ ميزة جديدة 2: toast آخر صنف مضاف
        if (_lastAddedItem != null)
          Positioned(
            bottom: 130,
            left: 0,
            right: 0,
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.elasticOut,
                builder: (context, v, child) => Transform.scale(
                  scale: v,
                  child: child,
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        CafeTheme.primaryGold,
                        CafeTheme.warmBrown,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: CafeTheme.primaryGold.withValues(alpha: 0.4),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.black, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'أُضيف: $_lastAddedItem ✨',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        _buildBottomActionArea(),
      ],
    );
  }

  // ✦ ميزة جديدة 4: بانر العروض الدوّار
  Widget _buildPromoBanner() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: AnimatedBuilder(
          animation: _promoController,
          builder: (context, child) => Opacity(
            opacity: (1.0 - _promoController.value * 0.5).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, _promoController.value * -4),
              child: child,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  CafeTheme.primaryGold.withValues(alpha: 0.12),
                  CafeTheme.warmBrown.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: CafeTheme.primaryGold.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.campaign_rounded,
                    color: CafeTheme.primaryGold, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _promoMessages[_promoBannerIndex],
                    style: const TextStyle(
                      color: CafeTheme.primaryGoldLight,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: CafeTheme.primaryGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${_promoBannerIndex + 1}/${_promoMessages.length}",
                    style: const TextStyle(
                      color: CafeTheme.primaryGold,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
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
            GestureDetector(
              onTap: () {
                try {
                  js.context.callMethod('eval', ['window.location.reload();']);
                } catch (e) {
                  debugPrint("Reload error: $e");
                }
              },
              child: buildstormLogo(size: 40),
            ),
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
                "$_timeGreeting | طاولة $currentTable | $registeredName",
                style: const TextStyle(fontSize: 10, color: Colors.white60),
              ),
            const SizedBox(height: 15),
          ],
        ),
      ),
      actions: [
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
        // ✦ ميزة جديدة 1: ساعة + ميزة جديدة 3: وضع التعتيم
        Padding(
          padding: const EdgeInsets.only(left: 10, top: 12, right: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => setState(() => _isDimMode = !_isDimMode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _isDimMode
                        ? CafeTheme.primaryGold.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          _isDimMode ? CafeTheme.primaryGold : Colors.white10,
                    ),
                  ),
                  child: Icon(
                    _isDimMode
                        ? Icons.brightness_3_rounded
                        : Icons.brightness_6_rounded,
                    color: _isDimMode ? CafeTheme.primaryGold : Colors.white38,
                    size: 14,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              if (_currentTime.isNotEmpty)
                Text(
                  _currentTime,
                  style: const TextStyle(
                    color: CafeTheme.primaryGold,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
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

  // ==========================================
  // ✦ ميزة 1: شريط البحث والفلاتر
  // ==========================================
  Widget _buildSearchAndFilterBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          children: [
            Row(
              children: [
                // زرار البحث
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showSearch = !_showSearch;
                      if (!_showSearch) {
                        _searchQuery = "";
                        _searchController.clear();
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _showSearch
                          ? CafeTheme.primaryGold.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _showSearch
                            ? CafeTheme.primaryGold
                            : CafeTheme.warmBrown.withValues(alpha: 0.3),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: _showSearch
                              ? CafeTheme.primaryGold
                              : Colors.white54,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "بحث",
                          style: TextStyle(
                            color: _showSearch
                                ? CafeTheme.primaryGold
                                : Colors.white54,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // ✦ ميزة 2: زرار المفضلة
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showFavoritesOnly = !_showFavoritesOnly;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _showFavoritesOnly
                          ? Colors.red.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _showFavoritesOnly
                            ? Colors.redAccent
                            : CafeTheme.warmBrown.withValues(alpha: 0.3),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showFavoritesOnly
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: _showFavoritesOnly
                              ? Colors.redAccent
                              : Colors.white54,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "المفضلة",
                          style: TextStyle(
                            color: _showFavoritesOnly
                                ? Colors.redAccent
                                : Colors.white54,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_favorites.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "${_favorites.length}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // ✦ ميزة 4: تبديل العرض Grid/List
                GestureDetector(
                  onTap: () {
                    setState(() => _isGridView = !_isGridView);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: CafeTheme.warmBrown.withValues(alpha: 0.3),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      _isGridView
                          ? Icons.view_list_rounded
                          : Icons.grid_view_rounded,
                      color: CafeTheme.primaryGold,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            // حقل البحث
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _showSearch
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          hintText: "ابحث عن أي صنف...",
                          hintStyle: const TextStyle(
                              color: Colors.white38, fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: CafeTheme.primaryGold, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _searchQuery = "";
                                      _searchController.clear();
                                    });
                                  },
                                  child: const Icon(Icons.close_rounded,
                                      color: Colors.white38, size: 18),
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
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
                  decoration:
                      const BoxDecoration(gradient: CafeTheme.goldGradient),
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
                const Spacer(),
                // ✦ زرار "عرض أكثر" — يوسّع القائمة ويرتبها من الأكثر للأقل
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _bestSellersLimit += 5;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          CafeTheme.primaryGold,
                          CafeTheme.warmBrown,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color:
                              CafeTheme.primaryGold.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "عرض أكثر",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.black,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 210,
            child: StreamBuilder<QuerySnapshot>(
              // ✦ جيب المنتجات مرتبة بناءً على order_count الحقيقي من Firebase
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .orderBy('order_count', descending: true)
                  .limit(_bestSellersLimit)
                  .snapshots(),
              builder: (context, snapshot) {
                // ✦ fallback: لو مفيش order_count نجيب بدون ترتيب
                if (snapshot.hasError ||
                    (!snapshot.hasData && snapshot.connectionState ==
                        ConnectionState.done)) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('products')
                        .limit(_bestSellersLimit)
                        .snapshots(),
                    builder: (context, snap2) {
                      if (!snap2.hasData) return const SizedBox();
                      return _buildBestSellersHorizontalList(
                          snap2.data!.docs);
                    },
                  );
                }
                if (!snapshot.hasData) return const SizedBox();
                var items = snapshot.data!.docs;
                // ✦ ترتيب يدوي احتياطي لو order_count مش موجود
                items.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aCount = (aData['order_count'] as num?)?.toInt() ?? 0;
                  final bCount = (bData['order_count'] as num?)?.toInt() ?? 0;
                  return bCount.compareTo(aCount);
                });
                return _buildBestSellersHorizontalList(items);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBestSellersHorizontalList(
      List<QueryDocumentSnapshot> items) {
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
        String itemName = item['name'] ?? '';
        int qtyInBasket = basket
            .where(
                (e) => (e['name'] as String).startsWith(itemName))
            .fold(0, (s, e) => s + (e['quantity'] as int));
        // ✦ عدد الطلبات الحقيقي
        final orderCount =
            (item['order_count'] as num?)?.toInt() ?? 0;

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
                color: qtyInBasket > 0
                    ? CafeTheme.primaryGold
                    : CafeTheme.primaryGold.withValues(alpha: 0.35),
                width: qtyInBasket > 0 ? 2 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      CafeTheme.primaryGold.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 6,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24)),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            hasImage
                                ? FastNetworkImage(
                                    url: imgUrl!,
                                    fit: BoxFit.cover,
                                    cacheWidth: 300,
                                    cacheHeight: 300,
                                    placeholder: (c) =>
                                        _bestSellerPlaceholder(
                                            item['name'] ?? ""),
                                  )
                                : _bestSellerPlaceholder(
                                    item['name'] ?? ""),
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
                                      : "${item['price'] ?? '—'} ج",
                                  style: const TextStyle(
                                    color: CafeTheme.primaryGold,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            // ✦ شارة عدد الطلبات الحقيقي
                            if (orderCount > 0)
                              Positioned(
                                bottom: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black
                                        .withValues(alpha: 0.65),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.local_fire_department_rounded,
                                        color: Colors.orangeAccent,
                                        size: 11,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        "$orderCount طلب",
                                        style: const TextStyle(
                                          color: Colors.orangeAccent,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            // ✦ ميزة 2: زرار المفضلة
                            Positioned(
                              top: 8,
                              left: 8,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (_favorites
                                        .contains(itemName)) {
                                      _favorites.remove(itemName);
                                    } else {
                                      _favorites.add(itemName);
                                    }
                                  });
                                },
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.black
                                        .withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _favorites.contains(itemName)
                                        ? Icons.favorite_rounded
                                        : Icons
                                            .favorite_border_rounded,
                                    color: _favorites
                                            .contains(itemName)
                                        ? Colors.redAccent
                                        : Colors.white54,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.center,
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
                                borderRadius:
                                    BorderRadius.circular(10),
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
                // ✦ ميزة 3: عداد الكميات على الكارد
                if (qtyInBasket > 0)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: CafeTheme.primaryGold,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          "$qtyInBasket",
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(child: SizedBox());
        }
        var cats = snapshot.data!.docs;
        if (currentCat == null && cats.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => currentCat = cats.first['name']);
          });
        }

        // ==========================================
        // دالة فتح ويندو اختيار القسم
        // ==========================================
        void showCategoryPicker() {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (ctx) => BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 520),
                decoration: BoxDecoration(
                  color: const Color(0xFF180E04),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(30)),
                  border: Border.all(
                    color: CafeTheme.primaryGold.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: CafeTheme.primaryGold.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "اختار القسم",
                      style: TextStyle(
                        color: CafeTheme.primaryGold,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: GridView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.8,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: cats.length + 1,
                        itemBuilder: (ctx2, i) {
                          bool isAll = i == 0;
                          String catN =
                              isAll ? "__all__" : cats[i - 1]['name'] ?? "";
                          bool isSelected = currentCat == catN;
                          return GestureDetector(
                            onTap: () {
                              setState(() => currentCat = catN);
                              Navigator.pop(ctx);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
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
                                    : Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? CafeTheme.primaryGold
                                      : CafeTheme.warmBrown
                                          .withValues(alpha: 0.3),
                                  width: 1.2,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: CafeTheme.primaryGold
                                              .withValues(alpha: 0.4),
                                          blurRadius: 10,
                                        )
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isAll
                                        ? Icons.grid_view_rounded
                                        : CategoryIcons.resolve(catN),
                                    color: isSelected
                                        ? Colors.black87
                                        : CafeTheme.primaryGold
                                            .withValues(alpha: 0.7),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      isAll ? "كل الأقسام" : catN,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.black87
                                            : Colors.white70,
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
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
          );
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
                itemCount: cats.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    bool isAllSelected = currentCat == "__all__";
                    return GestureDetector(
                      onTap: showCategoryPicker,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.only(left: 5, right: 5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: isAllSelected
                              ? const LinearGradient(
                                  colors: [
                                    CafeTheme.primaryGold,
                                    CafeTheme.warmBrown
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : const LinearGradient(
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
                              color:
                                  CafeTheme.primaryGold.withValues(alpha: 0.2),
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
                              color: isAllSelected
                                  ? Colors.black87
                                  : CafeTheme.primaryGold,
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "كل الأقسام",
                              style: TextStyle(
                                color: isAllSelected
                                    ? Colors.black87
                                    : CafeTheme.primaryGold,
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
                                : CafeTheme.primaryGold.withValues(alpha: 0.6),
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            catName,
                            style: TextStyle(
                              color:
                                  isSelected ? Colors.black87 : Colors.white60,
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
              _showFavoritesOnly
                  ? "❤️ المفضلة"
                  : _searchQuery.isNotEmpty
                      ? "🔍 نتائج البحث"
                      : (currentCat == "__all__"
                          ? "كل الأقسام"
                          : (currentCat ?? "")),
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

  // ==========================================
  // ✦ ميزة 4: Products Grid / List view
  // ==========================================
  Widget _buildProductsGrid() {
    final Stream<QuerySnapshot> stream = (currentCat == "__all__" ||
            _searchQuery.isNotEmpty ||
            _showFavoritesOnly)
        ? FirebaseFirestore.instance.collection('products').snapshots()
        : FirebaseFirestore.instance
            .collection('products')
            .where('cat', isEqualTo: currentCat)
            .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(
            child: Center(
              child: CircularProgressIndicator(color: CafeTheme.primaryGold),
            ),
          );
        }

        var allItems = snapshot.data!.docs;

        // فلترة البحث
        if (_searchQuery.isNotEmpty) {
          allItems = allItems.where((doc) {
            var d = doc.data() as Map<String, dynamic>;
            return (d['name'] ?? '').toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );
          }).toList();
        }

        // فلترة المفضلة
        if (_showFavoritesOnly) {
          allItems = allItems.where((doc) {
            var d = doc.data() as Map<String, dynamic>;
            return _favorites.contains(d['name'] ?? '');
          }).toList();
        }

        if (allItems.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(
                    _showFavoritesOnly
                        ? Icons.favorite_border_rounded
                        : Icons.search_off_rounded,
                    color: Colors.white24,
                    size: 50,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _showFavoritesOnly
                        ? "لا توجد أصناف في المفضلة بعد"
                        : "لا توجد نتائج للبحث",
                    style: const TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        // ✦ Grid View
        if (_isGridView) {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.82,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  var item = allItems[index].data() as Map<String, dynamic>;
                  return _buildGridCard(item);
                },
                childCount: allItems.length,
              ),
            ),
          );
        }

        // ✦ List View (الافتراضي)
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                var item = allItems[index].data() as Map<String, dynamic>;
                return _buildListCard(item);
              },
              childCount: allItems.length,
            ),
          ),
        );
      },
    );
  }

  // كارد القائمة (List)
  Widget _buildListCard(Map<String, dynamic> item) {
    String? imgUrl = item['image_url'];
    bool hasImage = imgUrl != null && imgUrl.isNotEmpty;
    bool hasSizes = item['sizes'] != null && (item['sizes'] as List).isNotEmpty;
    String itemName = item['name'] ?? '';
    bool isFav = _favorites.contains(itemName);
    // ✦ ميزة 3: عداد الكميات
    int qtyInBasket = basket
        .where((e) => (e['name'] as String).startsWith(itemName))
        .fold(0, (s, e) => s + (e['quantity'] as int));

    return GestureDetector(
      onTap: () => _showAddDialog(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 90,
        decoration: BoxDecoration(
          color: const Color(0xFF1A0F05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: qtyInBasket > 0
                ? CafeTheme.primaryGold
                : CafeTheme.warmBrown.withValues(alpha: 0.28),
            width: qtyInBasket > 0 ? 1.8 : 1,
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
            // صورة
            if (hasImage)
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(18),
                ),
                child: SizedBox(
                  width: 90,
                  height: 90,
                  child: FastNetworkImage(
                    url: imgUrl!,
                    fit: BoxFit.cover,
                    cacheWidth: 180,
                    cacheHeight: 180,
                    placeholder: (c) => Container(
                      color: const Color(0xFF2A1608),
                      child: Icon(
                        CategoryIcons.resolve(itemName),
                        color: CafeTheme.primaryGold.withValues(alpha: 0.4),
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
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
                      itemName,
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
                    Row(
                      children: [
                        Text(
                          hasSizes
                              ? "✦ متعدد الأحجام"
                              : "${item['price'] ?? '—'} ج.م",
                          style: TextStyle(
                            color:
                                CafeTheme.primaryGold.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        // ✦ ميزة 3: عداد الكميات
                        if (qtyInBasket > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: CafeTheme.primaryGold,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "في السلة: $qtyInBasket",
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // زرار المفضلة
            GestureDetector(
              onTap: () {
                setState(() {
                  if (isFav) {
                    _favorites.remove(itemName);
                  } else {
                    _favorites.add(itemName);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  isFav
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFav ? Colors.redAccent : Colors.white24,
                  size: 20,
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
                    colors: [CafeTheme.primaryGold, CafeTheme.warmBrown],
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
  }

  // كارد الشبكة (Grid)
  Widget _buildGridCard(Map<String, dynamic> item) {
    String? imgUrl = item['image_url'];
    bool hasImage = imgUrl != null && imgUrl.isNotEmpty;
    bool hasSizes = item['sizes'] != null && (item['sizes'] as List).isNotEmpty;
    String itemName = item['name'] ?? '';
    bool isFav = _favorites.contains(itemName);
    int qtyInBasket = basket
        .where((e) => (e['name'] as String).startsWith(itemName))
        .fold(0, (s, e) => s + (e['quantity'] as int));

    return GestureDetector(
      onTap: () => _showAddDialog(item),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [Color(0xFF2A1608), Color(0xFF160D03)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: qtyInBasket > 0
                ? CafeTheme.primaryGold
                : CafeTheme.primaryGold.withValues(alpha: 0.3),
            width: qtyInBasket > 0 ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: CafeTheme.primaryGold.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 6,
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(22)),
                    child: hasImage
                        ? FastNetworkImage(
                            url: imgUrl!,
                            fit: BoxFit.cover,
                            cacheWidth: 300,
                            cacheHeight: 300,
                            placeholder: (c) =>
                                _bestSellerPlaceholder(itemName),
                          )
                        : _bestSellerPlaceholder(itemName),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itemName,
                          style: const TextStyle(
                            color: CafeTheme.primaryGoldLight,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              hasSizes
                                  ? "✦ أحجام"
                                  : "${item['price'] ?? '—'} ج",
                              style: const TextStyle(
                                color: CafeTheme.primaryGold,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    CafeTheme.primaryGold,
                                    CafeTheme.warmBrown
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(Icons.add_rounded,
                                  color: Colors.black, size: 18),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // ✦ ميزة 2: زرار المفضلة
            Positioned(
              top: 8,
              left: 8,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (isFav) {
                      _favorites.remove(itemName);
                    } else {
                      _favorites.add(itemName);
                    }
                  });
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFav
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFav ? Colors.redAccent : Colors.white54,
                    size: 16,
                  ),
                ),
              ),
            ),
            // ✦ ميزة 3: عداد الكميات
            if (qtyInBasket > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: CafeTheme.primaryGold,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "$qtyInBasket",
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddDialog(Map<String, dynamic> item) {
    _noteController.clear();

    // ✅ إصلاح: null safety للسعر
    List<dynamic>? sizes = item['sizes'];
    Map<String, dynamic>? selectedSize;
    double currentPrice = 0.0;

    try {
      if (sizes != null && sizes.isNotEmpty) {
        selectedSize = sizes.first as Map<String, dynamic>;
        currentPrice = (selectedSize['price'] as num).toDouble();
      } else if (item['price'] != null) {
        currentPrice = (item['price'] as num).toDouble();
      }
    } catch (e) {
      currentPrice = 0.0;
      debugPrint("Price parse error: $e");
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1008),
              title: Text(
                "تخصيص ${item['name'] ?? ''}",
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
                                selectedSize = s as Map<String, dynamic>;
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

                      String itemName = item['name'] ?? '';
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
                      // ✦ ميزة جديدة 2: toast آخر صنف مضاف
                      _lastAddedItem = item['name'] ?? itemName;
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) setState(() => _lastAddedItem = null);
                      });
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
              border: const Border(
                top: BorderSide(color: CafeTheme.warmBrown, width: 1.5),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActiveOrdersTracker(),
                  // ✦ ميزة جديدة 5: مشاركة المنيو + تقييم سريع
                  _buildQuickShareRateBar(),
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

  // ✦ ميزة جديدة 5: شريط مشاركة وتقييم سريع
  Widget _buildQuickShareRateBar() {
    if (basket.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                try {
                  final url = Uri.base.toString();
                  js.context.callMethod('eval', [
                    'if(navigator.share){navigator.share({title:"storm",url:"$url"});}else{navigator.clipboard.writeText("$url");}'
                  ]);
                } catch (e) {
                  debugPrint("Share error: $e");
                }
                _showStatusSnackBar(
                    "تم نسخ رابط المنيو! 🔗", CafeTheme.warmBrown);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: CafeTheme.warmBrown.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.share_rounded,
                        color: CafeTheme.primaryGold, size: 16),
                    SizedBox(width: 6),
                    Text("شارك المنيو",
                        style: TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: _showQuickRatingDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: CafeTheme.warmBrown.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star_rounded,
                        color: CafeTheme.primaryGold, size: 16),
                    SizedBox(width: 6),
                    Text("قيّم تجربتك",
                        style: TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickRatingDialog() {
    int localRating = 0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(28),
              constraints: const BoxConstraints(maxWidth: 320),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E1008), Color(0xFF0D0804)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                    color: CafeTheme.primaryGold.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                      color: CafeTheme.primaryGold.withValues(alpha: 0.1),
                      blurRadius: 30)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildstormLogo(size: 50),
                  const SizedBox(height: 12),
                  const Text("كيف تجربتك معنا؟",
                      style: TextStyle(
                          color: CafeTheme.primaryGold,
                          fontSize: 18,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text("رأيك يهمنا جداً ✨",
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      return GestureDetector(
                        onTap: () => setSt(() => localRating = i + 1),
                        child: AnimatedScale(
                          scale: localRating >= i + 1 ? 1.25 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Icon(
                              localRating >= i + 1
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: localRating >= i + 1
                                  ? CafeTheme.primaryGold
                                  : Colors.white24,
                              size: 38,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  if (localRating > 0)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CafeTheme.primaryGold,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showStatusSnackBar(
                            localRating >= 4
                                ? "شكراً على تقييمك الرائع! 🌟"
                                : "شكراً، سنحاول التحسين دائماً 🙏",
                            localRating >= 4
                                ? CafeTheme.primaryGold
                                : Colors.orangeAccent,
                          );
                        },
                        child: const Text("إرسال التقييم",
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
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
            child: Text(
              _basketItemCount > 0
                  ? "تأكيد الطلب ($_basketItemCount) ⚡"
                  : "تأكيد الطلب ⚡",
              style: const TextStyle(
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

    // ✦ تحديث order_count لكل منتج في Firebase
    for (var item in basket) {
      try {
        // نجيب اسم المنتج الأصلي (بدون حجم)
        String rawName = (item['name'] as String).split(' (').first;
        final query = await FirebaseFirestore.instance
            .collection('products')
            .where('name', isEqualTo: rawName)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          await query.docs.first.reference.update({
            'order_count':
                FieldValue.increment(item['quantity'] as int),
          });
        }
      } catch (e) {
        debugPrint("order_count update error: $e");
      }
    }

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

    // ✦ ميزة 5: تقييم سريع بعد الطلب
    _showRatingDialog();
  }

  // ==========================================
  // ✦ ميزة 5: تقييم سريع بعد الطلب
  // ==========================================
  void _showRatingDialog() {
    int selectedRating = 0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setRatingState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A1008), Color(0xFF0D0904)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: CafeTheme.primaryGold.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "تم إرسال طلبك! 🎉",
                    style: TextStyle(
                      color: CafeTheme.primaryGold,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "كيف كانت تجربتك معنا؟",
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      return GestureDetector(
                        onTap: () {
                          setRatingState(() => selectedRating = i + 1);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            i < selectedRating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: i < selectedRating
                                ? CafeTheme.primaryGold
                                : Colors.white30,
                            size: 40,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  if (selectedRating > 0)
                    Text(
                      selectedRating == 5
                          ? "ممتاز! شكراً على ثقتك ✨"
                          : selectedRating >= 3
                              ? "شكراً! رأيك يفيدنا كثيراً"
                              : "آسفين على ذلك! سنتحسن 🙏",
                      style: TextStyle(
                        color: selectedRating >= 4
                            ? Colors.greenAccent
                            : selectedRating >= 3
                                ? CafeTheme.primaryGold
                                : Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "تخطي",
                            style: TextStyle(color: Colors.white38),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CafeTheme.primaryGold,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: selectedRating == 0
                              ? null
                              : () async {
                                  Navigator.pop(context);
                                  // حفظ التقييم في Firestore
                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('ratings')
                                        .add({
                                      'customer': registeredName,
                                      'table': currentTable,
                                      'rating': selectedRating,
                                      'timestamp': FieldValue.serverTimestamp(),
                                    });
                                  } catch (e) {
                                    debugPrint("Rating save error: $e");
                                  }
                                  if (mounted) {
                                    _showStatusSnackBar(
                                      "شكراً على تقييمك! ⭐",
                                      CafeTheme.primaryGold,
                                    );
                                  }
                                },
                          child: const Text(
                            "إرسال",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

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
              child:
                  const Text("إلغاء", style: TextStyle(color: Colors.white38)),
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
  // ✦ بانر ترحيبي ذكي
  // ==========================================
  Widget _buildWelcomeBanner() {
    if (registeredName == null)
      return const SliverToBoxAdapter(child: SizedBox());
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
              child: const Icon(Icons.waving_hand_rounded,
                  color: Colors.black, size: 22),
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
  // ✦ شريط توقيت المطبخ
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
        child: const Row(
          children: [
            Icon(Icons.local_fire_department_rounded,
                color: Colors.orangeAccent, size: 18),
            SizedBox(width: 10),
            Expanded(
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
  // ✦ اقتراح اليوم الذكي — من Firebase
  // ==========================================
  Widget _buildDailySpecial() {
    return SliverToBoxAdapter(
      child: StreamBuilder<QuerySnapshot>(
        // ✦ جيب أعلى ١٠ منتجات مرتبة بالأكثر طلباً
        stream: FirebaseFirestore.instance
            .collection('products')
            .orderBy('order_count', descending: true)
            .limit(10)
            .snapshots(),
        builder: (context, snapshot) {
          List<Map<String, dynamic>> topProducts = [];
          if (snapshot.hasData) {
            topProducts = snapshot.data!.docs
                .map((d) => d.data() as Map<String, dynamic>)
                .toList();
          }

          // ✦ المنطق الذكي: طقس + وقت + أكثر طلباً
          final suggestion = _buildSmartSuggestion(topProducts);
          final productData = suggestion['product'] as Map<String, dynamic>;
          final productName = suggestion['name'] as String;
          final reason = suggestion['reason'] as String;
          final badge = suggestion['badge'] as String;
          final timeLabel = suggestion['timeLabel'] as String;
          final weatherInfo = suggestion['weatherInfo'] as String;

          // ✦ إيموجي المنتج
          String productEmoji = _weatherEmoji;
          if (productName.contains("قهوة") || productName.contains("اسبريسو") ||
              productName.contains("كابتشينو") || productName.contains("موكا")) {
            productEmoji = "☕";
          } else if (productName.contains("لاتيه") || productName.contains("هوت")) {
            productEmoji = (_weatherTemp != null && _weatherTemp! < 20) ? "☕" : "🥛";
          } else if (productName.contains("شاي")) {
            productEmoji = "🍵";
          } else if (productName.contains("عصير") || productName.contains("ليمون") ||
              productName.contains("سموزي")) {
            productEmoji = "🍹";
          } else if (productName.contains("موهيتو")) {
            productEmoji = "🌿";
          } else if (productName.contains("كولد") || productName.contains("آيس") ||
              productName.contains("فرابتشينو") || productName.contains("مثلج")) {
            productEmoji = "🧊";
          } else if (productName.contains("شوكولاتة")) {
            productEmoji = "🍫";
          } else if (productName.contains("كيك") || productName.contains("حلى") ||
              productName.contains("ديزرت")) {
            productEmoji = "🍰";
          }

          return GestureDetector(
            onTap: productData.isNotEmpty
                ? () => _showAddDialog(productData)
                : null,
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
                  // ✦ إيموجي المنتج الكبير
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(productEmoji,
                          style: const TextStyle(fontSize: 36)),
                      if (weatherInfo.isNotEmpty)
                        Text(
                          weatherInfo,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 9,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✦ شارة السبب (طلب X مرة / اقتراح وقت)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: CafeTheme.primaryGold,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        // ✦ اسم المنتج
                        Text(
                          productName,
                          style: const TextStyle(
                            color: CafeTheme.primaryGoldLight,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        // ✦ السبب الذكي (طقس + وقت)
                        Text(
                          reason,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ✦ زرار الإضافة
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [CafeTheme.primaryGold, CafeTheme.warmBrown],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.black, size: 22),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // ✦ عداد السلة
  // ==========================================
  int get _basketItemCount =>
      basket.fold(0, (acc, item) => acc + (item['quantity'] as int));

  // ==========================================
  // ✦ تحية الوقت
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

  @override
  void dispose() {
    tableCtrl.dispose();
    nameCtrl.dispose();
    searchCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
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
    double currentPrice = 0.0;

    try {
      if (sizes != null && sizes.isNotEmpty) {
        selectedSize = sizes.first as Map<String, dynamic>;
        currentPrice = (selectedSize['price'] as num).toDouble();
      } else if (item['price'] != null) {
        currentPrice = (item['price'] as num).toDouble();
      }
    } catch (e) {
      currentPrice = 0.0;
      debugPrint("Waiter price parse error: $e");
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1008),
              title: Text(
                "إضافة ${item['name'] ?? ''}",
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
                                selectedSize = s as Map<String, dynamic>;
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

                      String itemName = item['name'] ?? '';
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
    if (!mounted) return;
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
            stream: selectedCategory != null
                ? FirebaseFirestore.instance
                    .collection('products')
                    .where('cat', isEqualTo: selectedCategory)
                    .snapshots()
                : FirebaseFirestore.instance.collection('products').snapshots(),
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
                                    errorBuilder: (c, e, s) => const Icon(
                                      Icons.fastfood,
                                      color: CafeTheme.primaryGold,
                                      size: 40,
                                    ),
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
                              prod['name'] ?? '',
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
                            hasSizes
                                ? "أحجام مختلفة"
                                : "${prod['price'] ?? '—'} ج.م",
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
