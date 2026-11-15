import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_floating_search_bar/material_floating_search_bar.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/models.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// A media source that allows the user to paste and select text.
class ReaderChatgptSource extends ReaderMediaSource {
  /// Define this media source.
  ReaderChatgptSource._privateConstructor()
      : super(
          uniqueKey: 'reader_chatgpt',
          sourceName: 'ChatGPT',
          description:
              'Allows the user to interact with an AI language model with an official API key from OpenAI.',
          icon: Icons.chat_outlined,
          implementsSearch: false,
          implementsHistory: false,
        );

  /// Get the singleton instance of this media type.
  static ReaderChatgptSource get instance => _instance;

  static final ReaderChatgptSource _instance =
      ReaderChatgptSource._privateConstructor();

  /// Keeps the API key in the iOS Keychain or Android's encrypted
  /// preferences rather than in plain app preferences. The key is kept to
  /// this device and left out of backups.
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _apiKeyKey = 'openai_api_key';

  String? _apiKey;

  /// Loads the API key, moving a key that earlier versions kept in plain
  /// preferences to secure storage.
  @override
  Future<void> prepareResources() async {
    String? plainKey =
        getPreference<String?>(key: _apiKeyKey, defaultValue: null);
    if (plainKey != null) {
      await setApiKey(plainKey);
      await deletePreference(key: _apiKeyKey);
      return;
    }

    try {
      _apiKey = await _secureStorage.read(key: _apiKeyKey);
    } catch (e) {
      debugPrint('Could not read the OpenAI API key: $e');
    }
  }

  /// The OpenAI API key, or null if none is set.
  String? get apiKey => _apiKey;

  /// Save the OpenAI API key, or remove it if [value] is empty.
  Future<void> setApiKey(String? value) async {
    _apiKey = (value == null || value.isEmpty) ? null : value;
    if (_apiKey == null) {
      await _secureStorage.delete(key: _apiKeyKey);
    } else {
      await _secureStorage.write(key: _apiKeyKey, value: _apiKey);
    }
  }

  /// The model used when none is set.
  static const String defaultModel = 'gpt-6-luna';

  /// The model used for the ChatGPT source and for translating and breaking
  /// down sentences.
  String get model {
    String model =
        getPreference<String>(key: 'openai_model', defaultValue: defaultModel);
    return model.isEmpty ? defaultModel : model;
  }

  /// Used to persist the model.
  Future<void> setModel(String value) async {
    await setPreference(key: 'openai_model', value: value);
  }

  /// Reasoning effort requested from [model], or an empty string to leave it
  /// to the model, for models without reasoning.
  String get reasoningEffort {
    return getPreference<String>(
        key: 'openai_reasoning_effort', defaultValue: 'low');
  }

  /// Used to persist the reasoning effort.
  Future<void> setReasoningEffort(String value) async {
    await setPreference(key: 'openai_reasoning_effort', value: value);
  }

  @override
  Future<void> onSearchBarTap({
    required BuildContext context,
    required WidgetRef ref,
    required AppModel appModel,
  }) async {}

  @override
  BaseSourcePage buildLaunchPage({
    MediaItem? item,
  }) {
    throw UnsupportedError('ChatGPT source does not launch any page');
  }

  @override
  List<Widget> getActions({
    required BuildContext context,
    required WidgetRef ref,
    required AppModel appModel,
  }) {
    return [
      buildClearButton(
        context: context,
        ref: ref,
        appModel: appModel,
      ),
      buildApiKeyButton(context: context, ref: ref, appModel: appModel),
    ];
  }

  /// Menu bar action.
  Widget buildApiKeyButton(
      {required BuildContext context,
      required WidgetRef ref,
      required AppModel appModel}) {
    return FloatingSearchBarAction(
      child: JidoujishoIconButton(
        size: Theme.of(context).textTheme.titleLarge?.fontSize,
        tooltip: t.api_key,
        icon: Icons.key,
        onTap: () async {
          await showDialog(
            context: context,
            builder: (context) => const ChatgptSettingsDialogPage(),
          );

          mediaType.refreshTab();
        },
      ),
    );
  }

  /// Menu bar action.
  Widget buildClearButton(
      {required BuildContext context,
      required WidgetRef ref,
      required AppModel appModel}) {
    return FloatingSearchBarAction(
      child: JidoujishoIconButton(
        size: Theme.of(context).textTheme.titleLarge?.fontSize,
        tooltip: t.clear_message_title,
        icon: Icons.clear_all,
        onTap: () {
          showClearPrompt(
            appModel: appModel,
            context: context,
            ref: ref,
          );
        },
      ),
    );
  }

  /// Shows when the clear button is pressed.
  void showClearPrompt(
      {required BuildContext context,
      required WidgetRef ref,
      required AppModel appModel}) async {
    Widget alertDialog = AlertDialog(
      title: Text(t.clear_message_title),
      content: Text(t.clear_message_description),
      actions: <Widget>[
        TextButton(
          child: Text(
            t.dialog_clear,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          onPressed: () async {
            Navigator.pop(context);
            await appModel.clearMessages();

            mediaType.refreshTab();
          },
        ),
        TextButton(
          child: Text(t.dialog_cancel),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );

    await showDialog(
      context: context,
      builder: (context) => alertDialog,
    );
  }

  @override
  BasePage buildHistoryPage({MediaItem? item}) {
    return const ReaderChatgptPage();
  }
}
