import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/gov_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _navigationTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      final authState = ref.read(authProvider);
      if (authState.isLoggedIn && authState.currentUser != null) {
        context.go('/dashboard');
      } else {
        context.go('/login');
      }
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.splashGradient),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 40),
              // Center Content
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GovLogo(size: 110, showLabel: true)
                      .animate()
                      .scale(duration: 800.ms, curve: Curves.easeOutBack)
                      .fadeIn(duration: 600.ms),
                  const SizedBox(height: 28),
                  Column(
                        children: [
                          const Text(
                            AppConstants.appName,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryBlue,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              AppConstants.appTagline,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryBlue.withAlpha(220),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      )
                      .animate()
                      .fadeIn(delay: 300.ms, duration: 600.ms)
                      .slideY(begin: 0.2, end: 0.0),
                ],
              ),
              // Bottom Version
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withAlpha(15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primaryBlue.withAlpha(40),
                    ),
                  ),
                  child: const Text(
                    AppConstants.appVersion,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ).animate().fadeIn(delay: 500.ms, duration: 500.ms),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
