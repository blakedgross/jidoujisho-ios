import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spaces/spaces.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// Shows the answer of [SentenceAssistant] for a sentence as it streams in.
class SentenceAssistantDialogPage extends BasePage {
  /// Create the dialog for [task] on [sentence], with [sentenceContext]
  /// being text around it.
  const SentenceAssistantDialogPage({
    required this.task,
    required this.sentence,
    this.sentenceContext,
    super.key,
  });

  /// What to do with the sentence.
  final SentenceAssistantTask task;

  /// The sentence to translate or break down.
  final String sentence;

  /// Text around [sentence], for context.
  final String? sentenceContext;

  @override
  BasePageState createState() => _SentenceAssistantDialogPageState();
}

class _SentenceAssistantDialogPageState
    extends BasePageState<SentenceAssistantDialogPage> {
  late final Stream<String> _answer = SentenceAssistant.run(
    task: widget.task,
    sentence: widget.sentence,
    context: widget.sentenceContext,
    language: appModel.targetLanguage,
  );

  final ScrollController _scrollController = ScrollController();
  String _latestAnswer = '';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String get title => switch (widget.task) {
        SentenceAssistantTask.translate => t.sentence_translate,
        SentenceAssistantTask.breakDown => t.sentence_break_down,
      };

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.sizeOf(context);

    return AlertDialog(
      title: Text(title),
      contentPadding: Spacing.of(context).insets.exceptBottom.big,
      actionsPadding: Spacing.of(context).insets.all.normal,
      content: SizedBox(
        width: min(size.width * 0.8, 640),
        child: StreamBuilder<String>(
          stream: _answer,
          builder: (context, snapshot) {
            _latestAnswer = snapshot.data ?? '';
            bool done = snapshot.connectionState == ConnectionState.done;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectableText(
                  widget.sentence,
                  style: textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Space.normal(),
                if (!done)
                  LinearProgressIndicator(
                    minHeight: 2,
                    color: theme.colorScheme.primary,
                    backgroundColor: Colors.transparent,
                  )
                else
                  const SizedBox(height: 2),
                const Space.normal(),
                Flexible(
                  child: Scrollbar(
                    controller: _scrollController,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: buildAnswer(snapshot),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (_latestAnswer.isNotEmpty) {
              Clipboard.setData(ClipboardData(text: _latestAnswer));
            }
          },
          child: Text(t.dialog_copy),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.dialog_close),
        ),
      ],
    );
  }

  Widget buildAnswer(AsyncSnapshot<String> snapshot) {
    if (snapshot.hasError) {
      return SelectableText(
        snapshot.error.toString(),
        style: textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
      );
    }

    return SelectableText(
      snapshot.data ?? '',
      style: textTheme.bodyLarge,
    );
  }
}
