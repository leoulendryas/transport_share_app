import 'package:flutter/material.dart';
import '../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String senderEmail; // Added sender email as a parameter

  const MessageBubble({
    super.key, 
    required this.message, 
    required this.isMe,
    required this.senderEmail, // Make it required
  });

  @override
  Widget build(BuildContext context) {
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
                color: isMe ? colors.primaryContainer : colors.surfaceContainerHighest, // Updated deprecated property
                borderRadius: _getBorderRadius(),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe) _buildSenderInfo(theme, colors),
                    _buildMessageContent(theme, colors),
                    _buildMessageFooter(theme, colors),
                    if (message.type == 'sos') _buildSosIndicator(theme, colors), // Using type instead of isSos
                    if (message.type == 'image') _buildImagePreview(), // Using type instead of isImage
                  ],
                ),
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
        senderEmail, // Using the passed email instead of message.email
        style: theme.textTheme.labelLarge?.copyWith(
          color: colors.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMessageContent(ThemeData theme, ColorScheme colors) {
    return Text(
      message.content,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: colors.onSurface,
      ),
    );
  }

  Widget _buildMessageFooter(ThemeData theme, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        _formatTime(message.timestamp), // Using a local formatting function
        style: theme.textTheme.labelSmall?.copyWith(
          color: Color.lerp(colors.onSurface, colors.surface, 0.4), // Replacing withOpacity
        ),
      ),
    );
  }

  Widget _buildSosIndicator(ThemeData theme, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(Icons.warning, color: colors.error, size: 16),
          const SizedBox(width: 4),
          Text(
            'SOS Alert',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          message.content,
          width: 200,
          height: 150,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              width: 200,
              height: 150,
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / 
                        loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => Container(
            width: 200,
            height: 150,
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image),
          ),
        ),
      ),
    );
  }

  // Helper function to format time
  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}