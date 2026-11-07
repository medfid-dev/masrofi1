import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';

String p2(int n) => n.toString().padLeft(2, '0');
String fmtDate(DateTime d) => '${d.year}-${p2(d.month)}-${p2(d.day)} ${p2(d.hour)}:${p2(d.minute)}';

String catEmoji(String c) {
  const m = {
    'طعام': '🍽️', 'فواتير': '🧾', 'مواصلات': '🚌', 'ترفيه': '🎬', 'تسوق': '🛍️', 'صحة': '💊',
    'اشتراكات': '🔁', 'راتب': '💼', 'عمل حر': '💻', 'هدية': '🎁', 'أخرى': '📌',
  };
  return m[c] ?? '📌';
}

class TxTile extends StatelessWidget {
  final Tx t;
  final VoidCallback? onDelete;
  const TxTile({super.key, required this.t, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = t.income ? Colors.green.shade700 : Colors.red.shade700;
    final sign = t.income ? '+' : '−';
    final title = (t.note.isEmpty ? t.cat : t.note) + (t.regret == true ? ' 😞' : '');
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(.12),
        child: Text(catEmoji(t.cat), style: const TextStyle(fontSize: 18)),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${t.cat} • ${fmtDate(t.at)}', style: TextStyle(color: cs.outline, fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$sign${fm(t.amount)}', style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          if (onDelete != null)
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'حذف', onPressed: onDelete),
        ],
      ),
    );
  }
}

class Sheet extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  const Sheet({super.key, this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title!, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}
