import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

class VoiceRecorderWidget extends StatefulWidget {
  final Function(String filePath) onRecordingComplete;
  final VoidCallback onCancel;
  final int maxDurationSeconds;
  final Color primaryColor;

  const VoiceRecorderWidget({
    Key? key,
    required this.onRecordingComplete,
    required this.onCancel,
    this.maxDurationSeconds = 180, // 3 minutes
    required this.primaryColor,
  }) : super(key: key);

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _timer;
  int _recordDuration = 0;
  bool _isRecording = false;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final path =
            '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordDuration = 0;
        });

        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordDuration++;
          });

          if (_recordDuration >= widget.maxDurationSeconds) {
            _stopRecording();
          }
        });
      }
    } catch (e) {
      print('Error starting recording: $e');
      widget.onCancel();
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();

    try {
      final path = await _recorder.stop();
      if (path != null && _recordDuration > 0) {
        widget.onRecordingComplete(path);
      } else {
        widget.onCancel();
      }
    } catch (e) {
      print('Error stopping recording: $e');
      widget.onCancel();
    }
  }

  void _cancelRecording() async {
    _timer?.cancel();
    try {
      await _recorder.stop();
    } catch (e) {
      print('Error canceling recording: $e');
    }
    widget.onCancel();
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Cancel button
            IconButton(
              onPressed: _cancelRecording,
              icon: const Icon(Icons.delete_outline_rounded),
              color: Colors.red[400],
              iconSize: 28,
            ),
            const SizedBox(width: 12),
            // Recording indicator and timer
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatDuration(_recordDuration),
                    style: const TextStyle(
                      fontFamily: 'YekanBakh',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    ' / ${_formatDuration(widget.maxDurationSeconds)}',
                    style: TextStyle(
                      fontFamily: 'YekanBakh',
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Stop and send button
            Material(
              color: widget.primaryColor,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: _stopRecording,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Voice Player Widget for playing voice messages
class VoicePlayerWidget extends StatefulWidget {
  final String url;
  final bool isMe;
  final Color primaryColor;

  const VoicePlayerWidget({
    Key? key,
    required this.url,
    required this.isMe,
    required this.primaryColor,
  }) : super(key: key);

  @override
  State<VoicePlayerWidget> createState() => _VoicePlayerWidgetState();
}

class _VoicePlayerWidgetState extends State<VoicePlayerWidget> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      await _player.setSourceUrl(widget.url);

      _player.onDurationChanged.listen((duration) {
        if (mounted) {
          setState(() {
            _duration = duration;
            _isLoading = false;
          });
        }
      });

      _player.onPositionChanged.listen((position) {
        if (mounted) {
          setState(() {
            _position = position;
          });
        }
      });

      _player.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
        }
      });

      _player.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
          });
        }
      });
    } catch (e) {
      print('Error initializing player: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isMe ? Colors.white.withOpacity(0.2) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          _isLoading
              ? SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.isMe ? Colors.white : widget.primaryColor,
                    ),
                  ),
                )
              : InkWell(
                  onTap: _togglePlayPause,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isMe
                          ? Colors.white.withOpacity(0.3)
                          : widget.primaryColor.withOpacity(0.1),
                    ),
                    child: Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: widget.isMe ? Colors.white : widget.primaryColor,
                      size: 24,
                    ),
                  ),
                ),
          const SizedBox(width: 10),
          // Progress bar and time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: widget.isMe
                        ? Colors.white.withOpacity(0.3)
                        : Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.isMe ? Colors.white : widget.primaryColor,
                    ),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 4),
                // Time display
                Text(
                  '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                  style: TextStyle(
                    fontFamily: 'YekanBakh',
                    fontSize: 11,
                    color: widget.isMe ? Colors.white70 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
