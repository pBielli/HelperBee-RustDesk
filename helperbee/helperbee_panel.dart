// HelperBee panel inside the HelperBee - RustDesk client (added by branding/rustdesk/apply-branding.py).
// It talks to the local HelperBee agent API (127.0.0.1:47123, same data as the tray popup): connection,
// remote-desktop apps on this PC with their IDs, password policy, and the assistance request.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

const _api = 'http://127.0.0.1:47123';
const _hdr = {'X-HelperBee': 'tray'};
const hbRed = Color(0xFFEF443B);
const hbRedDeep = Color(0xFFB8322B);
const _names = {'anydesk': 'AnyDesk', 'rustdesk': 'RustDesk', 'teamviewer': 'TeamViewer', 'supremo': 'Supremo'};

Future<Map<String, dynamic>?> hbStatus() async {
  try {
    final r = await http.get(Uri.parse('$_api/status'), headers: _hdr).timeout(const Duration(seconds: 3));
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
  } catch (_) {}
  return null;
}

String _ago(dynamic ms) {
  if (ms is! num || ms == 0) return '—';
  final s = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms.toInt())).inSeconds;
  if (s < 60) return '${s}s';
  if (s < 3600) return '${s ~/ 60} min';
  if (s < 86400) return '${s ~/ 3600} h';
  return '${s ~/ 86400} g';
}

String _fmtId(String id) => id.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');

/// The HelperBee mark (Hive hexagon + hexagonal lifebuoy) drawn in code: no asset needed.
class HelperBeeMark extends StatelessWidget {
  final double size;
  const HelperBeeMark({super.key, this.size = 28});
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _MarkPainter(Theme.of(context).colorScheme.background));
}

class _MarkPainter extends CustomPainter {
  final Color inner;
  _MarkPainter(this.inner);
  Path _hex(double cx, double cy, double r) {
    final p = Path();
    for (var i = 0; i < 6; i++) {
      final a = (-90 + 60 * i) * 3.141592653589793 / 180;
      final x = cx + r * _cos(a), y = cy + r * _sin(a);
      i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
    }
    return p..close();
  }
  static double _cos(double a) => math.cos(a);
  static double _sin(double a) => math.sin(a);

  @override
  void paint(Canvas c, Size s) {
    final k = s.width / 64;
    c.scale(k);
    c.drawPath(_hex(32, 32, 30), Paint()..color = hbRed);
    c.drawPath(_hex(32, 32, 23), Paint()..color = inner);
    for (var i = 0; i < 6; i++) {
      final a1 = (-90 + 60 * i) * 3.141592653589793 / 180, a2 = (-90 + 60 * (i + 1)) * 3.141592653589793 / 180;
      final p = Path()
        ..moveTo(32 + 15.5 * _cos(a1), 32 + 15.5 * _sin(a1))
        ..lineTo(32 + 15.5 * _cos(a2), 32 + 15.5 * _sin(a2))
        ..lineTo(32 + 8 * _cos(a2), 32 + 8 * _sin(a2))
        ..lineTo(32 + 8 * _cos(a1), 32 + 8 * _sin(a1))
        ..close();
      c.drawPath(p, Paint()..color = i.isEven ? hbRedDeep : Colors.white);
    }
    final outline = Paint()
      ..color = hbRedDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    c.drawPath(_hex(32, 32, 15.5), outline);
    c.drawPath(_hex(32, 32, 8), outline);
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) => old.inner != inner;
}

/// Header of the left pane: mark + name + live status; click opens the panel.
class HelperBeeHeader extends StatefulWidget {
  const HelperBeeHeader({super.key});
  @override
  State<HelperBeeHeader> createState() => _HelperBeeHeaderState();
}

