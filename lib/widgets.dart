import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';

String p2(int n) => n.toString().padLeft(2, '0');
String fmtDate(DateTime d) => '${d.year}-${p2(d.month)}-${p2(d.day)} ${p2(d.hour)}:${p2(d.minute)}';

class TxTile extends StatelessWidget {
  final Tx t;
  final VoidCallback? onDelete;
  const TxTile({super.key, required this.t, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = t.income ? Colors.green.shade700 : Colors.red.shade700;
    final sign = t.income ? '+' : '−';
    final title = (t.note.isEmpty ? t.cat : t.note) + (t.regret == true ? ' 😞' : '');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text('${t.cat} — ${fmtDate(t.at)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$sign${fm(t.amount)}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
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
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title!, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}
