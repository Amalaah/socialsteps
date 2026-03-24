import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// SocialSteps – ASD-friendly design system
///
/// Palette rationale
///   • Deep indigo background – calm, non-stimulating
///   • Soft violet / sky-blue accents – distinguishable without harsh contrast
///   • Warm amber reward accents – positive reinforcement
///   • No pure red / no strobe-like flickers
/// ─────────────────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  // ── Background layers ──────────────────────────────────────────────────────
  static const Color bg         = Color(0xFF1A1A2E);  // deep navy
  static const Color surface    = Color(0xFF16213E);  // card surface
  static const Color surfaceAlt = Color(0xFF0F3460);  // highlighted card
  static const Color border     = Color(0xFF2E344E);  // subtle border color

  // ── Brand / primary ────────────────────────────────────────────────────────
  static const Color primary    = Color(0xFF7C5CBF);  // soft violet
  static const Color primaryLt  = Color(0xFFB39DDB);  // light violet
  static const Color secondary  = Color(0xFF48CAE4);  // sky blue

  // ── Accent (rewards / positive) ────────────────────────────────────────────
  static const Color amber      = Color(0xFFFFB703);  // warm amber
  static const Color mint       = Color(0xFF52D9B5);  // calming mint green
  static const Color coral      = Color(0xFFFF8B64);  // soft coral (not red)

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFF5F0FF);
  static const Color textSecondary = Color(0xFFB0A8C8);
  static const Color textHint      = Color(0xFF6D6585);

  // ── Activity card gradients ────────────────────────────────────────────────
  static const List<List<Color>> activityGradients = [
    [Color(0xFF7C5CBF), Color(0xFF48CAE4)],  // violet → sky  (Emotion)
    [Color(0xFF52D9B5), Color(0xFF48CAE4)],  // mint   → sky  (Focus)
    [Color(0xFFFF8B64), Color(0xFFFFB703)],  // coral  → amber (Puzzle)
    [Color(0xFF7C5CBF), Color(0xFFFF8B64)],  // violet → coral (Color)
    [Color(0xFF52D9B5), Color(0xFF7C5CBF)],  // mint   → violet (Social)
  ];

  // ── Border radius ──────────────────────────────────────────────────────────
  static const double radiusSm  = 12;
  static const double radiusMd  = 20;
  static const double radiusLg  = 28;

  // ── Typography ─────────────────────────────────────────────────────────────
  static const TextStyle heading = TextStyle(
    fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary, height: 1.2,
  );
  static const TextStyle subheading = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary,
  );
  static const TextStyle body = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w400, color: textSecondary,
  );
  static const TextStyle label = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w500, color: textHint,
    letterSpacing: 0.5,
  );

  // ── ThemeData ──────────────────────────────────────────────────────────────
  static ThemeData get theme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      primary:   primary,
      secondary: secondary,
      surface:   surface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor:  surface,
      foregroundColor:  textPrimary,
      elevation:        0,
      centerTitle:      true,
      titleTextStyle:   TextStyle(
        fontSize: 18, fontWeight: FontWeight.w700,
        color: textPrimary, letterSpacing: 0.3,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor:  primary,
        foregroundColor:  textPrimary,
        padding:          const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        textStyle:        const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape:            RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        elevation: 6,
        shadowColor: primary.withOpacity(0.4),
      ),
    ),
    cardTheme: CardThemeData(
      color:  surface,
      shape:  RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
      ),
      elevation: 6,
      shadowColor: Colors.black38,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surfaceAlt,
      contentTextStyle: const TextStyle(color: textPrimary, fontSize: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusSm),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
      ),
      titleTextStyle: subheading,
      contentTextStyle: body,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceAlt,
      hintStyle: const TextStyle(color: textHint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
  );
}

// ─── Reusable widgets ──────────────────────────────────────────────────────────

/// Gradient card used for activity tiles
class ActivityCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;
  final bool locked;

  const ActivityCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: locked ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: locked
                ? [Colors.grey.shade800, Colors.grey.shade700]
                : gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: locked
              ? []
              : [
                  BoxShadow(
                    color: gradient.last.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 36)),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                locked ? '🔒 Locked' : subtitle,
                style: TextStyle(
                  fontSize: 12, color: Colors.white.withOpacity(0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated page entry (fades + slides up)
class PageEntry extends StatefulWidget {
  final Widget child;
  const PageEntry({super.key, required this.child});

  @override
  State<PageEntry> createState() => _PageEntryState();
}

class _PageEntryState extends State<PageEntry>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fade  = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _c.forward();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _fade,
          child: SlideTransition(position: _slide, child: widget.child));
}

/// Stat row tile shown on progress / stars screens
class StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const StatTile({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: AppTheme.body),
          ),
          Text(value,
              style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              )),
        ],
      ),
    );
  }
}
