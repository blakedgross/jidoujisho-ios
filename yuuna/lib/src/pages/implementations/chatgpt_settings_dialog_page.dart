import 'package:flutter/material.dart';
import 'package:spaces/spaces.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// The content of the dialog used for managing ChatGPT settings.
class ChatgptSettingsDialogPage extends BasePage {
  /// Create an instance of this page.
  const ChatgptSettingsDialogPage({super.key});

  @override
  BasePageState createState() => _ChatgptSettingsDialogPageState();
}

class _ChatgptSettingsDialogPageState extends BasePageState {
  late TextEditingController _apiKeyController;
  late TextEditingController _modelController;

  @override
  void initState() {
    super.initState();

    _apiKeyController =
        TextEditingController(text: ReaderChatgptSource.instance.apiKey ?? '');
    _modelController =
        TextEditingController(text: ReaderChatgptSource.instance.model);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: MediaQuery.of(context).orientation == Orientation.portrait
          ? Spacing.of(context).insets.exceptBottom.big
          : Spacing.of(context).insets.exceptBottom.normal.copyWith(
                left: Spacing.of(context).spaces.semiBig,
                right: Spacing.of(context).spaces.semiBig,
              ),
      actionsPadding: Spacing.of(context).insets.exceptBottom.normal.copyWith(
            left: Spacing.of(context).spaces.normal,
            right: Spacing.of(context).spaces.normal,
            bottom: Spacing.of(context).spaces.normal,
            top: Spacing.of(context).spaces.extraSmall,
          ),
      content: buildContent(),
      actions: actions,
    );
  }

  List<Widget> get actions => [
        buildCloseButton(),
      ];

  Widget buildCloseButton() {
    return TextButton(
      child: Text(t.dialog_close),
      onPressed: () => Navigator.pop(context),
    );
  }

  Widget buildContent() {
    ScrollController contentController = ScrollController();

    return RawScrollbar(
      thickness: 3,
      thumbVisibility: true,
      controller: contentController,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * (1 / 3),
        child: SingleChildScrollView(
          controller: contentController,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildApiKeyField(),
              const Space.normal(),
              buildModelField(),
              const Space.normal(),
              buildReasoningEffortDropdown(),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildApiKeyField() {
    return TextField(
      onChanged: (value) {
        ReaderChatgptSource.instance.setApiKey(value.trim());
      },
      controller: _apiKeyController,
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelText: t.api_key,
      ),
    );
  }

  Widget buildModelField() {
    return TextField(
      onChanged: (value) {
        ReaderChatgptSource.instance.setModel(value.trim());
      },
      controller: _modelController,
      autocorrect: false,
      decoration: InputDecoration(
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelText: t.openai_model,
        hintText: ReaderChatgptSource.defaultModel,
      ),
    );
  }

  /// Reasoning efforts to pick from. The empty string leaves the effort to
  /// the model, for models without reasoning.
  static const List<String> reasoningEfforts = [
    '',
    'none',
    'low',
    'medium',
    'high',
  ];

  Widget buildReasoningEffortDropdown() {
    String effort = ReaderChatgptSource.instance.reasoningEffort;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: Spacing.of(context).insets.onlyLeft.small,
          child: Text(
            t.openai_reasoning_effort,
            style: TextStyle(
              fontSize: 10,
              color: theme.unselectedWidgetColor,
            ),
          ),
        ),
        JidoujishoDropdown<String>(
          options: reasoningEfforts,
          initialOption: reasoningEfforts.contains(effort) ? effort : 'low',
          generateLabel: (effort) => effort.isEmpty
              ? t.openai_reasoning_model_default
              : effort[0].toUpperCase() + effort.substring(1),
          onChanged: (effort) {
            ReaderChatgptSource.instance.setReasoningEffort(effort!);
          },
        ),
      ],
    );
  }
}
