import 'dart:math' as math;
import 'package:aqua_steward/core/theme/app_color.dart';
import 'package:flutter/material.dart';

// Widget que dibuja y anima la silueta de un depósito de agua con animación de olas senoidales y porcentaje en tiempo real.
class DepositLevel extends StatefulWidget {
  final double level; // Porcentaje de llenado (0.0 - 100.0 %)

  const DepositLevel({super.key, required this.level});

  @override
  State<DepositLevel> createState() => _DepositLevelState();
}

class _DepositLevelState extends State<DepositLevel>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    // Controlador de animación continua para el movimiento de las olas
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Transición suave entre lecturas de nivel entrantes
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: widget.level.clamp(0.0, 100.0)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOutCubic,
      builder: (context, animatedLevel, _) {
        return AnimatedBuilder(
          animation: _waveController,
          builder: (context, _) {
            return Center(
              child: AspectRatio(
                aspectRatio: 1.1, // Proporción fija tipo tinaco/rotoplas
                child: CustomPaint(
                  painter: _TankWaterPainter(
                    levelPercent: animatedLevel,
                    waveProgress: _waveController.value,
                    waterColor: AppColor.parameterAqua,
                    borderColor: colorScheme.outline.withOpacity(0.5),
                    tankBgColor: colorScheme.surfaceContainerHighest,
                  ),
                  child: Center(
                    // Etiqueta central que muestra el porcentaje numérico
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColor.parameterAqua.withOpacity(0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        "${animatedLevel.toStringAsFixed(0)}%",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
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
}

/// CustomPainter encargado de renderizar la silueta del tinaco y el agua en movimiento
class _TankWaterPainter extends CustomPainter {
  final double levelPercent;
  final double waveProgress;
  final Color waterColor;
  final Color borderColor;
  final Color tankBgColor;

  _TankWaterPainter({
    required this.levelPercent,
    required this.waveProgress,
    required this.waterColor,
    required this.borderColor,
    required this.tankBgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _getTankPath(size);

    // 1. Fondo interior del tanque
    canvas.drawPath(
      path,
      Paint()
        ..color = tankBgColor.withOpacity(0.6)
        ..style = PaintingStyle.fill,
    );

    // Renderizado del agua animada (recortada a la silueta del depósito)
    canvas.save();
    canvas.clipPath(path);

    if (levelPercent > 0.5) {
      final double fillRatio = (levelPercent / 100.0).clamp(0.0, 1.0);
      final double baseHeight = size.height * 0.98;
      final double topWaterHeight = size.height * 0.08;
      final double targetWaterY =
          baseHeight - (fillRatio * (baseHeight - topWaterHeight));
      final double waveHeight = (fillRatio > 0.03 && fillRatio < 0.97)
          ? 4.5
          : 1.5;

      // Ola Trasera (movimiento desfasado con menor opacidad)
      final backWave = _buildWavePath(
        size: size,
        targetY: targetWaterY,
        waveHeight: waveHeight * 0.7,
        phase: (waveProgress * 2 * math.pi) + math.pi,
      );
      canvas.drawPath(
        backWave,
        Paint()
          ..color = waterColor.withOpacity(0.35)
          ..style = PaintingStyle.fill,
      );

      // Ola Frontal Principal con degradado vertical
      final frontWave = _buildWavePath(
        size: size,
        targetY: targetWaterY,
        waveHeight: waveHeight,
        phase: -(waveProgress * 2 * math.pi),
      );
      final frontPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            waterColor.withOpacity(0.95),
            waterColor.withOpacity(0.75),
            waterColor.withOpacity(0.55),
          ],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ).createShader(Rect.fromLTWH(0, targetWaterY, size.width, size.height))
        ..style = PaintingStyle.fill;
      canvas.drawPath(frontWave, frontPaint);

      // Brillo superior en la cresta de la ola
      canvas.drawPath(
        frontWave,
        Paint()
          ..color = Colors.white.withOpacity(0.3)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke,
      );
    }

    canvas.restore();

    // Contorno exterior del tinaco
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
  }

  /// Genera un trazado senoidal cerrado para simular la superficie del agua
  Path _buildWavePath({
    required Size size,
    required double targetY,
    required double waveHeight,
    required double phase,
  }) {
    final wavePath = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, targetY);

    for (double x = 0; x <= size.width; x += 2) {
      final double normalizedX = x / size.width;
      final double y =
          targetY + math.sin((normalizedX * 2 * math.pi) + phase) * waveHeight;
      wavePath.lineTo(x, y);
    }

    wavePath
      ..lineTo(size.width, size.height)
      ..close();
    return wavePath;
  }

  /// Construye la silueta vectorial de un tinaco / depósito rotoplas
  Path _getTankPath(Size size) {
    final double w = size.width;
    final double h = size.height;

    // Dimensiones de la tapa superior
    final double capWidth = w * 0.36;
    final double capLeft = (w - capWidth) / 2;
    final double capRight = capLeft + capWidth;
    final double capHeight = h * 0.07;
    const double capRadius = 3.0;

    // Dimensiones del cuello y hombros
    final double neckBottomY = capHeight + (h * 0.03);
    final double neckLeft = w * 0.28;
    final double neckRight = w * 0.72;
    final double shoulderBottomY = h * 0.16;
    final double bodyLeft = w * 0.04;
    final double bodyRight = w * 0.96;
    final double cornerRadius = w * 0.08;

    return Path()
      // Tapa superior redondeada
      ..moveTo(capLeft + capRadius, 2)
      ..lineTo(capRight - capRadius, 2)
      ..quadraticBezierTo(capRight, 2, capRight, 2 + capRadius)
      ..lineTo(capRight, capHeight)
      // Cuello derecho
      ..lineTo(neckRight, capHeight)
      ..lineTo(neckRight, neckBottomY)
      // Hombro curvado derecho
      ..cubicTo(
        neckRight,
        neckBottomY + (shoulderBottomY - neckBottomY) * 0.5,
        bodyRight,
        shoulderBottomY - (shoulderBottomY - neckBottomY) * 0.4,
        bodyRight,
        shoulderBottomY,
      )
      // Cuerpo y base derecha
      ..lineTo(bodyRight, h - cornerRadius)
      ..quadraticBezierTo(bodyRight, h - 2, bodyRight - cornerRadius, h - 2)
      // Base inferior
      ..lineTo(bodyLeft + cornerRadius, h - 2)
      // Base izquierda y cuerpo
      ..quadraticBezierTo(bodyLeft, h - 2, bodyLeft, h - cornerRadius)
      ..lineTo(bodyLeft, shoulderBottomY)
      // Hombro curvado izquierdo
      ..cubicTo(
        bodyLeft,
        shoulderBottomY - (shoulderBottomY - neckBottomY) * 0.4,
        neckLeft,
        neckBottomY + (shoulderBottomY - neckBottomY) * 0.5,
        neckLeft,
        neckBottomY,
      )
      // Cuello y cierre con tapa
      ..lineTo(neckLeft, capHeight)
      ..lineTo(capLeft, capHeight)
      ..lineTo(capLeft, 2 + capRadius)
      ..quadraticBezierTo(capLeft, 2, capLeft + capRadius, 2)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _TankWaterPainter oldDelegate) {
    return oldDelegate.levelPercent != levelPercent ||
        oldDelegate.waveProgress != waveProgress ||
        oldDelegate.waterColor != waterColor ||
        oldDelegate.borderColor != borderColor;
  }
}
