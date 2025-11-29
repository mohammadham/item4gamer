import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ila_service.dart';
import '../models/ila_models.dart';

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

  // رنگ اصلی برند
  final Color _primaryColor = const Color(0xFF003EFF);
  final String _botAvatarUrl = 'https://app.ila.chat/storage/bots/2/961818.png';

  @override
  void initState() {
    super.initState();
    _initChat();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطا در برقراری ارتباط با سرور چت')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطا در ارسال پیام')),
        );
      }
    }

    setState(() {
      _isSending = false;
    });
  }

  Future<void> _pickAndSendFile() async {
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('خطا در ارسال فایل')),
          );
        }
      }

      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _launchFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('امکان باز کردن فایل وجود ندارد')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // Light gray background
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(_botAvatarUrl),
              radius: 16,
              backgroundColor: Colors.transparent,
            ),
            const SizedBox(width: 8),
            const Text(
              'پشتیبانی آنلاین',
              style: TextStyle(
                  fontFamily: 'YekanBakh',
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
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
                            Image.network(_botAvatarUrl, width: 80, height: 80),
                            const SizedBox(height: 16),
                            const Text(
                              'به پشتیبانی خوش آمدید\nچطور می‌توانیم کمکتان کنیم؟',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontFamily: 'YekanBakh',
                                  color: Colors.grey,
                                  fontSize: 16),
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
              padding: const EdgeInsets.only(
                  left: 4, right: 8), // Adjusted for RTL/LTR
              child: CircleAvatar(
                backgroundImage: NetworkImage(_botAvatarUrl),
                radius: 14,
                backgroundColor: Colors.transparent,
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
                                    'دانلود فایل ضمیمه',
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
            Material(
              color: Colors.transparent,
              child: IconButton(
                icon: const Icon(Icons.attach_file_rounded),
                color: Colors.grey[600],
                onPressed: _pickAndSendFile,
                splashRadius: 24,
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'پیام خود را بنویسید...',
                    hintStyle: TextStyle(
                        fontFamily: 'YekanBakh',
                        fontSize: 14,
                        color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    isDense: true,
                  ),
                  style: const TextStyle(fontFamily: 'YekanBakh', fontSize: 14),
                  maxLines: 4,
                  minLines: 1,
                ),
              ),
            ),
            const SizedBox(width: 8),
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
