import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_ia/services/llm_config.dart';

void main() {
  test('usa DeepSeek por defecto', () {
    final config = llmConfigFromEnv({'LLM_API_KEY': 'deepseek-key'});

    expect(config.apiKey, 'deepseek-key');
    expect(config.baseUrl, 'https://api.deepseek.com');
    expect(config.model, 'deepseek-chat');
  });

  test('usa OpenAI cuando LLM_PROVIDER=openai', () {
    final config = llmConfigFromEnv({
      'LLM_PROVIDER': 'openai',
      'OPENAI_API_KEY': 'openai-key',
    });

    expect(config.apiKey, 'openai-key');
    expect(config.baseUrl, 'https://api.openai.com/v1');
    expect(config.model, 'gpt-4o-mini');
  });

  test('permite sobrescribir el modelo de OpenAI', () {
    final config = llmConfigFromEnv({
      'LLM_PROVIDER': 'openai',
      'OPENAI_API_KEY': 'openai-key',
      'OPENAI_MODEL': 'gpt-4.1-mini',
    });

    expect(config.model, 'gpt-4.1-mini');
  });
}
