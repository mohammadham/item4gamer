import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';

enum PermissionType { microphone, camera, storage }

class PermissionDialog extends StatelessWidget {
  final PermissionType permissionType;
  final VoidCallback onGrantPermission;
  final VoidCallback onGoToSettings;
  final bool isPermanentlyDenied;

  const PermissionDialog({
    Key? key,
    required this.permissionType,
    required this.onGrantPermission,
    required this.onGoToSettings,
    this.isPermanentlyDenied = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    String title;
    String message;
    IconData icon;

    switch (permissionType) {
      case PermissionType.microphone:
        title = localizations.microphonePermission;
        message = isPermanentlyDenied
            ? localizations.permissionPermanentlyDenied
            : localizations.microphonePermissionMessage;
        icon = Icons.mic_rounded;
        break;
      case PermissionType.camera:
        title = localizations.cameraPermission;
        message = isPermanentlyDenied
            ? localizations.permissionPermanentlyDenied
            : localizations.cameraPermissionMessage;
        icon = Icons.camera_alt_rounded;
        break;
      case PermissionType.storage:
        title = localizations.storagePermission;
        message = isPermanentlyDenied
            ? localizations.permissionPermanentlyDenied
            : localizations.storagePermissionMessage;
        icon = Icons.folder_rounded;
        break;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon container with gradient background
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withOpacity(0.1),
                    primaryColor.withOpacity(0.2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                icon,
                size: 40,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            // Title
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'YekanBakh',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // Message
            Text(
              message,
              style: TextStyle(
                fontFamily: 'YekanBakh',
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Buttons
            Row(
              children: [
                // Cancel button
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Text(
                      localizations.cancel,
                      style: TextStyle(
                        fontFamily: 'YekanBakh',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Action button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (isPermanentlyDenied) {
                        onGoToSettings();
                      } else {
                        onGrantPermission();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isPermanentlyDenied
                          ? localizations.goToSettings
                          : localizations.grantPermission,
                      style: const TextStyle(
                        fontFamily: 'YekanBakh',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Future<bool> checkAndRequestPermission(
    BuildContext context,
    PermissionType type,
  ) async {
    Permission permission;
    switch (type) {
      case PermissionType.microphone:
        permission = Permission.microphone;
        break;
      case PermissionType.camera:
        permission = Permission.camera;
        break;
      case PermissionType.storage:
        permission = Permission.storage;
        break;
    }

    final status = await permission.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      await showDialog(
        context: context,
        builder: (ctx) => PermissionDialog(
          permissionType: type,
          isPermanentlyDenied: true,
          onGrantPermission: () {},
          onGoToSettings: () => openAppSettings(),
        ),
      );
      return false;
    }

    // Show dialog and request permission
    bool? shouldRequest = await showDialog<bool>(
      context: context,
      builder: (ctx) => PermissionDialog(
        permissionType: type,
        isPermanentlyDenied: false,
        onGrantPermission: () => Navigator.of(ctx).pop(true),
        onGoToSettings: () => openAppSettings(),
      ),
    );

    if (shouldRequest == true) {
      final result = await permission.request();
      return result.isGranted;
    }

    return false;
  }
}
