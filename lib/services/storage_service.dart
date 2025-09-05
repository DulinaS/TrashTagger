// lib/services/storage_service.dart - Updated version
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final Uuid _uuid = Uuid();

  // ================================
  // IMAGE UPLOAD METHODS
  // ================================

  // Upload image file (for trash reports and cleanup proofs)
  static Future<String> uploadImage(
    File imageFile,
    String folder, {
    String? customFileName,
    bool compressImage = true,
  }) async {
    try {
      // Generate unique filename
      String fileName = customFileName ?? _generateFileName(imageFile.path);
      String fullPath = '$folder/$fileName';

      // Get file bytes
      Uint8List imageBytes = await imageFile.readAsBytes();

      // Compress image if needed
      if (compressImage) {
        imageBytes = await _compressImage(imageBytes);
      }

      // Create reference
      Reference ref = _storage.ref().child(fullPath);

      // Set metadata
      SettableMetadata metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
          'folder': folder,
        },
      );

      // Upload file
      UploadTask uploadTask = ref.putData(imageBytes, metadata);

      // Monitor upload progress
      await uploadTask;

      // Get download URL
      String downloadURL = await ref.getDownloadURL();

      return downloadURL;
    } on FirebaseException catch (e) {
      throw StorageException('Upload failed: ${e.message}');
    } catch (e) {
      throw StorageException('Upload failed: $e');
    }
  }

  // Upload image from bytes (useful for camera captures)
  static Future<String> uploadImageFromBytes(
    Uint8List imageBytes,
    String folder, {
    String? customFileName,
    bool compressImage = true,
  }) async {
    try {
      // Generate unique filename
      String fileName = customFileName ?? '${_uuid.v4()}.jpg';
      String fullPath = '$folder/$fileName';

      // Compress image if needed
      if (compressImage) {
        imageBytes = await _compressImage(imageBytes);
      }

      // Create reference
      Reference ref = _storage.ref().child(fullPath);

      // Set metadata
      SettableMetadata metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
          'folder': folder,
        },
      );

      // Upload file
      UploadTask uploadTask = ref.putData(imageBytes, metadata);

      // Wait for completion
      await uploadTask;

      // Get download URL
      String downloadURL = await ref.getDownloadURL();

      return downloadURL;
    } on FirebaseException catch (e) {
      throw StorageException('Upload failed: ${e.message}');
    } catch (e) {
      throw StorageException('Upload failed: $e');
    }
  }

  // ================================
  // SPECIFIC UPLOAD METHODS
  // ================================

  // Upload trash report image
  static Future<String> uploadTrashReportImage(
    File imageFile,
    String reporterId,
  ) async {
    try {
      String fileName =
          'report_${reporterId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      return await uploadImage(
        imageFile,
        'trash_reports',
        customFileName: fileName,
        compressImage: true,
      );
    } catch (e) {
      throw StorageException('Failed to upload trash report image: $e');
    }
  }

  // Upload cleanup proof image
  static Future<String> uploadCleanupProofImage(
    File imageFile,
    String reportId,
    String cleanerId,
  ) async {
    try {
      String fileName =
          'proof_${reportId}_${cleanerId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      return await uploadImage(
        imageFile,
        'cleanup_proofs',
        customFileName: fileName,
        compressImage: true,
      );
    } catch (e) {
      throw StorageException('Failed to upload cleanup proof image: $e');
    }
  }

  // Add this method to your existing StorageService class
  // Update the uploadProfilePhoto method to clean up after upload
  static Future<String> uploadProfilePhoto(
    File imageFile,
    String userId,
  ) async {
    try {
      // Delete old profile photo first if it exists
      try {
        String oldPhotoPath = 'profile_photos/profile_$userId.jpg';
        Reference oldRef = _storage.ref().child(oldPhotoPath);
        await oldRef.delete();
      } catch (e) {
        print('Old profile photo not found: $e');
      }

      String fileName = 'profile_$userId.jpg';
      String downloadUrl = await uploadImage(
        imageFile,
        'profile_photos',
        customFileName: fileName,
        compressImage: true,
      );

      // Clean up local file after successful upload
      try {
        if (await imageFile.exists()) {
          await imageFile.delete();
        }
      } catch (e) {
        print('Could not delete temporary file: $e');
      }

      return downloadUrl;
    } catch (e) {
      throw StorageException('Failed to upload profile photo: $e');
    }
  }

  // Upload user profile image (keeping for backward compatibility)
  static Future<String> uploadProfileImage(
    File imageFile,
    String userId,
  ) async {
    return await uploadProfilePhoto(imageFile, userId);
  }

  // ================================
  // SUPPORT MESSAGE ATTACHMENTS
  // ================================

  // Upload support message attachment
  static Future<String> uploadSupportAttachment(
    File file,
    String userId,
    String messageId,
  ) async {
    try {
      String fileName =
          'attachment_${messageId}_${DateTime.now().millisecondsSinceEpoch}${path.extension(file.path)}';

      // Get file bytes
      Uint8List fileBytes = await file.readAsBytes();

      // Create reference
      Reference ref = _storage.ref().child('support_attachments/$fileName');

      // Determine content type
      String contentType = _getContentType(file.path);

      // Set metadata
      SettableMetadata metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
          'userId': userId,
          'messageId': messageId,
          'originalName': path.basename(file.path),
        },
      );

      // Upload file
      UploadTask uploadTask = ref.putData(fileBytes, metadata);
      await uploadTask;

      // Get download URL
      return await ref.getDownloadURL();
    } catch (e) {
      throw StorageException('Failed to upload support attachment: $e');
    }
  }

  // ================================
  // FILE MANAGEMENT
  // ================================

  // Delete old profile photo
  static Future<void> _deleteOldProfilePhoto(String userId) async {
    try {
      String oldPhotoPath = 'profile_photos/profile_$userId.jpg';
      await deleteFile(oldPhotoPath);
    } catch (e) {
      // Ignore error if old photo doesn't exist
      print('Old profile photo not found or could not be deleted: $e');
    }
  }

  // Delete file by URL
  static Future<void> deleteFileByUrl(String downloadUrl) async {
    try {
      Reference ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') {
        throw StorageException('Delete failed: ${e.message}');
      }
      // File doesn't exist, which is fine for deletion
    } catch (e) {
      throw StorageException('Delete failed: $e');
    }
  }

  // Delete file by path
  static Future<void> deleteFile(String filePath) async {
    try {
      Reference ref = _storage.ref().child(filePath);
      await ref.delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') {
        throw StorageException('Delete failed: ${e.message}');
      }
    } catch (e) {
      throw StorageException('Delete failed: $e');
    }
  }

  // Get file metadata
  static Future<FullMetadata?> getFileMetadata(String downloadUrl) async {
    try {
      Reference ref = _storage.refFromURL(downloadUrl);
      return await ref.getMetadata();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        return null;
      }
      throw StorageException('Failed to get metadata: ${e.message}');
    } catch (e) {
      throw StorageException('Failed to get metadata: $e');
    }
  }

  // ================================
  // BATCH OPERATIONS
  // ================================

  // Delete multiple files
  static Future<void> deleteMultipleFiles(List<String> downloadUrls) async {
    try {
      List<Future<void>> deleteFutures = downloadUrls
          .map((url) => deleteFileByUrl(url))
          .toList();
      await Future.wait(deleteFutures);
    } catch (e) {
      throw StorageException('Batch delete failed: $e');
    }
  }

  // List files in a folder
  static Future<List<Reference>> listFilesInFolder(
    String folderPath, {
    int maxResults = 100,
  }) async {
    try {
      Reference ref = _storage.ref().child(folderPath);
      ListResult result = await ref.list(ListOptions(maxResults: maxResults));
      return result.items;
    } on FirebaseException catch (e) {
      throw StorageException('Failed to list files: ${e.message}');
    } catch (e) {
      throw StorageException('Failed to list files: $e');
    }
  }

  // ================================
  // HELPER METHODS
  // ================================

  // Generate unique filename
  static String _generateFileName(String originalPath) {
    String extension = path.extension(originalPath);
    if (extension.isEmpty) extension = '.jpg';
    return '${_uuid.v4()}$extension';
  }

  // Get content type based on file extension
  static String _getContentType(String filePath) {
    String extension = path.extension(filePath).toLowerCase();
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.pdf':
        return 'application/pdf';
      case '.txt':
        return 'text/plain';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  // Compress image (basic implementation)
  static Future<Uint8List> _compressImage(Uint8List imageBytes) async {
    // This is a placeholder for image compression
    // In a real app, you might use packages like:
    // - flutter_image_compress
    // - image (for Dart-native compression)

    // For now, return original bytes
    // TODO: Implement actual compression based on file size
    return imageBytes;
  }

  // ================================
  // UPLOAD PROGRESS TRACKING
  // ================================

  // Upload with progress tracking
  static Stream<double> uploadImageWithProgress(
    File imageFile,
    String folder, {
    String? customFileName,
    bool compressImage = true,
  }) async* {
    try {
      // Generate unique filename
      String fileName = customFileName ?? _generateFileName(imageFile.path);
      String fullPath = '$folder/$fileName';

      // Get file bytes
      Uint8List imageBytes = await imageFile.readAsBytes();

      // Compress image if needed
      if (compressImage) {
        imageBytes = await _compressImage(imageBytes);
      }

      // Create reference
      Reference ref = _storage.ref().child(fullPath);

      // Set metadata
      SettableMetadata metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
          'folder': folder,
        },
      );

      // Start upload
      UploadTask uploadTask = ref.putData(imageBytes, metadata);

      // Listen to state changes
      await for (TaskSnapshot snapshot in uploadTask.snapshotEvents) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        yield progress;

        if (snapshot.state == TaskState.success) {
          break;
        } else if (snapshot.state == TaskState.error) {
          throw StorageException('Upload failed');
        }
      }
    } catch (e) {
      throw StorageException('Upload with progress failed: $e');
    }
  }

  // Upload profile photo with progress
  static Stream<double> uploadProfilePhotoWithProgress(
    File imageFile,
    String userId,
  ) async* {
    try {
      // Delete old profile photo first
      await _deleteOldProfilePhoto(userId);

      String fileName = 'profile_$userId.jpg';

      await for (double progress in uploadImageWithProgress(
        imageFile,
        'profile_photos',
        customFileName: fileName,
        compressImage: true,
      )) {
        yield progress;
      }
    } catch (e) {
      throw StorageException(
        'Failed to upload profile photo with progress: $e',
      );
    }
  }

  // ================================
  // UTILITY METHODS
  // ================================

  // Get storage usage for a user
  static Future<StorageUsageInfo> getUserStorageUsage(String userId) async {
    try {
      int totalSize = 0;
      int fileCount = 0;

      // Check different folders for user's files
      List<String> userFolders = [
        'trash_reports',
        'cleanup_proofs',
        'profile_photos',
        'support_attachments',
      ];

      for (String folder in userFolders) {
        try {
          List<Reference> files = await listFilesInFolder(folder);

          for (Reference file in files) {
            try {
              FullMetadata? metadata = await file.getMetadata();
              if (metadata != null &&
                  (metadata.customMetadata?['userId'] == userId ||
                      file.name.contains(userId))) {
                totalSize += metadata.size ?? 0;
                fileCount++;
              }
            } catch (e) {
              // Skip files that can't be accessed
              continue;
            }
          }
        } catch (e) {
          // Skip folders that can't be accessed
          continue;
        }
      }

      return StorageUsageInfo(
        totalSizeBytes: totalSize,
        fileCount: fileCount,
        totalSizeMB: totalSize / (1024 * 1024),
      );
    } catch (e) {
      throw StorageException('Failed to get storage usage: $e');
    }
  }

  // Check if file exists
  static Future<bool> fileExists(String downloadUrl) async {
    try {
      Reference ref = _storage.refFromURL(downloadUrl);
      await ref.getMetadata();
      return true;
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        return false;
      }
      throw StorageException('Failed to check file existence: ${e.message}');
    } catch (e) {
      throw StorageException('Failed to check file existence: $e');
    }
  }

  // Get optimized image URL (for thumbnails)
  static String getOptimizedImageUrl(
    String originalUrl, {
    int? width,
    int? height,
  }) {
    // This would work with Firebase Storage image optimization
    // For now, return original URL
    // In production, you might use Firebase Extensions or Cloud Functions
    // to generate optimized images
    return originalUrl;
  }

  // Validate file size
  static Future<bool> isValidFileSize(File file, {int maxSizeMB = 5}) async {
    try {
      int fileSizeBytes = await file.length();
      int maxSizeBytes = maxSizeMB * 1024 * 1024;
      return fileSizeBytes <= maxSizeBytes;
    } catch (e) {
      return false;
    }
  }

  // Validate image file
  static bool isValidImageFile(String filePath) {
    String extension = path.extension(filePath).toLowerCase();
    List<String> validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    return validExtensions.contains(extension);
  }
}

// ================================
// MODELS AND EXCEPTIONS
// ================================

class StorageUsageInfo {
  final int totalSizeBytes;
  final int fileCount;
  final double totalSizeMB;

  StorageUsageInfo({
    required this.totalSizeBytes,
    required this.fileCount,
    required this.totalSizeMB,
  });

  @override
  String toString() {
    return 'StorageUsageInfo(files: $fileCount, size: ${totalSizeMB.toStringAsFixed(2)} MB)';
  }
}

class StorageException implements Exception {
  final String message;
  StorageException(this.message);

  @override
  String toString() => message;
}

// Enum for upload status
enum UploadStatus { idle, uploading, success, error }

// Upload result class
class UploadResult {
  final String? downloadUrl;
  final UploadStatus status;
  final String? error;

  UploadResult({this.downloadUrl, required this.status, this.error});

  bool get isSuccess => status == UploadStatus.success && downloadUrl != null;
  bool get isError => status == UploadStatus.error;
}
