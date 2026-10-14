import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/grievance_model.dart';
import '../../theme/app_theme.dart';

enum AttachmentKind {
  audio,
  image,
  pdf,
  document,
}

AttachmentKind getAttachmentKind(String filename, String? mimeType) {
  final ext = filename.split('.').last.toLowerCase();
  final mime = mimeType?.toLowerCase() ?? '';

  if (['m4a', 'mp3', 'wav', 'aac', 'ogg', 'weba', 'flac'].contains(ext) ||
      mime.startsWith('audio/')) {
    return AttachmentKind.audio;
  }
  if (['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'].contains(ext) ||
      mime.startsWith('image/')) {
    return AttachmentKind.image;
  }
  if (ext == 'pdf' || mime == 'application/pdf') {
    return AttachmentKind.pdf;
  }
  return AttachmentKind.document;
}

/// Helper function to show attachment preview dialog across the entire application
void showAttachmentPreviewModal(
  BuildContext context, {
  required String fileUrl,
  required GrievanceAttachmentModel attachment,
}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AttachmentPreviewDialog(
      fileUrl: fileUrl,
      attachment: attachment,
    ),
  );
}

class AttachmentPreviewDialog extends StatelessWidget {
  final String fileUrl;
  final GrievanceAttachmentModel attachment;

  const AttachmentPreviewDialog({
    super.key,
    required this.fileUrl,
    required this.attachment,
  });

