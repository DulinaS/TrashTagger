// lib/screens/profile/help_support_screen.dart - Modern Vibrant Design (Completed)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../themes/app_theme.dart';
import '../../services/support_service.dart';
import '../../widgets/modern/modern_widgets.dart';
import '../../animations/custom_animations.dart';
import '../../animations/animation_constants.dart';
import '../../utils/helpers.dart';

class HelpSupportScreen extends StatefulWidget {
  @override
  _HelpSupportScreenState createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Contact form controllers
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedCategory = 'general';
  String _selectedPriority = 'medium';
  bool _isSubmitting = false;

  // Support messages data
  List<Map<String, dynamic>> _supportMessages = [];
  bool _isLoadingMessages = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSupportMessages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadSupportMessages() async {
    setState(() => _isLoadingMessages = true);

    try {
      final messages = await SupportService.getUserSupportMessages();
      setState(() => _supportMessages = messages);
    } catch (e) {
      _showErrorSnackbar('Failed to load support messages: $e');
    } finally {
      setState(() => _isLoadingMessages = false);
    }
  }

  Future<void> _submitSupportMessage() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final messageId = await SupportService.submitSupportMessage(
        subject: _subjectController.text.trim(),
        message: _messageController.text.trim(),
        category: _selectedCategory,
        priority: _selectedPriority,
      );

