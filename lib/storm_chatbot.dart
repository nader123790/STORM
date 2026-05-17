// =====================================================
// storm_chatbot.dart  v3.0
// ✦ AI Chatbot — Persistent Bottom Bar
//   يشتغل مع Google Gemini API (مجاني 100%)
//   الشريط ثابت في أسفل الشاشة ويتمدد لفوق
// =====================================================
// ignore_for_file: avoid_web_libraries_in_flutter, unused_local_variable

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import 'dart:convert';
import 'dart:js' as js;

// =====================================================
// ✦ ضع الـ API Key بتاعك هنا
//   احصل عليه مجاناً من: https://aistudio.google.com
// =====================================================
const String _geminiApiKey = 'AIzaSyD7TcJK73kmWD0SpSuFGmoxubfCHDZuXbA';

// ── ثيم الكافيه ──────────────────────────────────────
class _T {
  static const Color gold = Color(0xFFC8A96E);
  static const Color brown = Color(0xFF7B4A1E);
  static const Color darkBg = Color(0xFF0A0600);
  static const Color surface = Color(0xFF1A1008);
  static const Color surfaceLight = Color(0xFF2A1A0A);
}

// =====================================================
// ✦ نماذج البيانات
// =====================================================
class _Msg {
  final String text;
  final bool isBot;
  final List<_QR>? qr;
  final List<Map<String, dynamic>>? products;
  _Msg({required this.text, required this.isBot, this.qr, this.products});
}

class _QR {
  final String label, value;
  const _QR(this.label, this.value);
}

// =====================================================
// ✦ StormChatbot — الـ Widget الرئيسي
//   يُستخدم كـ Positioned في أسفل Stack داخل _buildMainContent
// =====================================================
class StormChatbot extends StatefulWidget {
  final List<Map<String, dynamic>> topProducts;
  final String? customerName;
  final void Function(Map<String, dynamic> product)? onAddToBasket;

  const StormChatbot({
    super.key,
    required this.topProducts,
    this.customerName,
    this.onAddToBasket,
  });

  @override
  State<StormChatbot> createState() => _StormChatbotState();
}

