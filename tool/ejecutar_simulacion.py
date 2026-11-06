import urllib.request
import json
import os

env = {}
if os.path.exists('.env'):
    with open('.env') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                k, v = line.split('=', 1)
                env[k.strip()] = v.strip()

supabase_url = env.get('SUPABASE_URL', '')
anon_key = env.get('SUPABASE_ANON_KEY', '')

print(f"Conectando a {supabase_url}...")

# 1. Obtener lista de negocios
req = urllib.request.Request(f"{supabase_url}/rest/v1/negocios?select=id,nombre", headers={
    'apikey': anon_key,
    'Authorization': f'Bearer {anon_key}'
})

negocios_existentes = {}
try:
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode())
        negocios_existentes = {n['nombre']: n['id'] for n in data}
        print(f"Negocios en base de datos: {list(negocios_existentes.keys())}")
except Exception as e:
    print(f"Error consultando negocios: {e}")

