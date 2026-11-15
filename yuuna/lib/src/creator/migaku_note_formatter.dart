import 'package:kana_kit/kana_kit.dart';
import 'package:mecab_dart/mecab_dart.dart';
import 'package:ve_dart/ve_dart.dart';
import 'package:yuuna/creator.dart';

/// Writes notes in the format of Migaku's "Migaku Japanese Targeted
/// Sentence" note type, so cards exported for Anki join an existing Migaku
/// deck and look like the cards made with Migaku.
///
/// Migaku keeps furigana inline: words are separated by spaces, a word with
/// kanji is written as `食[た]べる`, the target word is wrapped in
/// `<strong>`, and punctuation is wrapped in braces, like `{。}`. Its pitch
/// accent codes (`食[た;k2]べる`) are optional and left out.
class MigakuNoteFormatter {
  MigakuNoteFormatter._();

  /// Fields of the Migaku Japanese Targeted Sentence note type.
  static const List<String> fields = [
    'Sentence',
    'Translation',
    'Target Word',
    'Definitions',
    'Screenshot',
    'Sentence Audio',
    'Word Audio',
    'Images',
    'Example Sentences',
    'Is Vocabulary Card',
    'Is Audio Card',
  ];

  static const KanaKit _kanaKit = KanaKit();

  /// Mecab's IPADIC feature holding a token's reading in katakana.
  static const int _readingFeature = 7;

  /// The plain sentence of a note queued with
  /// [AnkiPackageExporter.standardFields], for translating.
  static String plainSentence(List<String> standardFields) {
    String inside = _field(standardFields, 'Cloze Inside');
    if (inside.isEmpty) {
      return _field(standardFields, 'Sentence');
    }
    return _field(standardFields, 'Cloze Before') +
        inside +
        _field(standardFields, 'Cloze After');
  }

  /// Migaku field values, in the order of [fields], for a note queued with
  /// [AnkiPackageExporter.standardFields].
  static List<String> format({
    required List<String> standardFields,
    required Mecab mecab,
    String translation = '',
  }) {
    String term = _field(standardFields, 'Term');
    String reading = _field(standardFields, 'Reading');

    Map<String, String> values = {
      'Sentence': formatSentence(
        mecab: mecab,
        sentence: _field(standardFields, 'Sentence'),
        before: _field(standardFields, 'Cloze Before'),
        inside: _field(standardFields, 'Cloze Inside'),
        after: _field(standardFields, 'Cloze After'),
      ),
      'Translation': translation,
      'Target Word': term.isEmpty ? '' : formatWord(term, reading),
      'Definitions': formatDefinitions(
        term: term,
        reading: reading,
        meaning: _field(standardFields, 'Meaning'),
      ),
      'Screenshot': _image(_field(standardFields, 'Image')),
      'Sentence Audio': _sound(_field(standardFields, 'Sentence Audio')),
      'Word Audio': _sound(_field(standardFields, 'Term Audio')),
    };

    return fields.map((field) => values[field] ?? '').toList();
  }

  static String _field(List<String> standardFields, String name) {
    int index = AnkiPackageExporter.standardFields.indexOf(name);
    return index < standardFields.length ? standardFields[index].trim() : '';
  }

  /// The sentence with furigana, the target word ([inside], between
  /// [before] and [after]) in bold. Without a target, [sentence] is used.
  static String formatSentence({
    required Mecab mecab,
    required String sentence,
    required String before,
    required String inside,
    required String after,
  }) {
    if (inside.isEmpty) {
      return _formatWords(mecab, sentence);
    }

    /// Migaku puts no spaces around the bold target word.
    return '${_formatWords(mecab, before)}'
        '<strong>${_formatWords(mecab, inside)}</strong>'
        '${_formatWords(mecab, after)}';
  }

  static String _formatWords(Mecab mecab, String text) {
    String singleLine = text.replaceAll(RegExp(r'\s+'), '');
    if (singleLine.isEmpty) {
      return '';
    }

    List<String> words = [];
    for (Word word in parseVe(mecab, singleLine)) {
      StringBuffer surface = StringBuffer();
      StringBuffer reading = StringBuffer();
      for (TokenNode token in word.tokens) {
        surface.write(token.surface);
        String tokenReading = token.features.length > _readingFeature
            ? token.features[_readingFeature]
            : '*';
        reading.write(tokenReading == '*' ? token.surface : tokenReading);
      }

      String text = surface.toString();
      if (_punctuation.hasMatch(text)) {
        words.add('{$text}');
      } else {
        words.add(formatWord(text, _kanaKit.toHiragana(reading.toString())));
      }
    }

    /// Punctuation attaches to the word before it, and a run of it shares
    /// one pair of braces.
    return words.join(' ').replaceAll(' {', '{').replaceAll('}{', '');
  }

  static final RegExp _punctuation = RegExp(r'^[\p{P}\p{S}]+$', unicode: true);

  /// A word in Migaku's furigana format: the kanji part with its reading in
  /// brackets, followed by any trailing kana, like `食[た]べる`. Words
  /// without kanji are left as they are.
  static String formatWord(String word, String reading) {
    if (!word.split('').any(_kanaKit.isKanji) || reading.isEmpty) {
      return word;
    }

    String hiraganaReading = _kanaKit.toHiragana(reading);

    int suffix = 0;
    while (suffix < word.length - 1 && suffix < hiraganaReading.length - 1) {
      String character = word[word.length - 1 - suffix];
      if (_kanaKit.isKanji(character) ||
          _kanaKit.toHiragana(character) !=
              hiraganaReading[hiraganaReading.length - 1 - suffix]) {
        break;
      }
      suffix++;
    }

    String base = word.substring(0, word.length - suffix);
    String baseReading =
        hiraganaReading.substring(0, hiraganaReading.length - suffix);
    String okurigana = word.substring(word.length - suffix);

    return '$base[$baseReading]$okurigana';
  }

  /// Definitions as Migaku writes them: the term and its reading, then one
  /// paragraph per sense with its glosses joined by semicolons.
  ///
  /// In the Meaning field, senses are separated by blank lines and glosses
  /// start with a bullet. Dictionary name headers (`【JMdict】`) and example
  /// sentences (lines starting with `▪`) are left out.
  static String formatDefinitions({
    required String term,
    required String reading,
    required String meaning,
  }) {
    if (term.isEmpty && meaning.isEmpty) {
      return '';
    }

    StringBuffer buffer = StringBuffer('<p>${_escape(term)}');
    if (reading.isNotEmpty && reading != term) {
      buffer.write(' (${_escape(reading)})');
    }
    buffer.write('</p>');

    String text = meaning.replaceAll(RegExp(r'<br\s*/?>'), '\n');
    for (String sense in text.split(RegExp(r'\n\s*\n'))) {
      List<String> glosses = [];
      for (String line in sense.split('\n')) {
        String trimmed = line.trim();
        if (trimmed.isEmpty ||
            trimmed.startsWith('▪') ||
            RegExp(r'^【.*】$').hasMatch(trimmed)) {
          continue;
        }
        glosses.add(trimmed.replaceFirst(RegExp(r'^[•∙◦・]\s*'), ''));
      }

      if (glosses.isNotEmpty) {
        buffer.write('<p>∙ ${_escape(glosses.join('; '))}</p>');
      }
    }

    return buffer.toString();
  }

  static String _escape(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  static String _image(String value) {
    if (value.isEmpty || value.startsWith('<img')) {
      return value;
    }
    return '<img src="$value">';
  }

  static String _sound(String value) {
    if (value.isEmpty || value.startsWith('[sound:')) {
      return value;
    }
    return '[sound:$value]';
  }
}
