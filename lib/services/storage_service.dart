// lib/services/storage_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = Uuid();

  // ================================
  // IMAGE UPLOAD METHODS
  // ================================

  // Upload image file (for trash reports and cleanup proofs)
  Future<String> uploadImage(
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
  Future<String> uploadImageFromBytes(
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
  Future<String> uploadTrashReportImage(
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
  Future<String> uploadCleanupProofImage(
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

  // Upload user profile image
  Future<String> uploadProfileImage(File imageFile, String userId) async {
    try {
      String fileName = 'profile_$userId.jpg';
      return await uploadImage(
        imageFile,
        'profile_images',
        customFileName: fileName,
        compressImage: true,
      );
    } catch (e) {
      throw StorageException('Failed to upload profile image: $e');
    }
  }

  // ================================
  // FILE MANAGEMENT
  // ================================

  // Delete file by URL
  Future<void> deleteFileByUrl(String downloadUrl) async {
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
  Future<void> deleteFile(String filePath) async {
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
  Future<FullMetadata?> getFileMetadata(String downloadUrl) async {
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
  Future<void> deleteMultipleFiles(List<String> downloadUrls) async {
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
  Future<List<Reference>> listFilesInFolder(
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
  String _generateFileName(String originalPath) {
    String extension = path.extension(originalPath);
    if (extension.isEmpty) extension = '.jpg';
    return '${_uuid.v4()}$extension';
  }

  // Compress image (basic implementation)
  Future<Uint8List> _compressImage(Uint8List imageBytes) async {
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
  Stream<double> uploadImageWithProgress(
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

  // ================================
  // UTILITY METHODS
  // ================================

  // Get storage usage for a user
  Future<StorageUsageInfo> getUserStorageUsage(String userId) async {
    try {
      int totalSize = 0;
      int fileCount = 0;

      // Check different folders for user's files
      List<String> userFolders = [
        'trash_reports',
        'cleanup_proofs',
        'profile_images',
      ];

      for (String folder in userFolders) {
        List<Reference> files = await listFilesInFolder(folder);

        for (Reference file in files) {
          FullMetadata? metadata = await file.getMetadata();
          if (metadata != null &&
              metadata.customMetadata?['userId'] == userId) {
            totalSize += metadata.size ?? 0;
            fileCount++;
          }
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
  Future<bool> fileExists(String downloadUrl) async {
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
  String getOptimizedImageUrl(String originalUrl, {int? width, int? height}) {
    // This would work with Firebase Storage image optimization
    // For now, return original URL
    // In production, you might use Firebase Extensions or Cloud Functions
    // to generate optimized images
    return originalUrl;
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
