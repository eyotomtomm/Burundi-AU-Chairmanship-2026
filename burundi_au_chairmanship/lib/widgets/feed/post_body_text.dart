import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_ds.dart';

/// Post text with #hashtags and links picked out.
///
/// Links always open in the system browser, never in-app: the app never
/// renders someone else's page inside its own chrome.
class PostBodyText extends StatefulWidget {
  final String text;
  final double fontSize;
  final int? maxLines;
  final void Function(String tag)? onTagTap;

  const PostBodyText(
    this.text, {
    super.key,
    this.fontSize = 14,
    this.maxLines,
    this.onTagTap,
  });

  @override
  State<PostBodyText> createState() => _PostBodyTextState();
}

class _PostBodyTextState extends State<PostBodyText> {
  /// Recognizers live as long as the text does. Building them inside `build`
  /// meant every rebuild — a like landing, a scroll — disposed the recognizer
  /// the finger was already on, so the tap went nowhere.
  final _recognizers = <TapGestureRecognizer>[];
  late List<_Token> _tokens;

  // Hashtags, and bare or schemed URLs.
  static final _pattern = RegExp(
    r'(#[\wÀ-ɏ]+)|((?:https?://|www\.)[^\s<>"]+)',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    _buildTokens();
  }

  @override
  void didUpdateWidget(covariant PostBodyText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _disposeRecognizers();
      _buildTokens();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  void _buildTokens() {
    _tokens = [];
    var index = 0;
    for (final m in _pattern.allMatches(widget.text)) {
      if (m.start > index) {
        _tokens.add(_Token(widget.text.substring(index, m.start), null));
      }
      final token = m.group(0)!;
      final isTag = token.startsWith('#');
      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          if (!mounted) return;
          if (isTag) {
            widget.onTagTap?.call(token.substring(1));
          } else {
            _openLink(token);
          }
        };
      _recognizers.add(recognizer);
      _tokens.add(_Token(token, recognizer));
      index = m.end;
    }
    if (index < widget.text.length) {
      _tokens.add(_Token(widget.text.substring(index), null));
    }
  }

  Future<void> _openLink(String raw) async {
    final normalised = raw.startsWith('http') ? raw : 'https://$raw';
    final uri = Uri.tryParse(normalised);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return;
    if (!mounted) return;

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leaving the app'),
        content: Text('This link opens in your browser.\n\n${uri.host}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Open')),
        ],
      ),
    );
    if (go != true) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
        fontSize: widget.fontSize, height: 1.45, color: Ds.ink(context));
    final accent =
        base.copyWith(color: Ds.greenDeep, fontWeight: FontWeight.w700);

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          for (final t in _tokens)
            TextSpan(
              text: t.text,
              style: t.recognizer == null ? null : accent,
              recognizer: t.recognizer,
            ),
        ],
      ),
      maxLines: widget.maxLines,
      overflow:
          widget.maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
    );
  }
}

class _Token {
  final String text;
  final TapGestureRecognizer? recognizer;
  const _Token(this.text, this.recognizer);
}
