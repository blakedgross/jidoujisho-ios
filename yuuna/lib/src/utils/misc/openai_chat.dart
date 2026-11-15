import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:yuuna/media.dart';
import 'package:yuuna/utils.dart';

/// Raised when [OpenAiChat] cannot get an answer, with a message for the
/// user.
class OpenAiChatException implements Exception {
  /// Create an exception with a message for the user.
  OpenAiChatException(this.message);

  /// Why the request failed.
  final String message;

  @override
  String toString() => message;
}

/// Streams answers from OpenAI's Chat Completions API with the API key,
/// model and reasoning effort set for [ReaderChatgptSource].
class OpenAiChat {
  OpenAiChat._();

  static final Uri _endpoint =
      Uri.parse('https://api.openai.com/v1/chat/completions');

  /// Stream the answer to [messages], a conversation of maps with a `role`
  /// (`system`, `user` or `assistant`) and its `content`. Each event is the
  /// whole answer so far.
  static Stream<String> complete({
    required List<Map<String, String>> messages,
  }) async* {
    ReaderChatgptSource source = ReaderChatgptSource.instance;
    String? apiKey = source.apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw OpenAiChatException(t.openai_missing_api_key);
    }

    String reasoningEffort = source.reasoningEffort;
    http.Request request = http.Request('POST', _endpoint)
      ..headers.addAll({
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode({
        'model': source.model,
        if (reasoningEffort.isNotEmpty) 'reasoning_effort': reasoningEffort,
        'stream': true,
        'messages': messages,
      });

    http.Client client = http.Client();
    try {
      http.StreamedResponse response;
      try {
        response = await client.send(request);
      } catch (e) {
        throw OpenAiChatException(t.openai_unreachable(error: e));
      }

      if (response.statusCode != 200) {
        String body = await response.stream.bytesToString();
        throw OpenAiChatException(_errorMessage(response, body));
      }

      StringBuffer answer = StringBuffer();
      await for (String line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (!line.startsWith('data:')) {
          continue;
        }
        String data = line.substring(5).trim();
        if (data == '[DONE]') {
          break;
        }

        Map<String, dynamic> chunk = jsonDecode(data);
        List<dynamic> choices = chunk['choices'] ?? [];
        String? delta = choices.isEmpty
            ? null
            : ((choices.first as Map<String, dynamic>)['delta']
                as Map<String, dynamic>?)?['content'];
        if (delta != null && delta.isNotEmpty) {
          answer.write(delta);
          yield answer.toString();
        }
      }
    } finally {
      client.close();
    }
  }

  static String _errorMessage(http.StreamedResponse response, String body) {
    String? detail;
    try {
      Map<String, dynamic> error =
          (jsonDecode(body) as Map<String, dynamic>)['error'];
      detail = error['message'];
    } catch (_) {}

    return t.openai_failed(
      status: response.statusCode,
      message: detail ?? response.reasonPhrase ?? '',
    );
  }
}
