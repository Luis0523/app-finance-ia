import 'llm_service.dart';

class LlmConfig {
  const LlmConfig({
    required this.apiKey,
    required this.baseUrl,
    required this.model,
  });

  final String apiKey;
  final String baseUrl;
  final String model;
}

LlmConfig llmConfigFromEnv(Map<String, String> env) {
  final provider = env['LLM_PROVIDER']?.trim().toLowerCase();
  if (provider == 'openai') {
    return LlmConfig(
      apiKey: env['OPENAI_API_KEY'] ?? '',
      baseUrl: env['OPENAI_BASE_URL'] ?? 'https://api.openai.com/v1',
      model: env['OPENAI_MODEL'] ?? 'gpt-4o-mini',
    );
  }

  return LlmConfig(
    apiKey: env['LLM_API_KEY'] ?? '',
    baseUrl: env['LLM_BASE_URL'] ?? 'https://api.deepseek.com',
    model: env['LLM_MODEL'] ?? 'deepseek-chat',
  );
}

LlmService llmServiceFromEnv(Map<String, String> env) {
  final config = llmConfigFromEnv(env);
  return LlmService(
    apiKey: config.apiKey,
    baseUrl: config.baseUrl,
    model: config.model,
  );
}
