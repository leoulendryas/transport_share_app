import 'package:flutter/material.dart';
import '../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String senderEmail;

  const MessageBubble({
    super.key, 
    required this.message, 
    required this.isMe,
    required this.senderEmail,
  });

  @override
  Widget build(BuildContext context) {
    if (message.type == 'typing_start') {
      return _buildTypingIndicator(context);
    } else if (message.type == 'typing_end') {
      return const SizedBox.shrink();
    } else if (message.type == 'ping' || message.type == 'pong') {
      return const SizedBox.shrink();
    } else if (message.type == 'error') {
      return _buildErrorMessage(context);
    }

    return _buildRegularMessage(context);
  }

  Widget _buildRegularMessage(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isMe ? colors.primaryContainer : colors.surfaceContainerHighest,
                borderRadius: _getBorderRadius(),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe) _buildSenderInfo(theme, colors),
                    if (message.content != null && message.content!.isNotEmpty)
                      _buildMessageContent(theme, colors),
                    _buildMessageFooter(theme, colors),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('...'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              message.content ?? 'Error',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  BorderRadius _getBorderRadius() {
    return BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
      bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
    );
  }

  Widget _buildSenderInfo(ThemeData theme, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        senderEmail,
        style: theme.textTheme.labelLarge?.copyWith(
          color: colors.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMessageContent(ThemeData theme, ColorScheme colors) {
    return Text(
      message.content!,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: colors.onSurface,
      ),
    );
  }

  Widget _buildMessageFooter(ThemeData theme, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        _formatTime(message.timestamp),
        style: theme.textTheme.labelSmall?.copyWith(
          color: Color.lerp(colors.onSurface, colors.surface, 0.4),
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}