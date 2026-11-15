import 'package:yuuna/language.dart';
import 'package:yuuna/utils.dart';

/// What [SentenceAssistant] does with a sentence.
enum SentenceAssistantTask {
  /// Translate the sentence.
  translate,

  /// Explain the sentence word by word and its grammar.
  breakDown,
}

/// Translates and breaks down sentences from readers with [OpenAiChat], like
/// Migaku.
class SentenceAssistant {
  SentenceAssistant._();

  /// Stream the answer for [task] on [sentence], a sentence in [language].
  /// Each event is the whole answer so far. [context] is text around the
  /// sentence, such as the rest of its paragraph, used only to resolve
  /// ambiguity.
  static Stream<String> run({
    required SentenceAssistantTask task,
    required String sentence,
    required Language language,
    String? context,
  }) {
    return OpenAiChat.complete(
      messages: [
        {
          'role': 'system',
          'content': _instructions(task: task, language: language),
        },
        {
          'role': 'user',
          'content': _input(sentence: sentence, context: context),
        },
      ],
    );
  }

  static String _input({required String sentence, String? context}) {
    if (context == null || context.trim().isEmpty || context == sentence) {
      return sentence;
    }

    return 'Sentence: $sentence\n\nSurrounding text, for context only: $context';
  }

  static String _instructions({
    required SentenceAssistantTask task,
    required Language language,
  }) {
    /// Language names are in the language itself, such as 日本語.
    String name = const {
          'ja': 'Japanese',
          'en': 'English',
        }[language.languageCode] ??
        language.languageName;
    String readings = language.languageCode == 'ja'
        ? ' Give readings in hiragana after kanji, like 食べる (たべる).'
        : '';

    switch (task) {
      case SentenceAssistantTask.translate:
        return 'You translate $name into natural English for a language '
            'learner. The text may come from a manga speech bubble or a '
            'novel, and may contain OCR errors; read it as intended. Reply '
            'with only the translation.';
      case SentenceAssistantTask.breakDown:
        return 'You explain $name sentences to an English-speaking learner. '
            'The text may come from a manga speech bubble or a novel, and may '
            'contain OCR errors; read it as intended. Reply in plain text '
            'with no Markdown: no asterisks, hashes, tables or code. Use '
            'these sections, each title on its own line:\n'
            'Translation\n'
            'A natural English translation.\n'
            'Words\n'
            'One line per word or set phrase, in sentence order, starting '
            'with "• ": the word as written, its dictionary form if '
            'different, its part of speech and its meaning here.$readings\n'
            'Grammar\n'
            'One line per grammar point, starting with "• ": conjugations, '
            'particles and constructions, what each does in this sentence.\n'
            'Nuance\n'
            'Tone, register, slang or implied meaning, in a sentence or two. '
            'Leave this section out if there is nothing to add.';
    }
  }
}
