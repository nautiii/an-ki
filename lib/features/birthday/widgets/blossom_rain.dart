import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Pluie de pétales de lotus et de prunier (signature S4) : une seule fois,
/// [duration] au plus, à poser derrière le contenu. Décorative : ni toucher
/// ni lecteur d'écran. Rien quand les animations sont coupées.
class BlossomRain extends StatefulWidget {
  const BlossomRain({
    super.key,
    required this.colors,
    required this.play,
    this.onPlay,
  });

  /// Durée totale, dernier pétale compris (identité : ≤ 2,5 s).
  static const Duration duration = Duration(milliseconds: 2400);

  /// Teintes des pétales, prises tour à tour.
  final List<Color> colors;

  /// Faut-il faire tomber les pétales ? Lu une fois, au montage : une pluie
  /// lancée va jusqu'au bout, même si l'appelant change d'avis.
  final bool play;

  /// Appelé une fois la pluie lancée (après la première image) ; jamais
  /// quand elle ne tombe pas.
  final VoidCallback? onPlay;

  @override
  State<BlossomRain> createState() => _BlossomRainState();
}

class _BlossomRainState extends State<BlossomRain>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: BlossomRain.duration,
  );

  // Même tirage à chaque fois : la pluie est la même pour tout le monde.
  final List<_Petal> _petals = _Petal.scatter(math.Random(7), count: 16);

  bool _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;
    if (!widget.play || MediaQuery.disableAnimationsOf(context)) return;
    unawaited(_controller.forward());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onPlay?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _PetalsPainter(_controller, _petals, widget.colors),
          ),
        ),
      ),
    );
  }
}

/// Un pétale : où il part, quand, combien de temps il tombe et comment il
/// tournoie. Fractions de la largeur et de la durée totale.
class _Petal {
  const _Petal({
    required this.x,
    required this.delay,
    required this.fall,
    required this.size,
    required this.sway,
    required this.spin,
    required this.phase,
    required this.lotus,
  });

  /// [count] pétales tirés de [random], tous tombés avant la fin.
  static List<_Petal> scatter(math.Random random, {required int count}) => [
    for (var i = 0; i < count; i++)
      _Petal(
        x: random.nextDouble(),
        delay: random.nextDouble() * 0.3,
        fall: 0.55 + random.nextDouble() * 0.15,
        size: 7 + random.nextDouble() * 8,
        sway: 6 + random.nextDouble() * 12,
        spin: (random.nextDouble() - 0.5) * 3,
        phase: random.nextDouble() * 2 * math.pi,
        // Moitié lotus pointus, moitié fleurs de prunier rondes.
        lotus: i.isEven,
      ),
  ];

  final double x;
  final double delay;
  final double fall;
  final double size;
  final double sway;
  final double spin;
  final double phase;
  final bool lotus;
}

class _PetalsPainter extends CustomPainter {
  _PetalsPainter(this.animation, this.petals, this.colors)
    : super(repaint: animation);

  final Animation<double> animation;
  final List<_Petal> petals;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    // Avant le départ et une fois tombés : plus rien à dessiner.
    if (t == 0 || animation.isCompleted || colors.isEmpty) return;
    for (final (index, petal) in petals.indexed) {
      final progress = (t - petal.delay) / petal.fall;
      if (progress <= 0 || progress >= 1) continue;
      final fall = Curves.easeInSine.transform(progress);
      final y = -petal.size + fall * (size.height + 2 * petal.size);
      final x =
          petal.x * size.width +
          math.sin(petal.phase + progress * 2.4 * math.pi) * petal.sway;
      // Apparaît vite, s'efface sur le dernier quart de sa chute.
      final opacity =
          math.min(1.0, progress / 0.1) * math.min(1.0, (1 - progress) / 0.25);
      final color = colors[index % colors.length];
      final paint = Paint()..color = color.withValues(alpha: color.a * opacity);
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(petal.phase + progress * petal.spin * 2 * math.pi);
      if (petal.lotus) {
        canvas.drawPath(_lotus(petal.size), paint);
      } else {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: petal.size * 0.8,
            height: petal.size * 0.6,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  /// Pétale de lotus : pointe en haut, base arrondie.
  static Path _lotus(double length) => Path()
    ..moveTo(0, -length / 2)
    ..cubicTo(
      length * 0.5,
      -length * 0.2,
      length * 0.4,
      length / 2,
      0,
      length / 2,
    )
    ..cubicTo(
      -length * 0.4,
      length / 2,
      -length * 0.5,
      -length * 0.2,
      0,
      -length / 2,
    )
    ..close();

  @override
  bool shouldRepaint(covariant _PetalsPainter oldDelegate) =>
      oldDelegate.petals != petals || oldDelegate.colors != colors;
}
