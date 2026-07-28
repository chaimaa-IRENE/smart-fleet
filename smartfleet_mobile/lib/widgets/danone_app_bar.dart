import 'package:flutter/material.dart';
import '../config/theme.dart';

class DanoneAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showLogo;
  final PreferredSizeWidget? bottom;

  const DanoneAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showLogo = true,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: leading != null,
      leading: leading,
      title: Row(
        children: [
          if (showLogo) ...[
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'D',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: actions,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
}