class _HelperBeeHeaderState extends State<HelperBeeHeader> {
  Map<String, dynamic>? st;
  Timer? t;
  @override
  void initState() {
    super.initState();
    _load();
    t = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  Future<void> _load() async {
    final s = await hbStatus();
    if (mounted) setState(() => st = s);
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = st?['connected'] == true;
    final pending = st?['info']?['pending_approval'] == true;
    final label = st == null ? 'Agent not running' : pending ? 'Waiting for approval' : ok ? 'Connected' : 'Server unreachable';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showHelperBeePanel(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 12, 8),
        child: Row(children: [
          const HelperBeeMark(size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('HelperBee', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Row(children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: st == null ? Colors.grey : pending ? Colors.orange : ok ? Colors.green : hbRed)),
                const SizedBox(width: 5),
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.grey))),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Floating button (bottom right of the main window).
class HelperBeeFab extends StatelessWidget {
  const HelperBeeFab({super.key});
  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
        backgroundColor: hbRed,
        foregroundColor: Colors.white,
        onPressed: () => showHelperBeePanel(context),
        icon: const Icon(Icons.support_agent),
        label: const Text('HelperBee'),
      );
}

void showHelperBeePanel(BuildContext context) {
  showDialog(context: context, builder: (_) => const Dialog(insetPadding: EdgeInsets.all(24), child: SizedBox(width: 460, child: _Panel())));
}

class _Panel extends StatefulWidget {
  const _Panel();
  @override
  State<_Panel> createState() => _PanelState();
}

class _PanelState extends State<_Panel> {
  Map<String, dynamic>? st;
  bool loading = true, sending = false;
  String? sent;
  final msg = TextEditingController();
  Timer? t;
  @override
  void initState() {
    super.initState();
    _load();
    t = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    t?.cancel();
    msg.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await hbStatus();
    if (mounted) setState(() { st = s; loading = false; });
  }

  Future<void> _send() async {
    setState(() { sending = true; sent = null; });
    try {
      final r = await http.post(Uri.parse('$_api/assist'), headers: {..._hdr, 'Content-Type': 'application/json'}, body: jsonEncode({'Message': msg.text.trim()})).timeout(const Duration(seconds: 15));
      sent = r.statusCode == 200 ? 'Request sent: a technician has been notified.' : 'Could not send: ${jsonDecode(r.body)['error'] ?? r.statusCode}';
      if (r.statusCode == 200) msg.clear();
    } catch (e) {
      sent = 'Could not send: the HelperBee agent is not running.';
    }
    if (mounted) setState(() => sending = false);
    _load();
  }

  Widget _row(String k, Widget v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 120, child: Text(k, style: const TextStyle(color: Colors.grey, fontSize: 13))), Expanded(child: v)]));

  @override
  Widget build(BuildContext context) {
    final s = st;
    final info = s?['info'] as Map<String, dynamic>?;
    final apps = ((s?['anydesk']?['apps']) as Map<String, dynamic>?) ?? {};
    final assist = info?['assist'] as Map<String, dynamic>?;
    final pwd = info?['password'] as Map<String, dynamic>?;
    final open = assist != null && assist['status'] == 'open';
    return Padding(
      padding: const EdgeInsets.all(22),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const HelperBeeMark(size: 40),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('HelperBee', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Text('assist · by pbielli', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ])),
            IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
          ]),
          const SizedBox(height: 14),
          if (loading) const LinearProgressIndicator(color: hbRed)
          else if (s == null)
            const Text('The HelperBee agent is not running on this PC. Restart the PC or contact your administrator.')
          else ...[
            if (info?['pending_approval'] == true)
              Container(
                width: double.infinity, margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(.15), borderRadius: BorderRadius.circular(10)),
                child: const Text('Waiting for approval: a technician must approve this PC.')),
            _row('Status', Text(s['connected'] == true ? 'Connected to ${Uri.tryParse(s['server'] ?? '')?.host ?? s['server']} · ${_ago(s['last_ok'])} ago' : 'Server unreachable${s['last_error'] != null ? ' (${s['last_error']})' : ''}')),
            if (info?['device_name'] != null) _row('This PC', Text('${info!['device_name']}')),
            _row('Agent', Text('${s['agent_version'] ?? '?'}')),
            _row('Password', Text(pwd == null || pwd['managed'] != true ? 'not managed' : pwd['pinned'] == true || pwd['rotating'] != true ? 'static · set ${_ago(pwd['set_at'])} ago' : 'rotating (${pwd['mode'] ?? ''}${pwd['time'] != null && pwd['time'] != '' ? ' ${pwd['time']}' : ''})')),
            const SizedBox(height: 8),
            const Text('Remote assistance apps on this PC', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            if (apps.values.every((a) => a['installed'] != true)) const Text('None', style: TextStyle(color: Colors.grey)),
            for (final e in apps.entries.where((e) => e.value['installed'] == true))
              _row(_names[e.key] ?? e.key, Row(children: [
                Expanded(child: SelectableText(e.value['id'] != null ? _fmtId('${e.value['id']}') : '—', style: const TextStyle(fontFamily: 'monospace', fontSize: 15))),
                if (e.value['id'] != null) IconButton(tooltip: 'Copy', iconSize: 16, onPressed: () => Clipboard.setData(ClipboardData(text: '${e.value['id']}')), icon: const Icon(Icons.copy)),
                Text('${e.value['version'] ?? ''}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ])),
            const Divider(height: 26),
            Text(open ? 'Assistance requested ${_ago(assist!['created_at'])} ago: a technician will contact you.' : 'Need help? Describe the problem and ask for assistance.',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (assist != null && (assist['reply'] ?? '') != '') Padding(padding: const EdgeInsets.only(top: 6), child: Text('Technician: ${assist['reply']}')),
            const SizedBox(height: 8),
            TextField(controller: msg, maxLines: 3, maxLength: 1000, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'What is the problem?')),
            Row(children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: hbRed, foregroundColor: Colors.white),
                onPressed: sending ? null : _send,
                icon: const Icon(Icons.support_agent),
                label: Text(open ? 'Send more details' : 'Request assistance'),
              ),
              const SizedBox(width: 12),
              if (sent != null) Expanded(child: Text(sent!, style: const TextStyle(fontSize: 12))),
            ]),
          ],
        ]),
      ),
    );
  }
}
