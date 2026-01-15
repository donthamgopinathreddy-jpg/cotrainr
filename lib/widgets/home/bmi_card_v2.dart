import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../theme/design_tokens.dart';
import '../common/glass_card.dart';
import '../common/pill_chip.dart';

class BmiCardV2 extends StatefulWidget {
  final double bmi;
  final String status;

  const BmiCardV2({
    super.key,
    required this.bmi,
    required this.status,
  });

  @override
  State<BmiCardV2> createState() => _BmiCardV2State();
}

class _BmiCardV2State extends State<BmiCardV2>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bmiPosition = _calculateBmiPosition(widget.bmi);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 200),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/home/body-metrics');
        },
        child: GlassCard(
          margin: EdgeInsets.symmetric(horizontal: DesignTokens.spacing16),
          padding: EdgeInsets.all(DesignTokens.spacing16),
          onTap: null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: BMI + Body Composition (meta) + info icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BMI',
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeH2,
                          fontWeight: FontWeight.w700,
                          color: DesignTokens.textPrimary,
                        ),
                      ),
                      SizedBox(height: DesignTokens.spacing4),
                      Text(
                        'Body Composition',
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeMeta,
                          color: DesignTokens.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.info_outline,
                    size: DesignTokens.iconSizeTile,
                    color: DesignTokens.textSecondary,
                  ),
                ],
              ),
              SizedBox(height: DesignTokens.spacing16),
              // Center: 22.4 (H1) Status pill (NORMAL green)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    widget.bmi.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: DesignTokens.fontSizeH1,
                      fontWeight: FontWeight.w700,
                      color: DesignTokens.textPrimary,
                    ),
                  ),
                  PillChip(
                    label: widget.status.toUpperCase(),
                    isActive: true,
                  ),
                ],
              ),
              SizedBox(height: DesignTokens.spacing24),
              // Secondary: Range bar Under Normal Over Obese
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 40,
                    child: Stack(
                      children: [
                        // Scale segments
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.6),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    bottomLeft: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 8,
                                color: DesignTokens.accentGreen.withValues(alpha: 0.6),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 8,
                                color: Colors.orange.withValues(alpha: 0.6),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.6),
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(4),
                                    bottomRight: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Marker: Glowing dot with shadow
                        AnimatedBuilder(
                          animation: _scaleAnimation,
                          builder: (context, child) {
                            return Positioned(
                              left: (MediaQuery.of(context).size.width - 64) *
                                  bmiPosition *
                                  _scaleAnimation.value,
                              top: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _getStatusColor(widget.status),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _getStatusColor(widget.status)
                                          .withValues(alpha: 0.6),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: DesignTokens.spacing8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Under', style: TextStyle(fontSize: 10)),
                      Text('Normal', style: TextStyle(fontSize: 10)),
                      Text('Over', style: TextStyle(fontSize: 10)),
                      Text('Obese', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              SizedBox(height: DesignTokens.spacing16),
              // CTA: Update Height Weight (small ghost button)
              TextButton(
                onPressed: () {
                  // TODO: Open height/weight update
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: DesignTokens.spacing16,
                    vertical: DesignTokens.spacing8,
                  ),
                ),
                child: Text(
                  'Update Height & Weight',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeMeta,
                    color: DesignTokens.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateBmiPosition(double bmi) {
    if (bmi < 18.5) {
      return (bmi / 18.5) * 0.25;
    } else if (bmi < 25) {
      return 0.25 + ((bmi - 18.5) / 6.5) * 0.25;
    } else if (bmi < 30) {
      return 0.5 + ((bmi - 25) / 5) * 0.25;
    } else {
      return 0.75 + ((bmi - 30) / 10).clamp(0.0, 0.25);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'underweight':
        return Colors.blue;
      case 'normal':
        return DesignTokens.accentGreen;
      case 'overweight':
        return Colors.orange;
      case 'obese':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}



