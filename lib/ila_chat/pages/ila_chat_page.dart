import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ila_service.dart';
import '../models/ila_models.dart';
import '../widgets/permission_dialog.dart';
import '../widgets/voice_widgets.dart';
import '../widgets/image_preview_dialog.dart';

class IlaChatPage extends StatefulWidget {
  const IlaChatPage({Key? key}) : super(key: key);

  @override
  State<IlaChatPage> createState() => _IlaChatPageState();
}

class _IlaChatPageState extends State<IlaChatPage> {
  final IlaService _service = IlaService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<IlaMessage> _messages = [];
  String? _conversationId;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isRecording = false;

  // Permission states
  bool _hasMicPermission = false;
  bool _hasCameraPermission = false;
  bool _hasStoragePermission = false;

  // App logo path
  final String _appLogoPath = 'assets/images/logoLight.png';

  @override
  void initState() {
    super.initState();
    _initChat();
    _checkPermissions();
  }

  Color get _primaryColor => Theme.of(context).primaryColor;

  Future<void> _checkPermissions() async {
    _hasMicPermission = await Permission.microphone.isGranted;
    _hasCameraPermission = await Permission.camera.isGranted;
    _hasStoragePermission =
        await Permission.storage.isGranted || await Permission.photos.isGranted;
    if (mounted) setState(() {});
  }

