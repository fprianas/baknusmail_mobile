import 'dart:math';
import 'package:flutter/material.dart';

class HeartParticle {
  final String id;
  final Offset startOffset;
  final double size;
  final Color color;
  final double angle;
  final double swayDistance;
  final double swayFrequency;
  final double verticalDistance;
  final String? userName;
  final AnimationController controller;

  HeartParticle({
    required this.id,
    required this.startOffset,
    required this.size,
    required this.color,
    required this.angle,
    required this.swayDistance,
    required this.swayFrequency,
    required this.verticalDistance,
    this.userName,
    required this.controller,
  });
}

class FloatingHeartsOverlay extends StatefulWidget {
  final Widget child;

  const FloatingHeartsOverlay({
    super.key,
    required this.child,
  });

  @override
  State<FloatingHeartsOverlay> createState() => FloatingHeartsOverlayState();
}

class FloatingHeartsOverlayState extends State<FloatingHeartsOverlay> with TickerProviderStateMixin {
  final List<HeartParticle> _particles = [];
  final Random _random = Random();

  static const List<Color> _heartColors = [
    Color(0xFFE11D48), // Rose red
    Color(0xFFF43F5E), // Pink rose
    Color(0xFFEC4899), // Hot pink
    Color(0xFFFF2D55), // Bright red pink
    Color(0xFFF472B6), // Light pink
  ];

  /// Trigger satu atau beberapa partikel animasi love dari posisi tertentu (bisa menyertakan nama)
  void spawnHeart([Offset? position, int count = 2, String? userName]) {
    if (!mounted) return;
    final Size size = MediaQuery.of(context).size;
    final defaultPos = Offset(size.width - 60, size.height - 120);
    final spawnPos = position ?? defaultPos;

    for (int i = 0; i < count; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 1400 + _random.nextInt(600)),
      );

      final particle = HeartParticle(
        id: '${DateTime.now().microsecondsSinceEpoch}_$i',
        startOffset: spawnPos + Offset((_random.nextDouble() - 0.5) * 40, (_random.nextDouble() - 0.5) * 20),
        size: (userName != null ? 24.0 : 28.0) + _random.nextDouble() * 12.0,
        color: _heartColors[_random.nextInt(_heartColors.length)],
        angle: (_random.nextDouble() - 0.5) * 0.3,
        swayDistance: 20.0 + _random.nextDouble() * 35.0,
        swayFrequency: 1.5 + _random.nextDouble() * 2.0,
        verticalDistance: 190.0 + _random.nextDouble() * 110.0,
        userName: i == 0 ? userName : null, // Tampilkan badge nama pada partikel utama
        controller: controller,
      );

      controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (mounted) {
            setState(() {
              _particles.removeWhere((p) => p.id == particle.id);
            });
          }
          particle.controller.dispose();
        }
      });

      setState(() {
        _particles.add(particle);
      });

      controller.forward();
    }
  }

  /// Trigger animasi floating heart bertuliskan nama civitas yang menyukai status (staggered animation)
  void spawnHeartsForUsers(List<String> names, [Offset? position]) {
    if (!mounted || names.isEmpty) return;
    final Size screenSize = MediaQuery.of(context).size;

    for (int i = 0; i < names.length; i++) {
      final String name = names[i];
      final double delayMs = (i * 220).toDouble();

      Future.delayed(Duration(milliseconds: delayMs.toInt()), () {
        if (!mounted) return;
        final double randomX = (screenSize.width * 0.2) + (_random.nextDouble() * (screenSize.width * 0.6));
        final double spawnY = screenSize.height - 130 - (_random.nextDouble() * 40);
        final spawnPos = position ?? Offset(randomX, spawnY);

        final controller = AnimationController(
          vsync: this,
          duration: Duration(milliseconds: 1500 + _random.nextInt(600)),
        );

        final particle = HeartParticle(
          id: '${DateTime.now().microsecondsSinceEpoch}_user_$i',
          startOffset: spawnPos,
          size: 26.0 + _random.nextDouble() * 10.0,
          color: _heartColors[_random.nextInt(_heartColors.length)],
          angle: (_random.nextDouble() - 0.5) * 0.25,
          swayDistance: 15.0 + _random.nextDouble() * 30.0,
          swayFrequency: 1.2 + _random.nextDouble() * 1.8,
          verticalDistance: 200.0 + _random.nextDouble() * 100.0,
          userName: name,
          controller: controller,
        );

        controller.addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            if (mounted) {
              setState(() {
                _particles.removeWhere((p) => p.id == particle.id);
              });
            }
            particle.controller.dispose();
          }
        });

        setState(() {
          _particles.add(particle);
        });

        controller.forward();
      });
    }
  }

  @override
  void dispose() {
    for (var p in _particles) {
      p.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ..._particles.map((particle) => AnimatedBuilder(
              animation: particle.controller,
              builder: (context, child) {
                final progress = particle.controller.value;
                final dy = -progress * particle.verticalDistance;
                final dx = sin(progress * particle.swayFrequency * pi) * particle.swayDistance;

                // Scale elasticity
                double scale = 1.0;
                if (progress < 0.2) {
                  scale = (progress / 0.2) * 1.3;
                } else if (progress < 0.4) {
                  scale = 1.3 - ((progress - 0.2) / 0.2 * 0.3);
                }

                // Opacity fadeout in last 40%
                double opacity = 1.0;
                if (progress > 0.6) {
                  opacity = 1.0 - ((progress - 0.6) / 0.4);
                }

                return Positioned(
                  left: particle.startOffset.dx + dx - (particle.userName != null ? 50 : (particle.size / 2)),
                  top: particle.startOffset.dy + dy - (particle.size / 2),
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: Transform.rotate(
                        angle: particle.angle + (sin(progress * pi) * 0.1),
                        child: Transform.scale(
                          scale: scale.clamp(0.0, 2.0),
                          child: particle.userName != null && particle.userName!.isNotEmpty
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.75),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: particle.color.withValues(alpha: 0.85),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: particle.color.withValues(alpha: 0.45),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.favorite_rounded,
                                        size: particle.size * 0.65,
                                        color: particle.color,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        particle.userName!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          shadows: [
                                            Shadow(blurRadius: 4, color: Colors.black),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Icon(
                                  Icons.favorite_rounded,
                                  size: particle.size,
                                  color: particle.color,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 10,
                                      color: particle.color.withValues(alpha: 0.7),
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            )),
      ],
    );
  }
}