class _StormChatbotState extends State<StormChatbot>
    with SingleTickerProviderStateMixin {
  static const double _barH = 56;
  static const double _openFrac = 0.62;

  bool _isOpen = false;
  bool _loading = false;
  bool _pulse = false;

  late AnimationController _animCtrl;
  late Animation<double> _heightAnim;
  late Animation<double> _fadeAnim;

  final List<_Msg> _msgs = [];
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _inputCtrl = TextEditingController();
  List<Map<String, dynamic>> _allMenu = [];

  // ── سجل المحادثة بفورمات Gemini (contents)
  final List<Map<String, dynamic>> _geminiHistory = [];

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _heightAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);

    _loadMenu();
    _greet();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _pulse = true);
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  // ── تحميل المنيو من Firebase ─────────────────────────
  Future<void> _loadMenu() async {
    try {
      final snap =
          await FirebaseFirestore.instance.collection('products').get();
      _allMenu = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      debugPrint('Chatbot menu load: $e');
    }
  }

  // ── رسالة الترحيب الأولى ─────────────────────────────
  void _greet() {
    final name = widget.customerName;
    final text = name != null
        ? 'أهلاً يا $name! 👋\nأنا مساعدك الذكي في storm ✨\nمش عارف تختار؟ أنا هساعدك!'
        : 'أهلاً بيك في storm! ✨\nأنا مساعدك الذكي — هساعدك تختار من المنيو حسب مزاجك 😊';

    _msgs.add(_Msg(
      text: text,
      isBot: true,
      qr: const [
        _QR('☕ حاجة ساخنة', 'عايز حاجة ساخنة'),
        _QR('🧊 حاجة باردة', 'عايز حاجة باردة'),
        _QR('🍰 حلويات', 'عايز حاجة حلوة أو ديزرت'),
        _QR('🔥 الأكثر طلباً', 'إيه الأكثر طلباً عندكم؟'),
      ],
    ));
  }

  // ── فتح / إغلاق الشات ───────────────────────────────
  void _toggle() {
    setState(() => _isOpen = !_isOpen);
    if (_isOpen) {
      _animCtrl.forward();
      _pulse = false;
      _scrollToBottom();
    } else {
      _animCtrl.reverse();
      _inputCtrl.clear();
    }
  }

  // ── إرسال رسالة ─────────────────────────────────────
  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _msgs.add(_Msg(text: text, isBot: false));
      _loading = true;
    });
    _inputCtrl.clear();
    _scrollToBottom();
    try {
      final reply = await _callGemini(text);
      setState(() {
        _msgs.add(reply);
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _msgs
            .add(_Msg(text: 'عذراً، في مشكلة مؤقتة 😔 جرب تاني.', isBot: true));
        _loading = false;
      });
    }
    _scrollToBottom();
  }

  // ── بناء context المنيو ──────────────────────────────
  String _menuCtx() {
    final top = widget.topProducts
        .take(10)
        .map(
          (p) =>
              '- ${p['name']} (${p['price']} ج.م) — طُلب ${p['order_count'] ?? 0} مرة',
        )
        .join('\n');
    final all = _allMenu
        .take(40)
        .map(
          (p) => '- ${p['name']} | ${p['price']} ج.م | ${p['category'] ?? ''}',
        )
        .join('\n');
    return '=== الأكثر طلباً ===\n$top\n\n=== المنيو ===\n$all';
  }

  // ── System Prompt ────────────────────────────────────
  String _systemPrompt() => '''
أنت مساعد ذكي لكافيه "storm" الفاخر. مهمتك مساعدة العملاء على اختيار المشروب أو الأكل المناسب.

قواعد مهمة:
- تكلم بالعربية العامية المصرية الودية والقصيرة
- اسأل سؤال واحد بس في كل رد (مش أكتر)
- لما تقترح منتج، اكتبه هكذا في آخر ردك:
  [SUGGEST: اسم المنتج | السعر]
- ممكن تقترح اتنين أو تلاتة بأسطر منفصلة
- خليك مرح وودّي ✨

${_menuCtx()}
''';

  // ── استدعاء Gemini API (مجاني) ──────────────────────
  Future<_Msg> _callGemini(String userMsg) async {
    // أضف رسالة المستخدم لسجل المحادثة
    _geminiHistory.add({
      'role': 'user',
      'parts': [
        {'text': userMsg}
      ],
    });

    // بناء الـ request body بفورمات Gemini
    final bodyMap = {
      'system_instruction': {
        'parts': [
          {'text': _systemPrompt()}
        ]
      },
      'contents': _geminiHistory,
      'generationConfig': {
        'maxOutputTokens': 400,
        'temperature': 0.7,
      },
    };

    final bodyJson = jsonEncode(bodyMap);
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_geminiApiKey';

    // reset قبل الطلب
    js.context.callMethod(
        'eval', ['window._schatDone = false; window._schatResp = "";']);

    js.context.callMethod('eval', [
      '''
      (async function() {
        try {
          const r = await fetch("$url", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: ${jsonEncode(bodyJson)}
          });
          const d = await r.json();
          let text = "";
          if (d.candidates && d.candidates[0] &&
              d.candidates[0].content && d.candidates[0].content.parts) {
            text = d.candidates[0].content.parts[0].text || "";
          }
          window._schatResp = text;
          window._schatDone = true;
        } catch(e) {
          window._schatResp = "error:" + e.toString();
          window._schatDone = true;
        }
      })();
    '''
    ]);

    // polling بسيط حد ما يجي الرد
    String? raw;
    for (int i = 0; i < 80; i++) {
      await Future.delayed(const Duration(milliseconds: 250));
      try {
        if (js.context['_schatDone'] == true) {
          raw = js.context['_schatResp']?.toString();
          js.context.callMethod(
              'eval', ['window._schatDone = false; window._schatResp = "";']);
          break;
        }
      } catch (_) {}
    }

    if (raw == null || raw.isEmpty || raw.startsWith('error:')) {
      // لو في error، نشيل آخر رسالة user من التاريخ
      if (_geminiHistory.isNotEmpty) _geminiHistory.removeLast();
      throw Exception('Gemini error: $raw');
    }

    // أضف رد البوت لسجل المحادثة
    _geminiHistory.add({
      'role': 'model',
      'parts': [
        {'text': raw}
      ],
    });

    // ── parse [SUGGEST: name | price] ──────────────────
    final pat = RegExp(r'\[SUGGEST:\s*(.+?)\s*\|\s*(.+?)\]');
    final found = <Map<String, dynamic>>[];
    for (final m in pat.allMatches(raw)) {
      final name = m.group(1)?.trim() ?? '';
      Map<String, dynamic>? item;
      try {
        item = _allMenu.firstWhere(
          (p) =>
              (p['name'] ?? '').toString().contains(name) ||
              name.contains((p['name'] ?? '').toString()),
        );
      } catch (_) {}
      found.add({'name': name, 'price': m.group(2)?.trim(), ...(item ?? {})});
    }

    final clean =
        raw.replaceAll(pat, '').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

    return _Msg(
      text: clean,
      isBot: true,
      products: found.isEmpty ? null : found,
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 160), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // =====================================================
  // BUILD
  // =====================================================
  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final openH = screenH * _openFrac;

    return AnimatedBuilder(
      animation: _heightAnim,
      builder: (context, _) {
        final currentH = _barH + (_heightAnim.value * (openH - _barH));
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: currentH,
              decoration: BoxDecoration(
                color: _T.surface.withValues(alpha: 0.97),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(26)),
                border: Border(
                  top: BorderSide(
                      color: _T.gold.withValues(alpha: 0.35), width: 1.2),
                  left: BorderSide(
                      color: _T.gold.withValues(alpha: 0.15), width: 0.8),
                  right: BorderSide(
                      color: _T.gold.withValues(alpha: 0.15), width: 0.8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _T.gold.withValues(alpha: 0.12),
                    blurRadius: 24,
                    spreadRadius: 2,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildBar(),
                  if (_isOpen)
                    Expanded(
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: Column(
                          children: [
                            Expanded(child: _buildMsgList()),
                            if (_loading) _buildTyping(),
                            _buildInput(),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── الشريط العلوي (الزرار الثابت) ───────────────────
  Widget _buildBar() {
    return GestureDetector(
      onTap: _toggle,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: _barH,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _T.gold.withValues(alpha: 0.12),
              _T.brown.withValues(alpha: 0.06),
            ],
          ),
          border: _isOpen
              ? Border(
                  bottom: BorderSide(color: _T.gold.withValues(alpha: 0.18)))
              : null,
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [_T.gold, _T.brown],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _T.gold.withValues(alpha: 0.45),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isOpen
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.auto_awesome_rounded,
                    color: Colors.black,
                    size: 18,
                  ),
                ),
                if (_pulse && !_isOpen)
                  Positioned(top: -2, right: -2, child: _PulseDot()),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'مساعد storm الذكي ✨',
                    style: TextStyle(
                      color: _T.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    _isOpen ? 'اضغط للإغلاق' : 'مش عارف تختار؟ اسألني!',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.38),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            if (!_isOpen && _msgs.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _T.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _T.gold.withValues(alpha: 0.35)),
                ),
                child: Text(
                  '${_msgs.length - 1} رسالة',
                  style: const TextStyle(
                      color: _T.gold,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            if (_isOpen)
              Icon(Icons.expand_more_rounded,
                  color: _T.gold.withValues(alpha: 0.6), size: 20),
          ],
        ),
      ),
    );
  }

  // ── قائمة الرسائل ────────────────────────────────────
  Widget _buildMsgList() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        itemCount: _msgs.length,
        itemBuilder: (_, i) => _buildBubble(_msgs[i]),
      ),
    );
  }

  Widget _buildBubble(_Msg msg) {
    return Column(
      crossAxisAlignment:
          msg.isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            gradient: msg.isBot
                ? LinearGradient(colors: [_T.surfaceLight, _T.surface])
                : const LinearGradient(
                    colors: [_T.gold, _T.brown],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.only(
              topRight: const Radius.circular(18),
              topLeft: const Radius.circular(18),
              bottomRight: msg.isBot ? const Radius.circular(18) : Radius.zero,
              bottomLeft: msg.isBot ? Radius.zero : const Radius.circular(18),
            ),
            border: msg.isBot
                ? Border.all(color: _T.gold.withValues(alpha: 0.14))
                : null,
          ),
          child: Text(
            msg.text,
            style: TextStyle(
              color: msg.isBot ? Colors.white : Colors.black,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),

        // أزرار سريعة
        if (msg.qr != null && msg.qr!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: msg.qr!
                  .map((q) => GestureDetector(
                        onTap: () => _send(q.value),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(
                            color: _T.gold.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: _T.gold.withValues(alpha: 0.38)),
                          ),
                          child: Text(q.label,
                              style: const TextStyle(
                                  color: _T.gold,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ))
                  .toList(),
            ),
          ),

        // المنتجات المقترحة
        if (msg.products != null && msg.products!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child:
                Column(children: msg.products!.map(_buildProductCard).toList()),
          ),
      ],
    );
  }

  // ── كارد المنتج المقترح ──────────────────────────────
  Widget _buildProductCard(Map<String, dynamic> p) {
    final imgUrl = (p['image_url'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          _T.gold.withValues(alpha: 0.1),
          _T.brown.withValues(alpha: 0.05),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _T.gold.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: imgUrl.isNotEmpty
                ? Image.network(imgUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imgPh())
                : _imgPh(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['name'] ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5)),
                if (p['price'] != null)
                  Text('${p['price']} ج.م',
                      style: const TextStyle(color: _T.gold, fontSize: 11.5)),
              ],
            ),
          ),
          if (widget.onAddToBasket != null)
            GestureDetector(
              onTap: () => widget.onAddToBasket!(p),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_T.gold, _T.brown],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.black, size: 14),
                    SizedBox(width: 3),
                    Text('أضف',
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _imgPh() => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _T.gold.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.local_cafe_rounded, color: _T.gold, size: 22),
      );

  // ── مؤشر الكتابة ─────────────────────────────────────
  Widget _buildTyping() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: _T.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _T.gold.withValues(alpha: 0.14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [_Dot(delay: 0), _Dot(delay: 160), _Dot(delay: 320)],
          ),
        ),
      ),
    );
  }

  // ── شريط الإدخال ─────────────────────────────────────
  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _T.gold.withValues(alpha: 0.14))),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: _send,
                decoration: InputDecoration(
                  hintText: 'اكتب سؤالك...',
                  hintStyle:
                      const TextStyle(color: Colors.white30, fontSize: 12.5),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                        color: _T.gold.withValues(alpha: 0.2), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: _T.gold, width: 1),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _send(_inputCtrl.text),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_T.gold, _T.brown],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.black, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// ✦ Pulse Dot — نقطة إشعار حية
// =====================================================
class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.redAccent.withValues(alpha: 0.5 + _c.value * 0.5),
            border: Border.all(color: _T.darkBg, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withValues(alpha: _c.value * 0.6),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      );
}

// =====================================================
// ✦ Dot — نقطة مؤشر الكتابة
// =====================================================
class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat(reverse: true);
    _a = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _a,
        builder: (_, __) => Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _T.gold.withValues(alpha: 0.4 + _a.value * 0.6),
          ),
          transform: Matrix4.translationValues(0, -4 * _a.value, 0),
        ),
      );
}