      // Clear form
      _subjectController.clear();
      _messageController.clear();
      setState(() {
        _selectedCategory = 'general';
        _selectedPriority = 'medium';
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              const Text('Support message submitted successfully!'),
            ],
          ),
          backgroundColor: AppTheme.primaryEmerald,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      // Switch to messages tab and reload
      _tabController.animateTo(2);
      await _loadSupportMessages();
    } catch (e) {
      _showErrorSnackbar('Failed to submit message: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [_buildModernAppBar()];
        },
        body: TabBarView(
          controller: _tabController,
          children: [_buildFAQTab(), _buildContactTab(), _buildMessagesTab()],
        ),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.backgroundPrimary,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.infoBlue.withOpacity(0.1),
                AppTheme.primaryTeal.withOpacity(0.05),
              ],
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.infoBlue, AppTheme.primaryTeal],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Help & Support',
              style: AppTheme.titleLarge.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: AppTheme.infoBlue,
        labelColor: AppTheme.infoBlue,
        unselectedLabelColor: AppTheme.textSecondary,
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.help_outline_rounded, size: 18),
                const SizedBox(width: 8),
                Text('FAQ'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.email_outlined, size: 18),
                const SizedBox(width: 8),
                Text('Contact'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.message_outlined, size: 18),
                const SizedBox(width: 8),
                Text('Messages'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SlideInAnimation(
            delay: AnimationConstants.microDelay,
            child: _buildWelcomeCard(),
          ),
          const SizedBox(height: 24),

          SlideInAnimation(
            delay: AnimationConstants.shortDelay,
            child: _buildFAQSection('Getting Started', [
              {
                'question': 'How do I report trash?',
                'answer':
                    'Tap the camera icon in the bottom navigation, take a photo of the trash, and provide location details. Our AI will verify the report.',
              },
              {
                'question': 'How do I earn points?',
                'answer':
                    'You earn points by reporting trash (10-25 points) and completing cleanup challenges (20-50 points). Points vary based on trash severity.',
              },
              {
                'question': 'What are cleanup challenges?',
                'answer':
                    'When someone reports trash, it becomes a cleanup challenge. You can accept it, clean it up, and submit proof to earn points and badges.',
              },
            ], AppTheme.primaryGradient),
          ),

          const SizedBox(height: 16),
          SlideInAnimation(
            delay: AnimationConstants.mediumDelay,
            child: _buildFAQSection('Points & Badges', [
              {
                'question': 'How does the level system work?',
                'answer':
                    'Levels are based on total points: Level 2 (50pts), Level 3 (150pts), Level 4 (300pts), Level 5 (500pts), and so on.',
              },
              {
                'question': 'How do I earn badges?',
                'answer':
                    'Badges are earned automatically for milestones like first report, multiple cleanups, streaks, and special achievements.',
              },
              {
                'question': 'What is the leaderboard?',
                'answer':
                    'The leaderboard shows top contributors. There are all-time, monthly, and weekly rankings based on points earned.',
              },
            ], AppTheme.warningGradient),
          ),

          const SizedBox(height: 16),
          SlideInAnimation(
            delay: AnimationConstants.longDelay,
            child: _buildFAQSection('Safety & Verification', [
              {
                'question': 'Is it safe to clean up trash?',
                'answer':
                    'Always prioritize safety. Avoid hazardous materials, wear gloves, and report dangerous items to authorities instead of cleaning them yourself.',
              },
              {
                'question': 'How does verification work?',
                'answer':
                    'We use AI to verify cleanup photos by comparing before/after images, checking location proximity, and analyzing image authenticity.',
              },
              {
                'question': 'What if my cleanup is disputed?',
                'answer':
                    'Disputed cleanups are manually reviewed by our team. You can resubmit better proof or request a review.',
              },
            ], AppTheme.errorGradient),
          ),

          const SizedBox(height: 16),
          SlideInAnimation(
            delay: AnimationConstants.extraLongDelay,
            child: _buildFAQSection(
              'Technical Issues',
              [
                {
                  'question': 'The app is not working properly',
                  'answer':
                      'Try restarting the app, checking your internet connection, and updating to the latest version. Contact support if issues persist.',
                },
                {
                  'question': 'I\'m not receiving notifications',
                  'answer':
                      'Check your notification settings in the app and your device settings. Make sure TrashTagger has permission to send notifications.',
                },
                {
                  'question': 'My location is not accurate',
                  'answer':
                      'Ensure location services are enabled for TrashTagger in your device settings. Try moving to an area with better GPS reception.',
                },
              ],
              LinearGradient(
                colors: [AppTheme.accentPurple, AppTheme.accentCoral],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SlideInAnimation(
            delay: AnimationConstants.microDelay,
            child: ModernCard(
              padding: const EdgeInsets.all(24),
              backgroundColor: AppTheme.infoBlue.withOpacity(0.05),
              border: Border.all(color: AppTheme.infoBlue.withOpacity(0.3)),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.infoBlue, AppTheme.primaryTeal],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.support_agent_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Contact Support',
                              style: AppTheme.headlineMedium.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Need help? Send us a message and we\'ll get back to you as soon as possible.',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Form(
            key: _formKey,
            child: Column(
              children: [
                // Category Selection
                SlideInAnimation(
                  delay: AnimationConstants.shortDelay,
                  child: _buildCategorySelection(),
                ),
                const SizedBox(height: 16),

                // Priority Selection
                SlideInAnimation(
                  delay: AnimationConstants.mediumDelay,
                  child: _buildPrioritySelection(),
                ),
                const SizedBox(height: 16),

                // Subject Field
                SlideInAnimation(
                  delay: AnimationConstants.longDelay,
                  child: _buildSubjectField(),
                ),
                const SizedBox(height: 16),

                // Message Field
                SlideInAnimation(
                  delay: AnimationConstants.extraLongDelay,
                  child: _buildMessageField(),
                ),
                const SizedBox(height: 24),

                // Submit Button
                ScaleInAnimation(
                  delay: const Duration(milliseconds: 600),
                  child: ModernGradientButton(
                    text: 'Send Message',
                    onPressed: _isSubmitting ? null : _submitSupportMessage,
                    isLoading: _isSubmitting,
                    icon: _isSubmitting ? null : Icons.send_rounded,
                    gradient: AppTheme.primaryGradient,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesTab() {
    if (_isLoadingMessages) {
      return ModernLoadingWidget(message: 'Loading your messages...');
    }

    if (_supportMessages.isEmpty) {
      return ModernEmptyState(
        icon: Icons.message_outlined,
        title: 'No Support Messages',
        message: 'You haven\'t sent any support messages yet.',
        actionText: 'Send Message',
        onAction: () => _tabController.animateTo(1),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSupportMessages,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: _supportMessages.length,
        itemBuilder: (context, index) {
          return SlideInAnimation(
            delay: Duration(milliseconds: 100 + (index * 50)),
            child: _buildMessageCard(_supportMessages[index]),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return ModernCard(
      padding: const EdgeInsets.all(24),
      backgroundColor: AppTheme.primaryEmerald.withOpacity(0.05),
      border: Border.all(color: AppTheme.primaryEmerald.withOpacity(0.3)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.eco_rounded, size: 48, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text(
            'Welcome to TrashTagger Support',
            style: AppTheme.headlineMedium.copyWith(
              color: AppTheme.primaryEmerald,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Find answers to common questions or contact our support team for personalized help.',
            style: AppTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFAQSection(
    String title,
    List<Map<String, String>> faqs,
    LinearGradient gradient,
  ) {
    return ModernCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_getFAQIcon(title), color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...faqs.map((faq) => _buildFAQItem(faq['question']!, faq['answer']!)),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.w600),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelection() {
    return ModernCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.category_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Category',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SupportService.categories.entries.map((entry) {
              final isSelected = _selectedCategory == entry.key;
              return ModernChip(
                label: entry.value,
                selected: isSelected,
                onTap: () {
                  setState(() => _selectedCategory = entry.key);
                },
                selectedColor: AppTheme.primaryEmerald,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPrioritySelection() {
    return ModernCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.warningGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.priority_high_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Priority',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: SupportService.priorities.entries.map((entry) {
              final isSelected = _selectedPriority == entry.key;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: ModernChip(
                    label: entry.value,
                    selected: isSelected,
                    onTap: () {
                      setState(() => _selectedPriority = entry.key);
                    },
                    selectedColor: _getPriorityColor(entry.key),
                    width: double.infinity,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectField() {
    return ModernCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.infoBlue, AppTheme.primaryTeal],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.subject_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Subject',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ModernTextField(
            controller: _subjectController,
            hint: 'Brief description of your issue',
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Subject is required';
              }
              if (value.trim().length < 5) {
                return 'Subject must be at least 5 characters';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageField() {
    return ModernCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.accentPurple, AppTheme.accentCoral],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.message_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Message',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ModernTextField(
            controller: _messageController,
            hint: 'Please describe your issue in detail...',
            maxLines: 6,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Message is required';
              }
              if (value.trim().length < 10) {
                return 'Message must be at least 10 characters';
              }
              if (value.trim().length > 2000) {
                return 'Message must be less than 2000 characters';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {}); // Update character count
            },
          ),
          const SizedBox(height: 8),
          Text(
            '${_messageController.text.length}/2000 characters',
            style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> message) {
    final status = message['status'] ?? 'open';
    final hasResponse = message['adminResponse'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ModernCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    message['subject'] ?? 'No Subject',
                    style: AppTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ModernStatusBadge(
                  status: status,
                  customText: SupportService.getStatusDisplayName(status),
                  color: _getStatusColor(status),
                  showPulse: status == 'in_progress',
                ),
              ],
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundPrimary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.category_rounded,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        SupportService.getCategoryDisplayName(
                          message['category'] ?? 'general',
                        ),
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimestamp(message['createdAt']),
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message['message'] ?? '',
                    style: AppTheme.bodyMedium,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            if (hasResponse) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryEmerald.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.support_agent_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Support Response',
                          style: AppTheme.labelMedium.copyWith(
                            color: AppTheme.primaryEmerald,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message['adminResponse'] ?? '',
                      style: AppTheme.bodyMedium,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return AppTheme.infoBlue;
      case 'in_progress':
        return AppTheme.warningAmber;
      case 'resolved':
        return AppTheme.primaryEmerald;
      case 'closed':
        return AppTheme.textSecondary;
      default:
        return AppTheme.textSecondary;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'low':
        return AppTheme.successGreen;
      case 'medium':
        return AppTheme.warningAmber;
      case 'high':
        return AppTheme.errorRed;
      default:
        return AppTheme.warningAmber;
    }
  }

  IconData _getFAQIcon(String title) {
    switch (title) {
      case 'Getting Started':
        return Icons.rocket_launch_rounded;
      case 'Points & Badges':
        return Icons.emoji_events_rounded;
      case 'Safety & Verification':
        return Icons.verified_user_rounded;
      case 'Technical Issues':
        return Icons.bug_report_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      DateTime date;

      if (timestamp is DateTime) {
        date = timestamp;
      } else if (timestamp is Map && timestamp.containsKey('_seconds')) {
        final seconds = timestamp['_seconds'];
        final nanoseconds = timestamp['_nanoseconds'] ?? 0;
        date = DateTime.fromMillisecondsSinceEpoch(
          (seconds * 1000) + (nanoseconds ~/ 1000000),
        );
      } else if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else {
        return 'Unknown';
      }

      return Helpers.formatDateTime(date);
    } catch (e) {
      print('Error formatting timestamp: $e');
      return 'Unknown';
    }
  }
}
