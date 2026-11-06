const LLM_BASE_URL = (process.env.LLM_BASE_URL || 'https://api.deepseek.com')
  .replace(/\/$/, '');

module.exports = async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  const supabaseUrl = process.env.SUPABASE_URL;
  const anonKey = process.env.SUPABASE_ANON_KEY;
  const apiKey = process.env.LLM_API_KEY;

  if (!supabaseUrl || !anonKey || !apiKey) {
    res.status(500).json({ error: 'Faltan variables de entorno del servidor' });
    return;
  }

  const authHeader = req.headers.authorization || '';
  const token = authHeader.replace(/^Bearer\s+/i, '').trim();

  if (!token || token === 'proxy') {
    res.status(401).json({ error: 'Sesión requerida' });
    return;
  }

  const userResponse = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: {
      apikey: anonKey,
      Authorization: `Bearer ${token}`,
    },
  });

  if (!userResponse.ok) {
    res.status(401).json({ error: 'Sesión inválida' });
    return;
  }

  const body =
    typeof req.body === 'string' ? req.body : JSON.stringify(req.body ?? {});

  try {
    const upstream = await fetch(`${LLM_BASE_URL}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body,
    });

    const text = await upstream.text();
    res.status(upstream.status);
    res.setHeader(
      'Content-Type',
      upstream.headers.get('content-type') || 'application/json',
    );
    res.send(text);
  } catch (error) {
    res.status(502).json({ error: `No se pudo contactar al LLM: ${error}` });
  }
};
