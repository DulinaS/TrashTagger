// lib/models/onboarding_model.dart
import 'package:flutter/material.dart';

class OnboardingPage {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final LinearGradient gradient;
  final List<String> features;
  final String? imagePath;

  OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.features,
    this.imagePath,
  });
}

class OnboardingData {
  static List<OnboardingPage> getPages() {
    return [
      OnboardingPage(
        title: 'Report & Discover',
        subtitle: 'Spot trash in your area',
        description:
            'Easily report litter and discover cleanup opportunities in your neighborhood. Your reports help create a cleaner community for everyone.',
        icon: Icons.location_on_rounded,
        gradient: const LinearGradient(
          colors: [Color(0xFF00BFA5), Color(0xFF26A69A)],
        ),
        features: [
          '📍 GPS-based reporting',
          '📸 Photo documentation',
          '🗺️ Interactive map view',
          '📊 Real-time statistics',
        ],
      ),
      OnboardingPage(
        title: 'Earn & Compete',
        subtitle: 'Join the leaderboard',
        description:
            'Complete cleanup challenges, earn points, unlock badges, and climb the leaderboard. Make environmental action fun and rewarding!',
        icon: Icons.emoji_events_rounded,
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB74D), Color(0xFFFF8A65)],
        ),
        features: [
          '🏆 Weekly challenges',
          '⭐ Points & badges system',
          '📈 Progress tracking',
          '👥 Community rankings',
        ],
      ),
      OnboardingPage(
        title: 'Connect & Impact',
        subtitle: 'Build a cleaner future',
        description:
            'Connect with like-minded individuals, organize cleanup events, and see the real impact of your efforts on the environment.',
        icon: Icons.groups_rounded,
        gradient: const LinearGradient(
          colors: [Color(0xFF9C27B0), Color(0xFF26A69A)],
        ),
        features: [
          '🌱 Environmental impact',
          '🤝 Community events',
          '📱 Social sharing',
          '💚 Make a difference',
        ],
      ),
    ];
  }
}
