import 'package:flutter/material.dart';
import '../../../config/theme.dart';

class ConversationBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final String time;

  const ConversationBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.time = '',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.assistant, size: 16, color: AppTheme.primary),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.primary : AppTheme.surface,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomRight: isUser ? const Radius.circular(4) : null,
                  bottomLeft: !isUser ? const Radius.circular(4) : null,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isUser ? AppTheme.primary : Colors.black12)
                        .withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      color: isUser ? Colors.white : AppTheme.textPrimary,
                      fontSize: 15,
                      height: 1.4,
                    ),
                    textDirection: _isArabic(text)
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                  ),
                  if (time.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        time,
                        style: TextStyle(
                          fontSize: 11,
                          color: isUser
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isUser)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.person, size: 16, color: AppTheme.primary),
            ),
        ],
      ),
    );
  }

  bool _isArabic(String text) {
    return text.contains(RegExp(r'[\u0600-\u06FF]'));
  }
}
