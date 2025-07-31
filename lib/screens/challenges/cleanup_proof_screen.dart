// lib/screens/challenges/cleanup_proof_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/trash_report_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';
import '../../themes/app_theme.dart';
import '../../widgets/common/custom_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CleanupProofScreen extends StatefulWidget {
  final TrashReportModel challenge;

  const CleanupProofScreen({Key? key, required this.challenge})
    : super(key: key);

  @override
  _CleanupProofScreenState createState() => _CleanupProofScreenState();
}

class _CleanupProofScreenState extends State<CleanupProofScreen> {
  File? _proofImage;
  bool _isSubmitting = false;
  final StorageService _storageService = StorageService();
  final _notesController = TextEditingController();

  bool get canResubmit => widget.challenge.status == 'disputed';

  bool get isFirstSubmission =>
      widget.challenge.proofURL == null || widget.challenge.proofURL!.isEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(
          widget.challenge.status == 'disputed'
              ? 'Resubmit Cleanup Proof'
              : 'Submit Cleanup Proof',
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show resubmission notice only for disputed status
            if (widget.challenge.status == 'disputed')
              _buildResubmissionNotice(),

            // Original Trash Photo
            _buildOriginalPhotoSection(),
            const SizedBox(height: 24),

            // Proof Photo Section
            _buildProofPhotoSection(),
            const SizedBox(height: 24),

            // Notes Section
            _buildNotesSection(),
            const SizedBox(height: 24),

            // Safety Reminder
            _buildSafetyReminder(),
            const SizedBox(height: 100), // Space for bottom button
          ],
        ),
      ),
      bottomNavigationBar: _buildSubmitButton(),
    );
  }

  Widget _buildResubmissionNotice() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningYellow.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.warningYellow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: AppTheme.warningYellow),
              const SizedBox(width: 8),
              Text(
                'Cleanup Proof Disputed',
                style: AppTheme.labelMedium.copyWith(
                  color: AppTheme.warningYellow,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your previous proof photo was disputed. Please submit a new photo that clearly shows:',
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          if (widget.challenge.proofVerification?.reasons?.isNotEmpty ??
              false) ...[
            ...widget.challenge.proofVerification!.reasons.map(
              (reason) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: AppTheme.bodyMedium),
                    Expanded(
                      child: Text(
                        reason,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOriginalPhotoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Original Trash Report', style: AppTheme.headlineMedium),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: widget.challenge.imageURL,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 200,
                  color: AppTheme.lightGreen.withOpacity(0.3),
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 200,
                  color: AppTheme.lightGreen.withOpacity(0.3),
                  child: const Center(child: Icon(Icons.error)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Location: ${widget.challenge.address}',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProofPhotoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cleanup Proof Photo', style: AppTheme.headlineMedium),
            const SizedBox(height: 12),

            if (_proofImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _proofImage!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _takeNewPhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Retake Photo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _removePhoto,
                      icon: const Icon(Icons.delete),
                      label: const Text('Remove'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.dangerRed,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withOpacity(0.3),
                    style: BorderStyle.solid,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 48,
                      color: AppTheme.primaryGreen,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Take a photo of the cleaned area',
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Show the same location after cleanup',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('From Gallery'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cleanup Notes (Optional)', style: AppTheme.headlineMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText:
                    'Add any notes about the cleanup process, tools used, or challenges faced...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyReminder() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.infoBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.infoBlue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info, color: AppTheme.infoBlue),
              const SizedBox(width: 8),
              Text(
                'Cleanup Guidelines',
                style: AppTheme.labelMedium.copyWith(color: AppTheme.infoBlue),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '• Take the photo from the same angle as the original report\n'
            '• Ensure all visible trash has been removed\n'
            '• Dispose of waste properly in appropriate bins\n'
            '• If hazardous materials were involved, confirm safe disposal\n'
            '• Your proof photo will be reviewed by the community',
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: CustomButton(
          text: _isSubmitting
              ? 'Submitting...'
              : (widget.challenge.status == 'disputed'
                    ? 'Resubmit Cleanup Proof'
                    : 'Submit Cleanup Proof'),
          icon: Icons.check_circle,
          isLoading: _isSubmitting,
          onPressed: _proofImage != null ? _submitProof : null,
          backgroundColor: widget.challenge.status == 'disputed'
              ? AppTheme.warningYellow
              : AppTheme.primaryGreen,
        ),
      ),
    );
  }

  Future<void> _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null) {
        setState(() {
          _proofImage = File(image.path);
        });
      }
    } catch (e) {
      _showError('Failed to take photo: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null) {
        setState(() {
          _proofImage = File(image.path);
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  void _takeNewPhoto() {
    _takePhoto();
  }

  void _removePhoto() {
    setState(() {
      _proofImage = null;
    });
  }

  Future<void> _submitProof() async {
    if (_proofImage == null) return;

    setState(() => _isSubmitting = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user == null) {
        throw Exception('User not authenticated');
      }

      final proofURL = await _storageService.uploadCleanupProofImage(
        _proofImage!,
        widget.challenge.id,
        authProvider.user!.uid,
      );

      final data = {
        'proofURL': proofURL,
        'proofTimestamp': FieldValue.serverTimestamp(),
        'cleanupNotes': _notesController.text.trim(),
        'status': 'processing',
      };

      // Add resubmission-specific fields
      if (widget.challenge.status == 'disputed') {
        data['previousProofURL'] = widget.challenge.proofURL!;
        data['resubmissionAttempt'] = true;
        data['disputeResolved'] = false;
      }

      await FirebaseFirestore.instance
          .collection('trashReports')
          .doc(widget.challenge.id)
          .update(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.challenge.status == 'disputed'
                  ? 'Proof resubmitted successfully! Under review.'
                  : 'Cleanup proof submitted! Under review.',
            ),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      _showError('Failed to submit proof: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // In your CleanupProofScreen - add this to show verification status
  Widget _buildVerificationStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.security, color: AppTheme.infoBlue),
            SizedBox(height: 8),
            Text('AI Verification', style: AppTheme.headlineMedium),
            SizedBox(height: 8),
            Text(
              'Your proof will be automatically verified using AI to ensure it shows the same location cleaned up.',
              style: AppTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.dangerRed),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}
