import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:yuuna/creator.dart';

/// A note waiting in the export queue of an [AnkiPackageExporter].
class PendingAnkiNote {
  /// Create a pending note.
  PendingAnkiNote({
    required this.guid,
    required this.deck,
    required this.fields,
    required this.tags,
    required this.createdMs,
  });

  /// Restore a pending note from [toJson] output.
  factory PendingAnkiNote.fromJson(Map<String, dynamic> json) {
    return PendingAnkiNote(
      guid: json['guid'] as String,
      deck: json['deck'] as String,
      fields: List<String>.from(json['fields'] as List),
      tags: List<String>.from(json['tags'] as List),
      createdMs: json['createdMs'] as int,
    );
  }

  /// Globally unique note id used by Anki to recognise re-imports.
  final String guid;

  /// Name of the deck the note's card goes into.
  final String deck;

  /// Field values, in the order of [AnkiPackageExporter.standardFields].
  final List<String> fields;

  /// Note tags.
  final List<String> tags;

  /// Creation time in milliseconds since epoch.
  final int createdMs;

  /// Serialise for the queue file.
  Map<String, dynamic> toJson() => {
        'guid': guid,
        'deck': deck,
        'fields': fields,
        'tags': tags,
        'createdMs': createdMs,
      };
}

/// A note type an [AnkiPackageExporter] can write notes as.
class AnkiNoteType {
  /// Define a note type with a single card template.
  const AnkiNoteType({
    required this.id,
    required this.name,
    required this.fields,
    required this.templateName,
    required this.frontTemplate,
    required this.backTemplate,
    required this.css,
    required this.requirements,
    this.modifiedSeconds,
  });

  /// Note type id. Anki imports notes into an existing note type with the
  /// same id and fields instead of creating a copy.
  final int id;

  /// Note type name.
  final String name;

  /// Field names, in order.
  final List<String> fields;

  /// Name of the card template.
  final String templateName;

  /// Front of the card template.
  final String frontTemplate;

  /// Back of the card template.
  final String backTemplate;

  /// Styling of the note type.
  final String css;

  /// Anki's `req`: the fields the card template needs to be generated.
  final List<dynamic> requirements;

  /// Fixed modification time in seconds, or null for the export time. Anki
  /// only replaces an existing note type's templates and styling with a
  /// newer one.
  final int? modifiedSeconds;

  /// The note type the Android build creates through the AnkiDroid API.
  static final AnkiNoteType standard = AnkiNoteType(
    id: AnkiPackageExporter.standardModelId,
    name: AnkiMapping.standardModelName,
    fields: AnkiPackageExporter.standardFields,
    templateName: AnkiMapping.standardModelName,
    frontTemplate: AnkiPackageExporter.standardFrontTemplate,
    backTemplate: AnkiPackageExporter.standardBackTemplate,
    css: AnkiPackageExporter.standardCss,
    requirements: [
      [
        0,
        'all',
        [0]
      ]
    ],
  );

  /// Migaku's "Migaku Japanese Targeted Sentence" note type, with the id and
  /// fields of the note type Migaku installs in Anki, so exported notes join
  /// the cards made with Migaku. See [MigakuNoteFormatter].
  ///
  /// The note type is dated to 1970 so Anki keeps Migaku's own templates
  /// and styling. The simple templates here only show where Migaku's note
  /// type is not installed.
  static const AnkiNoteType migakuJapaneseTargetedSentence = AnkiNoteType(
    id: 1687936123297,
    name: 'Migaku Japanese Targeted Sentence',
    fields: MigakuNoteFormatter.fields,
    templateName: 'Standard',
    frontTemplate: _migakuFrontTemplate,
    backTemplate: _migakuBackTemplate,
    css: _migakuCss,
    requirements: [
      [
        0,
        'any',
        [0, 2]
      ]
    ],
    modifiedSeconds: 1,
  );

  /// Renders Migaku's inline furigana, `食[た;k2]べる`, as ruby text.
  static const String _migakuFrontTemplate = '''
<div class="sentence">{{Sentence}}</div>
<script>
document.querySelectorAll('.sentence').forEach(function (element) {
  element.innerHTML = element.innerHTML
    .replace(/\\{([^}]*)\\}/g, '\$1')
    .replace(/([^ <>\\[\\]]+)\\[([^\\];]*)(;[^\\]]*)?\\]/g, function (match, base, reading) {
      return reading ? '<ruby>' + base + '<rt>' + reading + '</rt></ruby>' : base;
    })
    .replace(/ /g, '');
});
</script>''';

