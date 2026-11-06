import urllib.request
import json
import os
import sys

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

# IDs de los negocios
NID_MAKEUP = 'b1111111-1111-1111-1111-111111111111'
NID_ROPA = 'b2222222-2222-2222-2222-222222222222'

def api_call(endpoint, method='GET', data=None, headers_extra=None):
    url = f"{supabase_url}/rest/v1/{endpoint}"
    h = {
        'apikey': anon_key,
        'Authorization': f'Bearer {anon_key}',
        'Content-Type': 'application/json'
    }
    if headers_extra:
        h.update(headers_extra)
    payload = json.dumps(data).encode('utf-8') if data else None
    req = urllib.request.Request(url, data=payload, method=method, headers=h)
    try:
        with urllib.request.urlopen(req) as resp:
            content = resp.read().decode('utf-8')
            return json.loads(content) if content else {}
    except urllib.error.HTTPError as e:
        err = e.read().decode('utf-8')
        print(f"Error {method} {endpoint}: {e.code} - {err}")
        return None

print("=== Comprobando si los negocios ya existen en Supabase ===")
negocios = api_call('negocios?select=*')
nombres = [n['nombre'] for n in negocios]
print(f"Negocios actuales: {nombres}")

if 'Glow & Glam MakeUp' in nombres and 'Ropa Americana Lucía' in nombres:
    print("✓ Los negocios ya están en Supabase.")
    # Verificar productos
    p1 = api_call(f"productos?negocio_id=eq.{NID_MAKEUP}", headers_extra={'x-negocio-id': NID_MAKEUP})
    print(f"Productos Glow & Glam: {len(p1) if p1 else 0}")
    p2 = api_call(f"productos?negocio_id=eq.{NID_ROPA}", headers_extra={'x-negocio-id': NID_ROPA})
    print(f"Productos Ropa Americana: {len(p2) if p2 else 0}")
    t1 = api_call(f"transacciones?negocio_id=eq.{NID_MAKEUP}", headers_extra={'x-negocio-id': NID_MAKEUP})
    print(f"Transacciones Glow & Glam: {len(t1) if t1 else 0}")
    t2 = api_call(f"transacciones?negocio_id=eq.{NID_ROPA}", headers_extra={'x-negocio-id': NID_ROPA})
    print(f"Transacciones Ropa Americana: {len(t2) if t2 else 0}")
else:
    print("! Aún no se han ejecutado los inserts en Supabase.")
    print("! Ejecuta el archivo 'supabase/migracion_simulacion_emprendimientos.sql' en el SQL Editor de tu Dashboard de Supabase.")