  Future<void> _initChat() async {
    String? savedId = await _service.getSavedConversationId();

    if (savedId == null) {
      savedId = await _service.createConversation();
    }

    if (savedId != null) {
      setState(() {
        _conversationId = savedId;
      });
      _loadMessages();

      Timer.periodic(const Duration(seconds: 5), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        _loadMessages(silent: true);
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        final localizations = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.chatConnectionError)),
        );
      }
    }
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (_conversationId == null) return;

    final msgs = await _service.getMessages(_conversationId!);
    if (mounted) {
      setState(() {
        _messages = msgs;
        if (!silent) _isLoading = false;
      });

      if (!silent) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _conversationId == null) return;

    setState(() {
      _isSending = true;
    });

    final success = await _service.sendMessage(_conversationId!, text);

    if (success) {
      _controller.clear();
      await _loadMessages();
    } else {
      if (mounted) {
        final localizations = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.messageSendError)),
        );
      }
    }

    setState(() {
      _isSending = false;
    });
  }

  Future<void> _pickAndSendFile() async {
    // Check permission first
    if (!_hasStoragePermission) {
      final granted = await PermissionDialog.checkAndRequestPermission(
        context,
        PermissionType.storage,
      );
      if (granted) {
        setState(() => _hasStoragePermission = true);
      } else {
        return;
      }
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      File file = File(result.files.single.path!);

      setState(() {
        _isSending = true;
      });

      final success = await _service.sendFile(_conversationId!, file, null);

      if (success) {
        await _loadMessages();
      } else {
        if (mounted) {
          final localizations = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations.fileSendError)),
          );
        }
      }

      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _pickAndSendImage() async {
    // Check permission first
    if (!_hasStoragePermission) {
      final granted = await PermissionDialog.checkAndRequestPermission(
        context,
        PermissionType.storage,
      );
      if (granted) {
        setState(() => _hasStoragePermission = true);
      } else {
        return;
      }
    }

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      File file = File(image.path);

      // Show preview before sending
      if (mounted) {
        ImagePreviewDialog.show(
          context,
          imageSource: file,
          onSend: () => _sendImageFile(file),
        );
      }
    }
  }

  Future<void> _takeAndSendPhoto() async {
    // Check camera permission first
    if (!_hasCameraPermission) {
      final granted = await PermissionDialog.checkAndRequestPermission(
        context,
        PermissionType.camera,
      );
      if (granted) {
        setState(() => _hasCameraPermission = true);
      } else {
        return;
      }
    }

    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);

    if (photo != null) {
      File file = File(photo.path);

      // Show preview before sending
      if (mounted) {
        ImagePreviewDialog.show(
          context,
          imageSource: file,
          onSend: () => _sendImageFile(file),
        );
      }
    }
  }

  Future<void> _sendImageFile(File file) async {
    setState(() {
      _isSending = true;
    });

    final success = await _service.sendFile(_conversationId!, file, null);

    if (success) {
      await _loadMessages();
    } else {
      if (mounted) {
        final localizations = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.fileSendError)),
        );
      }
    }

    setState(() {
      _isSending = false;
    });
  }

  Future<void> _startVoiceRecording() async {
    // Check mic permission first
    if (!_hasMicPermission) {
      final granted = await PermissionDialog.checkAndRequestPermission(
        context,
        PermissionType.microphone,
      );
      if (granted) {
        setState(() => _hasMicPermission = true);
      } else {
        return;
      }
    }

    setState(() {
      _isRecording = true;
    });
  }

  void _onVoiceRecordingComplete(String filePath) async {
    setState(() {
      _isRecording = false;
      _isSending = true;
    });

    final file = File(filePath);
    final success = await _service.sendVoice(_conversationId!, file);

    if (success) {
      await _loadMessages();
    } else {
      if (mounted) {
        final localizations = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.voiceSendError)),
        );
      }
    }

    setState(() {
      _isSending = false;
    });

    // Delete temp file
    try {
      await file.delete();
    } catch (e) {
      print('Error deleting temp voice file: $e');
    }
  }

  void _onVoiceRecordingCancel() {
    setState(() {
      _isRecording = false;
    });
  }

  Future<void> _launchFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        final localizations = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.cannotOpenFile)),
        );
      }
    }
  }

  void _showAttachmentOptions() {
    final localizations = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Options
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAttachmentOption(
                    icon: Icons.image_rounded,
                    label: localizations.selectImage,
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendImage();
                    },
                    hasPermission: _hasStoragePermission,
                  ),
                  _buildAttachmentOption(
                    icon: Icons.camera_alt_rounded,
                    label: localizations.takePhoto,
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(ctx);
                      _takeAndSendPhoto();
                    },
                    hasPermission: _hasCameraPermission,
                  ),
                  _buildAttachmentOption(
                    icon: Icons.attach_file_rounded,
                    label: localizations.selectFile,
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendFile();
                    },
                    hasPermission: _hasStoragePermission,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool hasPermission,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: hasPermission ? color.withOpacity(0.1) : Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: hasPermission ? color : Colors.grey[400],
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'YekanBakh',
              fontSize: 12,
              color: hasPermission ? Colors.black87 : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // App logo
            ClipOval(
              child: Image.asset(
                _appLogoPath,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _primaryColor.withOpacity(0.1),
                    ),
                    child: Icon(
                      Icons.support_agent_rounded,
                      color: _primaryColor,
                      size: 20,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Text(
              localizations.onlineSupport,
              style: const TextStyle(
                fontFamily: 'YekanBakh',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // App logo
                            ClipOval(
                              child: Image.asset(
                                _appLogoPath,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _primaryColor.withOpacity(0.1),
                                    ),
                                    child: Icon(
                                      Icons.support_agent_rounded,
                                      color: _primaryColor,
                                      size: 40,
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              localizations.welcomeToSupport,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'YekanBakh',
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          return _buildMessageBubble(msg);
                        },
                      ),
          ),
          if (_isSending) const LinearProgressIndicator(minHeight: 2),
          if (_isRecording)
            VoiceRecorderWidget(
              onRecordingComplete: _onVoiceRecordingComplete,
              onCancel: _onVoiceRecordingCancel,
              maxDurationSeconds: 180, // 3 minutes
              primaryColor: _primaryColor,
            )
          else
            _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(IlaMessage msg) {
    final isMe = !msg.isBot;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 8),
              child: ClipOval(
                child: Image.asset(
                  _appLogoPath,
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _primaryColor.withOpacity(0.1),
                      ),
                      child: Icon(
                        Icons.support_agent_rounded,
                        color: _primaryColor,
                        size: 18,
                      ),
                    );
                  },
                ),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? _primaryColor : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isMe ? const Radius.circular(18) : Radius.zero,
                  bottomRight: isMe ? Radius.zero : const Radius.circular(18),
                ),
                boxShadow: [
                  if (!isMe)
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text message
                  if (msg.message != null && msg.message!.isNotEmpty)
                    Text(
                      msg.message!,
                      style: TextStyle(
                        fontFamily: 'YekanBakh',
                        fontSize: 14,
                        color: isMe ? Colors.white : Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  // Voice messages
                  if (msg.voices.isNotEmpty)
                    ...msg.voices.map((v) => Padding(
                          padding: EdgeInsets.only(
                            top: msg.message != null && msg.message!.isNotEmpty
                                ? 8.0
                                : 0,
                          ),
                          child: VoicePlayerWidget(
                            url: v,
                            isMe: isMe,
                            primaryColor: _primaryColor,
                          ),
                        )),
                  // Images
                  if (msg.images.isNotEmpty)
                    ...msg.images.map((imgUrl) => Padding(
                          padding: EdgeInsets.only(
                            top: msg.message != null && msg.message!.isNotEmpty
                                ? 8.0
                                : 0,
                          ),
                          child: GestureDetector(
                            onTap: () => ImagePreviewDialog.show(
                              context,
                              imageSource: imgUrl,
                              showSendButton: false,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: imgUrl,
                                width: 200,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 200,
                                  height: 150,
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 200,
                                  height: 150,
                                  color: Colors.grey[200],
                                  child: Icon(
                                    Icons.broken_image_rounded,
                                    color: Colors.grey[400],
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )),
                  // Files
                  if (msg.files.isNotEmpty)
                    ...msg.files.map((f) => Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: InkWell(
                            onTap: () => _launchFile(f),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? Colors.white.withOpacity(0.2)
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.download_rounded,
                                      size: 18,
                                      color:
                                          isMe ? Colors.white : _primaryColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    AppLocalizations.of(context)!
                                        .downloadAttachment,
                                    style: TextStyle(
                                      fontFamily: 'YekanBakh',
                                      fontSize: 12,
                                      color:
                                          isMe ? Colors.white : _primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final localizations = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Attachment button
            Material(
              color: Colors.transparent,
              child: IconButton(
                icon: const Icon(Icons.attach_file_rounded),
                color:
                    _hasStoragePermission ? Colors.grey[600] : Colors.grey[400],
                onPressed: _showAttachmentOptions,
                splashRadius: 24,
              ),
            ),
            // Voice button
            Material(
              color: Colors.transparent,
              child: IconButton(
                icon: const Icon(Icons.mic_rounded),
                color: _hasMicPermission ? Colors.grey[600] : Colors.grey[400],
                onPressed: _startVoiceRecording,
                splashRadius: 24,
              ),
            ),
            // Text input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: localizations.typeYourMessage,
                    hintStyle: const TextStyle(
                      fontFamily: 'YekanBakh',
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                  style: const TextStyle(fontFamily: 'YekanBakh', fontSize: 14),
                  maxLines: 4,
                  minLines: 1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send button
            Material(
              color: _primaryColor,
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.send_rounded),
                color: Colors.white,
                onPressed: _sendMessage,
                splashRadius: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