  static const String _migakuBackTemplate = '''
{{FrontSide}}
{{Sentence Audio}}
<hr>
<div class="translation">{{Translation}}</div>
<div class="screenshot">{{Screenshot}}</div>
<div class="definitions">{{Definitions}}</div>
{{Word Audio}}''';

  static const String _migakuCss = '''
.card {
  font-family: "Hiragino Sans", "Noto Sans JP", sans-serif;
  font-size: 20px;
  text-align: center;
}

.sentence {
  font-size: 26px;
}

.sentence strong {
  color: #2880ff;
}

.translation {
  color: #666666;
}

.screenshot img {
  max-width: 100%;
  max-height: 365px;
}

.definitions {
  text-align: left;
}''';
}

/// Exports cards as an Anki package (.apkg) for import into desktop Anki.
///
/// Used where AnkiDroid's content provider does not exist (iOS). Notes and
/// their media are queued on disk under [rootDirectory]; [buildPackage]
/// writes the queue as an .apkg containing an [AnkiNoteType], decks, notes,
/// cards and media.
class AnkiPackageExporter {
  /// Create an exporter persisting its queue in [rootDirectory].
  AnkiPackageExporter(this.rootDirectory) {
    _mediaDirectory.createSync(recursive: true);
  }

  /// Directory holding the queue, media and exported key history.
  final Directory rootDirectory;

  /// Fields of the standard note type, identical to the one the Android
  /// build creates through the AnkiDroid API.
  static const List<String> standardFields = [
    'Term',
    'Reading',
    'Furigana',
    'Sentence',
    'Cloze Before',
    'Cloze Inside',
    'Cloze After',
    'Meaning',
    'Expanded Meaning',
    'Collapsed Meaning',
    'Notes',
    'Context',
    'Frequency',
    'Pitch Accent',
    'Image',
    'Term Audio',
    'Sentence Audio',
  ];

  /// Tag added to every exported note, as the Android build does.
  static const String appTag = 'Yuuna';

  /// Fixed note type id so every package merges into the same note type.
  static const int standardModelId = 1694733914216;

  /// Front template of the standard note type.
  static const String standardFrontTemplate = '<div id="word">{{Term}}</div>';

  /// Back template of the standard note type.
  static const String standardBackTemplate = '''
<div id="word">{{#Furigana}}{{furigana:Furigana}}{{/Furigana}}{{^Furigana}}{{Term}}{{/Furigana}}</div>{{#Pitch Accent}}{{Pitch Accent}}{{/Pitch Accent}}
{{#Image}}<div class="image">{{Image}}</div>{{/Image}}
{{#Term Audio}}{{Term Audio}}{{/Term Audio}}{{#Sentence Audio}}{{Sentence Audio}}{{/Sentence Audio}}
<div id="sentence">{{#Cloze Inside}}{{Cloze Before}}<span class="cloze">{{Cloze Inside}}</span>{{Cloze After}}{{/Cloze Inside}}{{^Cloze Inside}}{{Sentence}}{{/Cloze Inside}}</div>
{{#Meaning}}<p><small>{{Meaning}}</small></p>{{/Meaning}}
{{#Expanded Meaning}}<p><small>{{Expanded Meaning}}</small></p>{{/Expanded Meaning}}{{#Collapsed Meaning}}<details><summary></summary><p><small>{{Collapsed Meaning}}</small></p></details><br>
{{/Collapsed Meaning}}''';

  File get _queueFile => File(path.join(rootDirectory.path, 'queue.json'));
  File get _decksFile => File(path.join(rootDirectory.path, 'decks.json'));
  File get _exportedKeysFile =>
      File(path.join(rootDirectory.path, 'exported_keys.json'));
  Directory get _mediaDirectory =>
      Directory(path.join(rootDirectory.path, 'media'));

