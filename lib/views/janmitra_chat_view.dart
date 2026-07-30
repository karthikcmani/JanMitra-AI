// ignore_for_file: deprecated_member_use, unnecessary_underscores
import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'citizen_views.dart';

class JanMitraChatView extends StatefulWidget {
  final Function(int tabIndex)? onNavigateTab;

  const JanMitraChatView({super.key, this.onNavigateTab});

  @override
  State<JanMitraChatView> createState() => _JanMitraChatViewState();
}

class _JanMitraChatViewState extends State<JanMitraChatView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    final messages = appState.chatMessages;

    return Column(
      children: [
        // AI Assistant Top Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
            border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  gradient: AppTheme.aiGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'JanMitra AI Assistant',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                    const SizedBox(height: 2),
                    const Row(
                      children: [
                        CircleAvatar(radius: 3, backgroundColor: AppTheme.successGreen),
                        SizedBox(width: 4),
                        Text(
                          'Online • Natural Language Grievance Bot',
                          style: TextStyle(fontSize: 10.5, color: AppTheme.successGreen, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Chat List
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              return _buildMessageBubble(msg, isDark, appState);
            },
          ),
        ),

        // Bottom Input Bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.mic_rounded, color: AppTheme.aiPurple),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Listening... Voice-to-Text activated (Hindi/English).'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Ask JanMitra AI or report a complaint...',
                    border: InputBorder.none,
                  ),
                  onSubmitted: (text) {
                    if (text.trim().isNotEmpty) {
                      appState.sendChatMessage(text);
                      _controller.clear();
                      _scrollToBottom();
                    }
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: AppTheme.primaryBlue),
                onPressed: () {
                  if (_controller.text.trim().isNotEmpty) {
                    appState.sendChatMessage(_controller.text);
                    _controller.clear();
                    _scrollToBottom();
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isDark, AppState appState) {
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14, right: 30),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                gradient: AppTheme.aiGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      border: Border.all(
                        color: AppTheme.aiPurple.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(color: textPrimary, fontSize: 13, height: 1.4),
                    ),
                  ),
                  if (msg.suggestedActions != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: msg.suggestedActions!.map((action) {
                        return ActionChip(
                          avatar: const Icon(Icons.auto_awesome, size: 12, color: AppTheme.aiPurple),
                          label: Text(action, style: const TextStyle(fontSize: 11)),
                          onPressed: () {
                            appState.sendChatMessage(action);
                            _scrollToBottom();
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
