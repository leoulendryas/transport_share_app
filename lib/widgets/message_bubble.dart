import 'package:flutter/material.dart';
import '../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const MessageBubble({
    super.key, 
    required this.message, 
    required this.isMe
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
              decoration: BoxDecoration(
                color: isMe
                    ? colors.primaryContainer
                    : colors.surfaceVariant,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMe 
                      ? const Radius.circular(16) 
                      : const Radius.circular(4),
                  bottomRight: isMe 
                      ? const Radius.circular(4) 
                      : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.userEmail ?? 'Unknown User',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Text(
                    message.content,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.formattedTime,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurface.withOpacity(0.6),
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
}