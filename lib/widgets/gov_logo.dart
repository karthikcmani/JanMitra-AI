import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GovLogo extends StatelessWidget {
  final double size;
  final bool showLabel;
  final Color? color;

  const GovLogo({
    super.key,
    this.size = 100,
    this.showLabel = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.heroGradient,
            boxShadow: [
              BoxShadow(
                color: (color ?? AppTheme.primaryBlue).withAlpha(50),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(size * 0.04),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: Center(
                child: Container(
                  width: size * 0.7,
                  height: size * 0.7,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.heroGradient,
                  ),
                  child: Icon(
                    Icons.account_balance_rounded,
                    size: size * 0.38,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_user_rounded,
                size: 16,
                color: AppTheme.secondaryTeal,
              ),
              const SizedBox(width: 6),
              Text(
                'GOVERNMENT OF INDIA INITIATIVE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppTheme.primaryBlue.withAlpha(200),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