  @override
  Widget build(BuildContext context) {
    final kind = getAttachmentKind(attachment.originalFilename, attachment.mimeType);
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width > 640 ? 560.0 : screenSize.width * 0.94;
    final dialogHeight = screenSize.height * 0.82;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            _buildHeader(context, kind),
            const Divider(height: 1),
            Expanded(
              child: _buildBody(context, kind),
            ),
            const Divider(height: 1),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AttachmentKind kind) {
    IconData icon;
    Color iconColor;
    String typeLabel;

    switch (kind) {
      case AttachmentKind.audio:
        icon = Icons.mic_rounded;
        iconColor = const Color(0xFF7C3AED);
        typeLabel = 'Voice Petition Recording';
        break;
      case AttachmentKind.image:
        icon = Icons.image_rounded;
        iconColor = AppTheme.primaryBlue;
        typeLabel = 'Original Image Document';
        break;
      case AttachmentKind.pdf:
        icon = Icons.picture_as_pdf_rounded;
        iconColor = Colors.red.shade700;
        typeLabel = 'Official PDF Document';
        break;
      case AttachmentKind.document:
        icon = Icons.insert_drive_file_rounded;
        iconColor = AppTheme.secondaryTeal;
        typeLabel = 'Attached Document';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey.shade900
          : const Color(0xFFF8FAFC),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: iconColor,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  attachment.originalFilename.isNotEmpty
                      ? attachment.originalFilename
                      : 'Evidence File',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 22),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, AttachmentKind kind) {
    switch (kind) {
      case AttachmentKind.audio:
        return _AudioPreviewContent(
          fileUrl: fileUrl,
          attachment: attachment,
        );
      case AttachmentKind.image:
        return _ImagePreviewContent(
          fileUrl: fileUrl,
          attachment: attachment,
        );
      case AttachmentKind.pdf:
      case AttachmentKind.document:
        return _DocumentPreviewContent(
          fileUrl: fileUrl,
          attachment: attachment,
        );
    }
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (attachment.rawExtractedText != null &&
              attachment.rawExtractedText!.isNotEmpty)
            Text(
              'Extracted (${attachment.rawExtractedText!.length} chars)',
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            )
          else
            const SizedBox.shrink(),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

/// Rich Audio Player and Transcription viewer for Voice Petitions
/// Uses local device caching and DeviceFileSource to guarantee 100% reliable Android playback
class _AudioPreviewContent extends StatefulWidget {
  final String fileUrl;
  final GrievanceAttachmentModel attachment;

  const _AudioPreviewContent({
    required this.fileUrl,
    required this.attachment,
  });

  @override
  State<_AudioPreviewContent> createState() => _AudioPreviewContentState();
}

class _AudioPreviewContentState extends State<_AudioPreviewContent> {
  late final AudioPlayer _player;
  PlayerState _state = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackSpeed = 1.0;
  bool _isLoading = true;
  String? _localAudioPath;
  String? _errorMessage;

  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _completeSubscription;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initAudioListeners();
    _prepareAudioSource();
  }

  void _initAudioListeners() {
    _playerStateSubscription = _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _state = state;
          if (state == PlayerState.playing) _isLoading = false;
        });
      }
    });

    _durationSubscription = _player.onDurationChanged.listen((d) {
      if (mounted) {
        setState(() {
          _duration = d;
        });
      }
    });

    _positionSubscription = _player.onPositionChanged.listen((p) {
      if (mounted) {
        setState(() {
          _position = p;
        });
      }
    });

    _completeSubscription = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _position = Duration.zero;
          _state = PlayerState.completed;
        });
      }
    });
  }

  /// Downloads and caches the audio file locally to guarantee native Android playback without HTTP 206 range stream errors
  Future<void> _prepareAudioSource() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tempDir = await getTemporaryDirectory();

      // Check if file was recorded on this device directly
      final directFile = File('${tempDir.path}/${widget.attachment.originalFilename}');
      if (await directFile.exists() && await directFile.length() > 0) {
        _localAudioPath = directFile.path;
        await _player.setSource(DeviceFileSource(_localAudioPath!));
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // Check cached copy
      final safeName = widget.attachment.originalFilename.isNotEmpty
          ? widget.attachment.originalFilename
          : 'voice_${widget.attachment.id}.m4a';
      final cachedFile = File('${tempDir.path}/cached_${widget.attachment.id}_$safeName');
      if (await cachedFile.exists() && await cachedFile.length() > 0) {
        _localAudioPath = cachedFile.path;
        await _player.setSource(DeviceFileSource(_localAudioPath!));
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // Download from server to local cache
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ));

      await dio.download(widget.fileUrl, cachedFile.path);

      if (await cachedFile.exists() && await cachedFile.length() > 0) {
        _localAudioPath = cachedFile.path;
        await _player.setSource(DeviceFileSource(_localAudioPath!));
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Downloaded audio file is empty.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Notice: Audio stream is unavailable on device. The full transcribed petition is available below.';
        });
      }
    }
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _completeSubscription?.cancel();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_state == PlayerState.playing) {
        await _player.pause();
      } else {
        if (_localAudioPath != null && await File(_localAudioPath!).exists()) {
          await _player.setPlaybackRate(_playbackSpeed);
          await _player.play(DeviceFileSource(_localAudioPath!));
        } else {
          await _player.setPlaybackRate(_playbackSpeed);
          await _player.play(UrlSource(widget.fileUrl));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Playback note: $e';
        });
      }
    }
  }

  Future<void> _seek(double valueMs) async {
    final target = Duration(milliseconds: valueMs.toInt());
    await _player.seek(target);
  }

  Future<void> _cycleSpeed() async {
    final speeds = [1.0, 1.25, 1.5, 2.0];
    final currentIndex = speeds.indexOf(_playbackSpeed);
    final nextSpeed = speeds[(currentIndex + 1) % speeds.length];
    setState(() {
      _playbackSpeed = nextSpeed;
    });
    if (_state == PlayerState.playing) {
      await _player.setPlaybackRate(nextSpeed);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _state == PlayerState.playing;
    final maxMs = _duration.inMilliseconds.toDouble() > 0
        ? _duration.inMilliseconds.toDouble()
        : 1.0;
    final currentMs = _position.inMilliseconds
        .clamp(0, maxMs.toInt())
        .toDouble();
    final transcript = widget.attachment.rawExtractedText ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Audio Player Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF7C3AED).withValues(alpha: 0.12),
                  const Color(0xFF4F46E5).withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.graphic_eq_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Voice Petition Audio Player',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.attachment.originalFilename,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _cycleSpeed,
                      child: Text(
                        '${_playbackSpeed}x',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Slider
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: const Color(0xFF7C3AED),
                    thumbColor: const Color(0xFF7C3AED),
                    inactiveTrackColor: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: currentMs,
                    min: 0.0,
                    max: maxMs,
                    onChanged: (val) {
                      _seek(val);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Play / Pause Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.replay_10_rounded),
                      iconSize: 26,
                      tooltip: 'Replay 10s',
                      onPressed: () {
                        final newPos = _position - const Duration(seconds: 10);
                        _seek((newPos.inMilliseconds < 0 ? 0 : newPos.inMilliseconds).toDouble());
                      },
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(14),
                        elevation: 4,
                      ),
                      onPressed: _isLoading ? null : _togglePlayPause,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 28,
                            ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.forward_10_rounded),
                      iconSize: 26,
                      tooltip: 'Forward 10s',
                      onPressed: () {
                        final newPos = _position + const Duration(seconds: 10);
                        _seek((newPos.inMilliseconds > _duration.inMilliseconds
                                ? _duration.inMilliseconds
                                : newPos.inMilliseconds)
                            .toDouble());
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.amber.shade900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),

          // Speech-to-Text Transcript Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.translate_rounded, color: AppTheme.primaryBlue, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Extracted Voice Transcript',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (transcript.isNotEmpty)
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: transcript));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Voice transcript copied to clipboard!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Row(
                      children: [
                        Icon(Icons.copy_rounded, size: 14, color: AppTheme.primaryBlue),
                        SizedBox(width: 4),
                        Text(
                          'Copy Transcript',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: transcript.isNotEmpty
                ? SelectableText(
                    transcript,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      fontFamily: 'Roboto',
                    ),
                  )
                : const Text(
                    'Voice transcription completed without text output.',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Image viewer with explicit bounded viewport, pan, zoom, and fallback controls
class _ImagePreviewContent extends StatefulWidget {
  final String fileUrl;
  final GrievanceAttachmentModel attachment;

  const _ImagePreviewContent({
    required this.fileUrl,
    required this.attachment,
  });

  @override
  State<_ImagePreviewContent> createState() => _ImagePreviewContentState();
}

class _ImagePreviewContentState extends State<_ImagePreviewContent> {
  final TransformationController _transformController = TransformationController();
  File? _localFile;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkLocalOrDownload();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _checkLocalOrDownload() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tempDir = await getTemporaryDirectory();

      // Check if image was recently captured on this device directly
      final directFile = File('${tempDir.path}/${widget.attachment.originalFilename}');
      if (await directFile.exists() && await directFile.length() > 0) {
        if (mounted) {
          setState(() {
            _localFile = directFile;
            _isLoading = false;
          });
        }
        return;
      }

      final safeName = widget.attachment.originalFilename.isNotEmpty
          ? widget.attachment.originalFilename
          : 'image_${widget.attachment.id}.jpg';
      final cachedFile = File('${tempDir.path}/cached_img_${widget.attachment.id}_$safeName');
      if (await cachedFile.exists() && await cachedFile.length() > 0) {
        if (mounted) {
          setState(() {
            _localFile = cachedFile;
            _isLoading = false;
          });
        }
        return;
      }

      // Download image with Dio for resilience
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ));
      await dio.download(widget.fileUrl, cachedFile.path);

      if (await cachedFile.exists() && await cachedFile.length() > 0) {
        if (mounted) {
          setState(() {
            _localFile = cachedFile;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // Fallback to Image.network directly
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _zoomIn() {
    final matrix = _transformController.value.clone();
    matrix.multiply(Matrix4.diagonal3Values(1.25, 1.25, 1.0));
    _transformController.value = matrix;
  }

  void _zoomOut() {
    final matrix = _transformController.value.clone();
    matrix.multiply(Matrix4.diagonal3Values(0.8, 0.8, 1.0));
    _transformController.value = matrix;
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _transformController,
              panEnabled: true,
              minScale: 0.5,
              maxScale: 5.0,
              child: Center(
                child: _buildImageWidget(),
              ),
            ),
          ),
          if (_isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
          // Floating toolbar
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                    tooltip: 'Zoom In',
                    visualDensity: VisualDensity.compact,
                    onPressed: _zoomIn,
                  ),
                  IconButton(
                    icon: const Icon(Icons.zoom_out, color: Colors.white, size: 20),
                    tooltip: 'Zoom Out',
                    visualDensity: VisualDensity.compact,
                    onPressed: _zoomOut,
                  ),
                  IconButton(
                    icon: const Icon(Icons.restart_alt_rounded, color: Colors.white, size: 20),
                    tooltip: 'Reset View',
                    visualDensity: VisualDensity.compact,
                    onPressed: _resetZoom,
                  ),
                ],
              ),
            ),
          ),
          if (widget.attachment.rawExtractedText != null &&
              widget.attachment.rawExtractedText!.isNotEmpty)
            Positioned(
              bottom: 12,
              left: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.document_scanner_rounded, color: AppTheme.secondaryTeal, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.attachment.rawExtractedText!.length > 60
                            ? '${widget.attachment.rawExtractedText!.substring(0, 60)}...'
                            : widget.attachment.rawExtractedText!,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: widget.attachment.rawExtractedText!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Document OCR text copied to clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Text(
                          'Copy OCR',
                          style: TextStyle(
                            color: AppTheme.secondaryTeal,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageWidget() {
    if (_localFile != null) {
      return Image.file(
        _localFile!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildNetworkFallback(),
      );
    }
    return _buildNetworkFallback();
  }

  Widget _buildNetworkFallback() {
    return Image.network(
      widget.fileUrl,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_outlined, size: 48, color: Colors.white70),
              const SizedBox(height: 10),
              Text(
                _errorMessage != null
                    ? 'Unable to display image: $_errorMessage'
                    : 'Original image document (${widget.attachment.originalFilename}) is stored securely on the server.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry Loading Image', style: TextStyle(fontSize: 12)),
                onPressed: _checkLocalOrDownload,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Document & PDF extracted text & metadata reader
class _DocumentPreviewContent extends StatelessWidget {
  final String fileUrl;
  final GrievanceAttachmentModel attachment;

  const _DocumentPreviewContent({
    required this.fileUrl,
    required this.attachment,
  });

  @override
  Widget build(BuildContext context) {
    final text = attachment.rawExtractedText ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attachment.originalFilename,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Status: ${attachment.extractionStatus.toUpperCase()}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Document Extracted Text:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              if (text.isNotEmpty)
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Document text copied to clipboard!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Row(
                      children: [
                        Icon(Icons.copy_rounded, size: 14, color: AppTheme.primaryBlue),
                        SizedBox(width: 4),
                        Text(
                          'Copy',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: text.isNotEmpty
                ? SelectableText(
                    text,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  )
                : const Text(
                    'No extracted text content available.',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
          ),
        ],
      ),
    );
  }
}
