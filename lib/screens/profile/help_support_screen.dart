// lib/screens/profile/help_support_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../themes/app_theme.dart';
import '../../services/support_service.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/loading_widget.dart';
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
          content: Text('Support message submitted successfully!'),
          backgroundColor: AppTheme.primaryGreen,
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
      SnackBar(content: Text(message), backgroundColor: AppTheme.dangerRed),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text('Help & Support'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'FAQ', icon: Icon(Icons.help_outline)),
            Tab(text: 'Contact', icon: Icon(Icons.email_outlined)),
            Tab(text: 'Messages', icon: Icon(Icons.message_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildFAQTab(), _buildContactTab(), _buildMessagesTab()],
      ),
    );
  }

  Widget _buildFAQTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(),
          SizedBox(height: 24),

          Text('Frequently Asked Questions', style: AppTheme.headlineMedium),
          SizedBox(height: 16),

          _buildFAQSection('Getting Started', [
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
          ]),

          SizedBox(height: 16),
          _buildFAQSection('Points & Badges', [
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
          ]),

          SizedBox(height: 16),
          _buildFAQSection('Safety & Verification', [
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
          ]),

          SizedBox(height: 16),
          _buildFAQSection('Technical Issues', [
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
          ]),
        ],
      ),
    );
  }

  Widget _buildContactTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.support_agent, color: AppTheme.primaryGreen),
                      SizedBox(width: 12),
                      Text('Contact Support', style: AppTheme.headlineMedium),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Need help? Send us a message and we\'ll get back to you as soon as possible.',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),

          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Selection
                _buildCategorySelection(),
                SizedBox(height: 16),

                // Priority Selection
                _buildPrioritySelection(),
                SizedBox(height: 16),

                // Subject Field
                _buildSubjectField(),
                SizedBox(height: 16),

                // Message Field
                _buildMessageField(),
                SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    text: 'Send Message',
                    onPressed: _isSubmitting ? null : _submitSupportMessage,
                    isLoading: _isSubmitting,
                    icon: Icons.send,
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
      return LoadingWidget(message: 'Loading your messages...');
    }

    if (_supportMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.message_outlined,
              size: 64,
              color: AppTheme.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              'No Support Messages',
              style: AppTheme.headlineMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'You haven\'t sent any support messages yet.',
              style: AppTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(1),
              icon: Icon(Icons.add),
              label: Text('Send Message'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSupportMessages,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _supportMessages.length,
        itemBuilder: (context, index) {
          final message = _supportMessages[index];
          return _buildMessageCard(message);
        },
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      color: AppTheme.primaryGreen.withOpacity(0.1),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.eco, size: 48, color: AppTheme.primaryGreen),
            SizedBox(height: 16),
            Text(
              'Welcome to TrashTagger Support',
              style: AppTheme.headlineMedium.copyWith(
                color: AppTheme.primaryGreen,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Find answers to common questions or contact our support team for personalized help.',
              style: AppTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQSection(String title, List<Map<String, String>> faqs) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              //style: AppTheme.labelLarge.copyWith(color: AppTheme.primaryGreen),
            ),
            SizedBox(height: 12),
            ...faqs.map(
              (faq) => _buildFAQItem(faq['question']!, faq['answer']!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return ExpansionTile(
      title: Text(question, style: AppTheme.labelMedium),
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            answer,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category',
              style: AppTheme.labelMedium.copyWith(
                color: AppTheme.primaryGreen,
              ),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: SupportService.categories.entries.map((entry) {
                return FilterChip(
                  label: Text(entry.value),
                  selected: _selectedCategory == entry.key,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCategory = entry.key);
                    }
                  },
                  selectedColor: AppTheme.primaryGreen.withOpacity(0.2),
                  checkmarkColor: AppTheme.primaryGreen,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrioritySelection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Priority',
              style: AppTheme.labelMedium.copyWith(
                color: AppTheme.primaryGreen,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: SupportService.priorities.entries.map((entry) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: _selectedPriority == entry.key,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedPriority = entry.key);
                        }
                      },
                      selectedColor: AppTheme.primaryGreen.withOpacity(0.2),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectField() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subject',
              style: AppTheme.labelMedium.copyWith(
                color: AppTheme.primaryGreen,
              ),
            ),
            SizedBox(height: 8),
            TextFormField(
              controller: _subjectController,
              decoration: InputDecoration(
                hintText: 'Brief description of your issue',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.primaryGreen),
                ),
              ),
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
      ),
    );
  }

  Widget _buildMessageField() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Message',
              style: AppTheme.labelMedium.copyWith(
                color: AppTheme.primaryGreen,
              ),
            ),
            SizedBox(height: 8),
            TextFormField(
              controller: _messageController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Please describe your issue in detail...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.primaryGreen),
                ),
              ),
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
            ),
            SizedBox(height: 8),
            Text(
              '${_messageController.text.length}/2000 characters',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> message) {
    final status = message['status'] ?? 'open';
    final hasResponse = message['adminResponse'] != null;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    message['subject'] ?? 'No Subject',
                    style: AppTheme.labelMedium,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    SupportService.getStatusDisplayName(status),
                    style: AppTheme.bodyMedium.copyWith(
                      color: _getStatusColor(status),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),

            Row(
              children: [
                Icon(Icons.category, size: 16, color: AppTheme.textSecondary),
                SizedBox(width: 4),
                Text(
                  SupportService.getCategoryDisplayName(
                    message['category'] ?? 'general',
                  ),
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                SizedBox(width: 16),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                SizedBox(width: 4),
                Text(
                  _formatTimestamp(message['createdAt']),
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            Text(
              message['message'] ?? '',
              style: AppTheme.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

            if (hasResponse) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.support_agent,
                          size: 16,
                          color: AppTheme.primaryGreen,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Support Response',
                          style: AppTheme.labelMedium.copyWith(
                            color: AppTheme.primaryGreen,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
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
        return AppTheme.warningOrange;
      case 'resolved':
        return AppTheme.primaryGreen;
      case 'closed':
        return AppTheme.textSecondary;
      default:
        return AppTheme.textSecondary;
    }
  }

  // In your help_support_screen.dart file, update the _formatTimestamp method:

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      DateTime date;

      if (timestamp is DateTime) {
        date = timestamp;
      } else if (timestamp is Map && timestamp.containsKey('_seconds')) {
        // Handle Firestore timestamp format
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