  /// Notes waiting to be exported, oldest first.
  List<PendingAnkiNote> get pendingNotes {
    if (!_queueFile.existsSync()) {
      return [];
    }
    List<dynamic> json = jsonDecode(_queueFile.readAsStringSync());
    return json
        .map((e) => PendingAnkiNote.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void _writeQueue(List<PendingAnkiNote> notes) {
    _queueFile.writeAsStringSync(
        jsonEncode(notes.map((note) => note.toJson()).toList()));
  }

  Set<String> get _exportedKeys {
    if (!_exportedKeysFile.existsSync()) {
      return {};
    }
    return Set<String>.from(jsonDecode(_exportedKeysFile.readAsStringSync()));
  }

  /// Deck names offered for export: user-created decks plus decks of queued
  /// notes, always including Anki's 'Default'.
  List<String> get decks {
    Set<String> names = {'Default'};
    if (_decksFile.existsSync()) {
      names
          .addAll(List<String>.from(jsonDecode(_decksFile.readAsStringSync())));
    }
    names.addAll(pendingNotes.map((note) => note.deck));
    return names.toList()..sort();
  }

  /// Remember a deck name so it is offered in [decks].
  void addDeck(String name) {
    String trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    Set<String> names = decks.toSet()..add(trimmed);
    _decksFile.writeAsStringSync(jsonEncode(names.toList()));
  }

  /// Copy [file] into the queue's media folder and return the file name to
  /// reference from a field. [preferredName] is used as the stem.
  String addMedia({required File file, required String preferredName}) {
    String extension = path.extension(file.path);
    String name = '$preferredName$extension';
    int suffix = 1;
    while (File(path.join(_mediaDirectory.path, name)).existsSync()) {
      name = '$preferredName-$suffix$extension';
      suffix++;
    }
    file.copySync(path.join(_mediaDirectory.path, name));
    return name;
  }

  /// Queue a note of the standard note type for export.
  void addNote({
    required String deck,
    required List<String> fields,
    required List<String> tags,
  }) {
    if (fields.length != standardFields.length) {
      throw ArgumentError.value(fields.length, 'fields',
          'Expected ${standardFields.length} fields for the standard note type');
    }

    List<PendingAnkiNote> notes = pendingNotes;
    notes.add(
      PendingAnkiNote(
        guid: _guid(),
        deck: deck,
        fields: fields,
        tags: {appTag, ...tags.where((tag) => tag.trim().isNotEmpty)}.toList(),
        createdMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    _writeQueue(notes);
  }

  /// Whether a queued or previously exported note has [key] as its first
  /// field, mirroring AnkiDroid's duplicate check.
  bool hasDuplicate(String key) {
    String stripped = stripHtmlMedia(key);
    return _exportedKeys.contains(stripped) ||
        pendingNotes
            .any((note) => stripHtmlMedia(note.fields.first) == stripped);
  }

  /// Write the queue as an .apkg of [noteType], by default
  /// [AnkiNoteType.standard], in [outputDirectory] and return it.
  /// [noteFields] gives each queued note's fields for [noteType], in queue
  /// order; by default the queued fields are used.
  Future<File> buildPackage(
    Directory outputDirectory, {
    AnkiNoteType? noteType,
    List<List<String>>? noteFields,
  }) async {
    List<PendingAnkiNote> notes = pendingNotes;
    if (notes.isEmpty) {
      throw StateError('No notes queued for export');
    }
    noteType ??= AnkiNoteType.standard;
    noteFields ??= notes.map((note) => note.fields).toList();

    File databaseFile = File(path.join(rootDirectory.path, 'collection.anki2'));
    if (databaseFile.existsSync()) {
      databaseFile.deleteSync();
    }
    await _writeCollection(
      databasePath: databaseFile.path,
      notes: notes,
      noteType: noteType,
      noteFields: noteFields,
    );

    Archive archive = Archive()
      ..addFile(ArchiveFile.bytes(
          'collection.anki2', databaseFile.readAsBytesSync()));
    databaseFile.deleteSync();

    /// Anki packages store media as numbered files plus a JSON map from
    /// number to file name.
    Map<String, String> mediaMap = {};
    for (FileSystemEntity entity in _mediaDirectory.listSync()) {
      if (entity is File) {
        String number = '${mediaMap.length}';
        archive.addFile(ArchiveFile.bytes(number, entity.readAsBytesSync()));
        mediaMap[number] = path.basename(entity.path);
      }
    }
    archive
        .addFile(ArchiveFile.bytes('media', utf8.encode(jsonEncode(mediaMap))));

    String timestamp = DateTime.now()
        .toIso8601String()
        .split('.')
        .first
        .replaceAll(RegExp('[-:]'), '');
    File packageFile =
        File(path.join(outputDirectory.path, 'jidoujisho-$timestamp.apkg'));
    packageFile.writeAsBytesSync(ZipEncoder().encodeBytes(archive));

    return packageFile;
  }

  /// Clear the queue after its package was handed off, remembering first
  /// fields for [hasDuplicate].
  void markExported() {
    Set<String> keys = _exportedKeys
      ..addAll(pendingNotes.map((note) => stripHtmlMedia(note.fields.first)));
    _exportedKeysFile.writeAsStringSync(jsonEncode(keys.toList()));

    if (_queueFile.existsSync()) {
      _queueFile.deleteSync();
    }
    _mediaDirectory.deleteSync(recursive: true);
    _mediaDirectory.createSync(recursive: true);
  }

  Future<void> _writeCollection({
    required String databasePath,
    required List<PendingAnkiNote> notes,
    required AnkiNoteType noteType,
    required List<List<String>> noteFields,
  }) async {
    int nowMs = DateTime.now().millisecondsSinceEpoch;
    int nowSeconds = nowMs ~/ 1000;

    /// Anki's Default deck always has id 1; giving it another id makes Anki
    /// import it as a second deck, "Default_".
    Map<String, int> deckIds = {
      for (String deck in notes.map((note) => note.deck).toSet())
        deck: deck == 'Default' ? 1 : deckIdForName(deck),
    };

    Database database = await openDatabase(databasePath);
    try {
      await database.transaction((txn) async {
        for (String statement in _schema.split(';')) {
          if (statement.trim().isNotEmpty) {
            await txn.execute(statement);
          }
        }

        await txn.insert('col', {
          'id': 1,
          'crt': nowSeconds,
          'mod': nowMs,
          'scm': nowMs,
          'ver': 11,
          'dty': 0,
          'usn': 0,
          'ls': 0,
          'conf': jsonEncode(_collectionConfig),
          'models': jsonEncode({
            '${noteType.id}': _model(
              noteType: noteType,
              deckId: deckIds.values.first,
              modifiedSeconds: nowSeconds,
            ),
          }),
          'decks': jsonEncode({
            '1': _deck(id: 1, name: 'Default', modifiedSeconds: nowSeconds),
            for (MapEntry<String, int> entry in deckIds.entries)
              '${entry.value}': _deck(
                id: entry.value,
                name: entry.key,
                modifiedSeconds: nowSeconds,
              ),
          }),
          'dconf': jsonEncode({'1': _deckConfig}),
          'tags': '{}',
        });

        /// Note and card ids are millisecond timestamps in Anki; keep them
        /// unique and increasing.
        int nextId = nowMs;
        for (int position = 0; position < notes.length; position++) {
          PendingAnkiNote note = notes[position];
          List<String> fields = noteFields[position];
          int noteId = max(nextId++, note.createdMs);
          nextId = noteId + 1;
          String sortField = stripHtmlMedia(fields.first);

          await txn.insert('notes', {
            'id': noteId,
            'guid': note.guid,
            'mid': noteType.id,
            'mod': nowSeconds,
            'usn': -1,
            'tags':
                ' ${note.tags.map((tag) => tag.replaceAll(' ', '_')).join(' ')} ',
            'flds': fields.join('\x1f'),
            'sfld': sortField,
            'csum': fieldChecksum(fields.first),
            'flags': 0,
            'data': '',
          });

          await txn.insert('cards', {
            'id': nextId++,
            'nid': noteId,
            'did': deckIds[note.deck],
            'ord': 0,
            'mod': nowSeconds,
            'usn': -1,
            'type': 0,
            'queue': 0,
            'due': position + 1,
            'ivl': 0,
            'factor': 0,
            'reps': 0,
            'lapses': 0,
            'left': 0,
            'odue': 0,
            'odid': 0,
            'flags': 0,
            'data': '',
          });
        }
      });
    } finally {
      await database.close();
    }
  }

  /// Stable deck id derived from its name, so repeated exports to the same
  /// deck agree. Anki also matches decks by name on import.
  static int deckIdForName(String name) {
    List<int> digest = sha1.convert(utf8.encode(name)).bytes;
    int id = 0;
    for (int i = 0; i < 6; i++) {
      id = (id << 8) | digest[i];
    }

    /// Keep clear of the reserved default deck id 1.
    return id + 2;
  }

  /// Anki's field checksum: the first 8 hex digits of the SHA-1 of the
  /// first field with HTML and media references stripped.
  static int fieldChecksum(String field) {
    String hex = sha1.convert(utf8.encode(stripHtmlMedia(field))).toString();
    return int.parse(hex.substring(0, 8), radix: 16);
  }

  /// Anki's stripHTMLMedia: keep image file names, drop tags and decode the
  /// common entities.
  static String stripHtmlMedia(String html) {
    String withMedia = html.replaceAllMapped(
      RegExp('''<img[^>]+src=["']?([^"'>]+)["']?[^>]*>''',
          caseSensitive: false),
      (match) => ' ${match.group(1)} ',
    );
    return withMedia
        .replaceAll(RegExp('<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&')
        .trim();
  }

  static const String _guidAlphabet =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
      '!#\$%&()*+,-./:;<=>?@[]^_`{|}~';

  /// Random 64-bit value in Anki's base91 guid encoding.
  static String _guid() {
    Random random = Random.secure();
    BigInt value = BigInt.zero;
    for (int i = 0; i < 8; i++) {
      value = (value << 8) | BigInt.from(random.nextInt(256));
    }
    BigInt base = BigInt.from(_guidAlphabet.length);
    StringBuffer buffer = StringBuffer();
    do {
      buffer.write(_guidAlphabet[(value % base).toInt()]);
      value = value ~/ base;
    } while (value > BigInt.zero);
    return buffer.toString().split('').reversed.join();
  }

  static Map<String, dynamic> _model({
    required AnkiNoteType noteType,
    required int deckId,
    required int modifiedSeconds,
  }) {
    return {
      'id': '${noteType.id}',
      'name': noteType.name,
      'type': 0,
      'mod': noteType.modifiedSeconds ?? modifiedSeconds,
      'usn': -1,
      'sortf': 0,
      'did': deckId,
      'tmpls': [
        {
          'name': noteType.templateName,
          'ord': 0,
          'qfmt': noteType.frontTemplate,
          'afmt': noteType.backTemplate,
          'bqfmt': '',
          'bafmt': '',
          'did': null,
        },
      ],
      'flds': [
        for (int i = 0; i < noteType.fields.length; i++)
          {
            'name': noteType.fields[i],
            'ord': i,
            'sticky': false,
            'rtl': false,
            'font': 'Arial',
            'size': 20,
            'media': [],
          },
      ],
      'css': noteType.css,
      'latexPre': r'\documentclass[12pt]{article}'
          '\n'
          r'\special{papersize=3in,5in}'
          '\n'
          r'\usepackage[utf8]{inputenc}'
          '\n'
          r'\usepackage{amssymb,amsmath}'
          '\n'
          r'\pagestyle{empty}'
          '\n'
          r'\setlength{\parindent}{0in}'
          '\n'
          r'\begin{document}'
          '\n',
      'latexPost': r'\end{document}',
      'latexsvg': false,
      'tags': [],
      'vers': [],
      'req': noteType.requirements,
    };
  }

  static Map<String, dynamic> _deck({
    required int id,
    required String name,
    required int modifiedSeconds,
  }) {
    return {
      'id': id,
      'name': name,
      'mod': modifiedSeconds,
      'usn': -1,
      'desc': '',
      'dyn': 0,
      'conf': 1,
      'collapsed': false,
      'extendNew': 10,
      'extendRev': 50,
      'newToday': [0, 0],
      'revToday': [0, 0],
      'lrnToday': [0, 0],
      'timeToday': [0, 0],
    };
  }

  static const Map<String, dynamic> _collectionConfig = {
    'activeDecks': [1],
    'curDeck': 1,
    'newSpread': 0,
    'collapseTime': 1200,
    'timeLim': 0,
    'estTimes': true,
    'dueCounts': true,
    'curModel': null,
    'nextPos': 1,
    'sortType': 'noteFld',
    'sortBackwards': false,
    'addToCur': true,
  };

  static const Map<String, dynamic> _deckConfig = {
    'id': 1,
    'name': 'Default',
    'mod': 0,
    'usn': 0,
    'maxTaken': 60,
    'autoplay': true,
    'timer': 0,
    'replayq': true,
    'dyn': false,
    'new': {
      'bury': true,
      'delays': [1, 10],
      'initialFactor': 2500,
      'ints': [1, 4, 7],
      'order': 1,
      'perDay': 20,
      'separate': true,
    },
    'rev': {
      'bury': true,
      'ease4': 1.3,
      'fuzz': 0.05,
      'ivlFct': 1,
      'maxIvl': 36500,
      'minSpace': 1,
      'perDay': 200,
    },
    'lapse': {
      'delays': [10],
      'leechAction': 0,
      'leechFails': 8,
      'minInt': 1,
      'mult': 0,
    },
  };

  /// Anki 2.1 legacy (schema 11) collection layout, which every Anki version
  /// imports. Statements are separated by semicolons.
  static const String _schema = '''
CREATE TABLE col (id integer primary key, crt integer not null,
  mod integer not null, scm integer not null, ver integer not null,
  dty integer not null, usn integer not null, ls integer not null,
  conf text not null, models text not null, decks text not null,
  dconf text not null, tags text not null);
CREATE TABLE notes (id integer primary key, guid text not null,
  mid integer not null, mod integer not null, usn integer not null,
  tags text not null, flds text not null, sfld integer not null,
  csum integer not null, flags integer not null, data text not null);
CREATE TABLE cards (id integer primary key, nid integer not null,
  did integer not null, ord integer not null, mod integer not null,
  usn integer not null, type integer not null, queue integer not null,
  due integer not null, ivl integer not null, factor integer not null,
  reps integer not null, lapses integer not null, left integer not null,
  odue integer not null, odid integer not null, flags integer not null,
  data text not null);
CREATE TABLE revlog (id integer primary key, cid integer not null,
  usn integer not null, ease integer not null, ivl integer not null,
  lastIvl integer not null, factor integer not null,
  time integer not null, type integer not null);
CREATE TABLE graves (usn integer not null, oid integer not null,
  type integer not null);
CREATE INDEX ix_notes_usn on notes (usn);
CREATE INDEX ix_cards_usn on cards (usn);
CREATE INDEX ix_revlog_usn on revlog (usn);
CREATE INDEX ix_cards_nid on cards (nid);
CREATE INDEX ix_cards_sched on cards (did, queue, due);
CREATE INDEX ix_revlog_cid on revlog (cid);
CREATE INDEX ix_notes_csum on notes (csum);
''';

  /// Styling of the standard note type.
  static const String standardCss = '''
.card {
  font-family: "Helvetica Neue", Arial, sans-serif;
  font-size: 16px;
  text-align: center;
  color: #333333;
  background-color: #F6F6F6;
  border-radius: 12px;
  box-shadow: 0 6px 12px rgba(0, 0, 0, 0.2);
  padding: 24px;
  margin: 12px;
  border: 1px solid #D9D9D9;
}

#word {
  font-size: 30px;
  font-weight: bold;
  margin-bottom: 16px;
}

.details-summary {
  cursor: pointer;
  font-size: 16px;
  text-shadow: 1px 1px #ffffff;
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}

.details-summary:hover {
  color: #6495ED;
}

.details-summary:hover .arrow {
  transform: translateX(4px);
}

.arrow {
  fill: #777777;
  transition: transform 0.2s ease-in-out;
  margin-right: 8px;
}

.image img {
  max-width: 100%;
  height: 150px;
  border-radius: 12px;
  box-shadow: 0 6px 12px rgba(0, 0, 0, 0.2);
  margin-top: 8px;
  transition: height 0.2s ease-in-out;
}

.image:hover img {
  height: auto;
}

.furigana {
  font-size: 22px;
  font-weight: bold;
  line-height: 1.4;
  margin-bottom: 16px;
  text-shadow: 1px 1px #ffffff;
}

.meaning {
  font-size: 18px;
  line-height: 1.6;
  margin-bottom: 16px;
  text-shadow: 1px 1px #ffffff;
}

.cloze {
  font-weight: 900
}

#sentence {
  font-size: 20px;
  line-height: 1.6;
  margin-top: 16px;
} 

.pitch {
  border-top: solid red 2px;
  padding-top: 1px;
}

.pitch_end {
  border-color: red;
  border-right: solid red 2px;
  border-top: solid red 2px;  
  line-height: 1px;
  margin-right: 1px;
  padding-right: 1px;
  padding-top:1px;
}''';
}
