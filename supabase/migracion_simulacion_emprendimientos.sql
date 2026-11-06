-- ==============================================================================
-- MIGRACIÓN / SIMULACIÓN DE DATOS REALISTAS
-- Período: 31 de Octubre al 5 de Noviembre
-- Negocios:
--   1. "Glow & Glam MakeUp" (Maquillaje y cosméticos - Sofía)
--   2. "Ropa Americana Lucía" (Moda, pacas y prendas seleccionadas - Lucía)
-- ==============================================================================

-- 1. Asegurar que 'anon' y 'authenticated' puedan registrar negocios si aún no existe política de insert
do $$
begin
  if not exists (
    select 1 from pg_policies where tablename = 'negocios' and policyname = 'negocios_insert_anon'
  ) then
    create policy "negocios_insert_anon" on negocios for insert to anon, authenticated with check (true);
  end if;
end $$;

-- 2. Limpieza de simulaciones previas si se vuelve a correr
delete from negocios where nombre in ('Glow & Glam MakeUp', 'Ropa Americana Lucía');

-- 3. Crear los 2 negocios
insert into negocios (id, nombre, rubro, regimen_tributario)
values
  ('b1111111-1111-1111-1111-111111111111', 'Glow & Glam MakeUp', 'Cosméticos y Maquillaje', 'pequeño contribuyente'),
  ('b2222222-2222-2222-2222-222222222222', 'Ropa Americana Lucía', 'Ropa y Moda Americana', 'pequeño contribuyente');

-- 4. Crear dueños en usuarios
insert into usuarios (id, negocio_id, telefono, rol)
values
  ('u1111111-1111-1111-1111-111111111111', 'b1111111-1111-1111-1111-111111111111', '50255551001', 'dueño'),
  ('u2222222-2222-2222-2222-222222222222', 'b2222222-2222-2222-2222-222222222222', '50255551002', 'dueño');

-- 5. Crear cuentas de dinero
insert into cuentas_dinero (id, negocio_id, nombre, tipo, saldo_actual)
values
  ('cd111111-1111-1111-1111-111111111111', 'b1111111-1111-1111-1111-111111111111', 'Caja Efectivo', 'efectivo', 850.00),
  ('cd111111-1111-1111-1111-222222222222', 'b1111111-1111-1111-1111-111111111111', 'Transferencias Banrural', 'banco', 1420.00),
  ('cd222222-2222-2222-2222-111111111111', 'b2222222-2222-2222-2222-222222222222', 'Caja Principal', 'efectivo', 1240.00),
  ('cd222222-2222-2222-2222-222222222222', 'b2222222-2222-2222-2222-222222222222', 'Cuenta BI Monetaria', 'banco', 2300.00);

-- 6. Crear catálogo de productos para Glow & Glam MakeUp
insert into productos (id, negocio_id, nombre, nombre_normalizado, precio_compra, precio_venta, stock_minimo)
values
  ('p1010000-0000-0000-0000-000000000001', 'b1111111-1111-1111-1111-111111111111', 'Labial Mate Larga Duración', 'labial mate larga duracion', 22.00, 45.00, 5),
  ('p1010000-0000-0000-0000-000000000002', 'b1111111-1111-1111-1111-111111111111', 'Paleta de Sombras Nude 12 Colores', 'paleta de sombras nude 12 colores', 45.00, 95.00, 3),
  ('p1010000-0000-0000-0000-000000000003', 'b1111111-1111-1111-1111-111111111111', 'Base Líquida Cobertura Media', 'base liquida cobertura media', 35.00, 75.00, 4),
  ('p1010000-0000-0000-0000-000000000004', 'b1111111-1111-1111-1111-111111111111', 'Rímel A prueba de Agua Extra Volumen', 'rimel a prueba de agua extra volumen', 20.00, 40.00, 6),
  ('p1010000-0000-0000-0000-000000000005', 'b1111111-1111-1111-1111-111111111111', 'Polvo Compacto Traslúcido', 'polvo compacto traslucido', 25.00, 50.00, 4),
  ('p1010000-0000-0000-0000-000000000006', 'b1111111-1111-1111-1111-111111111111', 'Set de Brochas Profesionales x8', 'set de brochas profesionales x8', 50.00, 110.00, 2);

-- 7. Crear catálogo de productos para Ropa Americana Lucía
insert into productos (id, negocio_id, nombre, nombre_normalizado, precio_compra, precio_venta, stock_minimo)
values
  ('p2020000-0000-0000-0000-000000000001', 'b2222222-2222-2222-2222-222222222222', 'Blusa Casual Premium', 'blusa casual premium', 18.00, 45.00, 8),
  ('p2020000-0000-0000-0000-000000000002', 'b2222222-2222-2222-2222-222222222222', 'Pantalón Jeans Americano Levi/AE', 'pantalon jeans americano levi/ae', 45.00, 110.00, 5),
  ('p2020000-0000-0000-0000-000000000003', 'b2222222-2222-2222-2222-222222222222', 'Vestido de Verano Estampado', 'vestido de verano estampado', 28.00, 65.00, 4),
  ('p2020000-0000-0000-0000-000000000004', 'b2222222-2222-2222-2222-222222222222', 'Chaqueta Denim / Suéter Ligero', 'chaqueta denim / sueter ligero', 55.00, 125.00, 3),
  ('p2020000-0000-0000-0000-000000000005', 'b2222222-2222-2222-2222-222222222222', 'Falda Midi Plisada', 'falda midi plisada', 20.00, 50.00, 4);

-- 8. Inicializar Inventario de Glow & Glam MakeUp
insert into inventario (producto_id, existencia_actual, costo_promedio_actual)
values
  ('p1010000-0000-0000-0000-000000000001', 18, 22.00),
  ('p1010000-0000-0000-0000-000000000002', 8, 45.00),
  ('p1010000-0000-0000-0000-000000000003', 12, 35.00),
  ('p1010000-0000-0000-0000-000000000004', 15, 20.00),
  ('p1010000-0000-0000-0000-000000000005', 9, 25.00),
  ('p1010000-0000-0000-0000-000000000006', 5, 50.00);

-- 9. Inicializar Inventario de Ropa Americana Lucía
insert into inventario (producto_id, existencia_actual, costo_promedio_actual)
values
  ('p2020000-0000-0000-0000-000000000001', 32, 18.00),
  ('p2020000-0000-0000-0000-000000000002', 19, 45.00),
  ('p2020000-0000-0000-0000-000000000003', 14, 28.00),
  ('p2020000-0000-0000-0000-000000000004', 11, 55.00),
  ('p2020000-0000-0000-0000-000000000005', 16, 20.00);

-- 10. Transacciones históricas (31 Octubre - 05 Noviembre)
-- Usamos las categorías globales:
-- Ingresos: '30c1bbc8-30f3-4cfe-b250-9db7333487b9'
-- Costos de venta: '2ad8bb91-07c7-467d-8b17-220e9a30d706'
-- Gastos operativos: 'bf7ff4dd-0a75-466f-bbe7-45bea51e9ac8'
-- Gastos administrativos: 'e12d32db-e332-4234-82fc-dcd7b2a7b28e'

-- === GLOW & GLAM MAKEUP (Sofía) ===
-- Curva: 31 Oct (arrancando con 1 venta tímida), 1 Nov (feriado día de todos los santos, pocas ventas), 2 Nov (retoma), 3 Nov (buen día por promociones fin de semana), 4 Nov (día tranquilo lunes), 5 Nov (excelente día por reposición de quincena).
insert into transacciones (
  negocio_id, cuenta_dinero_id, categoria_id, monto, tipo,
  producto_id, cantidad, precio_unitario, costo_unitario_momento_venta, utilidad_calculada,
  descripcion_original, descripcion_normalizada, fecha, origen, confirmado_por_usuario
) values
  -- 31 Octubre
  ('b1111111-1111-1111-1111-111111111111', 'cd111111-1111-1111-1111-111111111111', '30c1bbc8-30f3-4cfe-b250-9db7333487b9', 45.00, 'ingreso',
   'p1010000-0000-0000-0000-000000000001', 1, 45.00, 22.00, 23.00,
   'Venta de labial mate tono rosa', 'venta labial mate larga duracion', '2026-10-31', 'manual', true),
  ('b1111111-1111-1111-1111-111111111111', 'cd111111-1111-1111-1111-111111111111', 'bf7ff4dd-0a75-466f-bbe7-45bea51e9ac8', 30.00, 'egreso',
   null, null, null, null, 0.00,
   'Bolsitas de regalo y papel de seda', 'empaques y bolsas regalo', '2026-10-31', 'manual', true),

  -- 01 Noviembre (Día de los Santos, flojo)
  ('b1111111-1111-1111-1111-111111111111', 'cd111111-1111-1111-1111-111111111111', '30c1bbc8-30f3-4cfe-b250-9db7333487b9', 40.00, 'ingreso',
   'p1010000-0000-0000-0000-000000000004', 1, 40.00, 20.00, 20.00,
   'Un rímel contra agua para una vecina', 'venta rimel extra volumen', '2026-11-01', 'texto', true),

  -- 02 Noviembre (Sábado de compras)
  ('b1111111-1111-1111-1111-111111111111', 'cd111111-1111-1111-1111-222222222222', '30c1bbc8-30f3-4cfe-b250-9db7333487b9', 170.00, 'ingreso',
   'p1010000-0000-0000-0000-000000000003', 2, 85.00, 35.00, 100.00,
   '2 bases líquidas transferidas por banca virtual', 'venta 2 bases liquidas', '2026-11-02', 'texto', true),
  ('b1111111-1111-1111-1111-111111111111', 'cd111111-1111-1111-1111-111111111111', '30c1bbc8-30f3-4cfe-b250-9db7333487b9', 95.00, 'ingreso',
   'p1010000-0000-0000-0000-000000000002', 1, 95.00, 45.00, 50.00,
   'Paleta de sombras para regalo de cumpleaños', 'venta paleta de sombras', '2026-11-02', 'manual', true),

  -- 03 Noviembre (Domingo muy bueno, combo de maquillaje)
  ('b1111111-1111-1111-1111-111111111111', 'cd111111-1111-1111-1111-111111111111', '30c1bbc8-30f3-4cfe-b250-9db7333487b9', 245.00, 'ingreso',
   'p1010000-0000-0000-0000-000000000006', 1, 110.00, 50.00, 60.00,
   'Set de brochas profesionales + polvo traslúcido y labial', 'venta combo de maquillaje completo', '2026-11-03', 'texto', true),
  ('b1111111-1111-1111-1111-111111111111', 'cd111111-1111-1111-1111-111111111111', '30c1bbc8-30f3-4cfe-b250-9db7333487b9', 90.00, 'ingreso',
   'p1010000-0000-0000-0000-000000000001', 2, 45.00, 22.00, 46.00,
   '2 labiales mate rojo cereza y nude', 'venta 2 labiales mate', '2026-11-03', 'manual', true),
  ('b1111111-1111-1111-1111-111111111111', 'cd111111-1111-1111-1111-111111111111', 'e12d32db-e332-4234-82fc-dcd7b2a7b28e', 50.00, 'egreso',
   null, null, null, null, 0.00,
   'Publicidad en Instagram y TikTok para la semana', 'pauta de anuncios redes sociales', '2026-11-03', 'manual', true),

  -- 04 Noviembre (Lunes flojo típico)
  ('b1111111-1111-1111-1111-111111111111', 'cd111111-1111-1111-1111-111111111111', '30c1bbc8-30f3-4cfe-b250-9db7333487b9', 50.00, 'ingreso',
   'p1010000-0000-0000-0000-000000000005', 1, 50.00, 25.00, 25.00,
   'Polvo traslúcido tono 2', 'venta polvo traslucido', '2026-11-04', 'texto', true),
  ('b1111111-1111-1111-1111-111111111111', 'cd111111-1111-1111-1111-111111111111', 'bf7ff4dd-0a75-466f-bbe7-45bea51e9ac8', 25.00, 'egreso',
   null, null, null, null, 0.00,
   'Envío mensajería en moto a zona 10', 'servicio de flete mensajeria', '2026-11-04', 'manual', true),

  -- 05 Noviembre (Hoy - Excelente movimiento)
  ('b1111111-1111-1111-1111-111111111111', 'cd111111-1111-1111-1111-222222222222', '30c1bbc8-30f3-4cfe-b250-9db7333487b9', 190.00, 'ingreso',
   'p1010000-0000-0000-0000-000000000002', 2, 95.00, 45.00, 100.00,
   '2 paletas de sombras pedido express', 'venta 2 paletas de sombras', '2026-11-05', 'texto', true),
  ('b1111111-1111-1111-1111-111111111111', 'cd111111-1111-1111-1111-111111111111', '30c1bbc8-30f3-4cfe-b250-9db7333487b9', 115.00, 'ingreso',
   'p1010000-0000-0000-0000-000000000003', 1, 75.00, 35.00, 40.00,
   'Base líquida + rímel volumen', 'venta base liquida mas rimel', '2026-11-05', 'manual', true);

-- === ROPA AMERICANA LUCÍA (Lucía) ===
-- Curva: 31 Octubre (desempacando fardo nuevo, pocas ventas), 1 Nov (feriado, apertura de fardo premium, buenas ventas por la tarde), 2 Nov (sábado excelente con liquidación de blusas), 3 Nov (domingo moderado), 4 Nov (lunes bajo), 5 Nov (hoy, venta de jeans y chaquetas).
insert into transacciones (
  negocio_id, cuenta_dinero_id, categoria_id, monto, tipo,
  producto_id, cantidad, precio_unitario, costo_unitario_momento_venta, utilidad_calculada,
  descripcion_original, descripcion_normalizada, fecha, origen, confirmado_por_usuario
) values
  -- 31 Octubre
  ('b2222222-2222-2222-2222-222222222222', 'cd222222-2222-2222-2222-111111111111', '30c1bbc8-30f3-4cfe-b250-9db7333487b9', 45.00, 'ingreso',
   'p2020000-0000-0000-0000-000000000001', 1, 45.00, 18.00, 27.00,
   'Blusa blanca bordada de paca americana', 'venta blusa casual americana', '2026-10-31', 'manual', true),
  ('b2222222-2222-2222-2222-222222222222', 'cd222222-2222-2222-2222-111111111111', 'bf7ff4dd-0a75-466f-bbe7-45bea51e9ac8', 80.00, 'egreso',
   null, null, null, null, 0.00,
   'Ganchos de plástico para ropa y etiquetas de precio', 'suministros tienda y exhibicion', '2026-10-31', 'manual', true),

  -- 01 Noviembre (Apertura de paca especial)
  ('b2222222-2222-2222-2222-111111111111', 'cd222222-2222-2222-2222-111111111111', '30c1bbc8-30f3-4cfe-b250-9db7333487b9', 220.00, 'ingreso',
   'p2020000-0000-0000-0000-000000000002', 2, 110.00, 45.00, 130.00,
   '2 pantalones Jeans Levi Strauss originales', 'venta 2 jeans levi strauss', '2026-11-01', 'manual', true),
  ('b2222222-2222-2222-2222-222222222222', 'cd222222-2222-2222-2222-111111111111', '30c1bbc8-30f3-4cfe-b250-9db7333487b9', 65.00, 'ingreso',
   'p2020000-0000-0000-0000-000000000003', 1, 65.00, 28.00, 37.00,
   'Vestido floreado de verano talla M', 'venta vestido verano estampado', '2026-11-01', 'texto', true),

  -- 02 Noviembre (Sábado muy activo)
  ('b2222222-2222-2222-2222-222222222222', 'cd222222-2222-2222-2222-111111111111', '30c1bbc8-30f3-4cfe-b250-9db7333487b9', 180.00, 'ingreso',
   'p2020000-0000-0000-0000-000000000001', 4, 45.00, 18.00, 108.00,
   '4 blusas surtidas promoción de fin de semana', 'venta 4 blusas americanas', '2026-11-02', 'manual', true),
  ('b2222222-2222-2222-2222-222222222222', 'cd222222-2222-2222-2222-222222222222', '30c1bbc8-30f3-4cfe-b250-9db7333487b9', 125.00, 'ingreso',
   'p2020000-0000-0000-0000-000000000004', 1, 125.00, 55.00, 70.00,
   'Chaqueta de mezclilla American Eagle transferida por BI', 'venta chaqueta denim american eagle', '2026-11-02', 'texto', true),
  ('b2222222-2222-2222-2222-222222222222', 'cd222222-2222-2222-2222-111111111111', 'bf7ff4dd-0a75-466f-bbe7-45bea51e9ac8', 40.00, 'egreso',
   null, null, null, null, 0.00,
   'Pago de luz del local de ropa', 'servicio energia electrica local', '2026-11-02', 'manual', true),

  -- 03 Noviembre (Domingo normal)
  ('b2222222-2222-2222-2222-222222222222', 'cd222222-2222-2222-2222-111111111111', '30c1bbc8-30f3-4cfe-b250-9db7333487b9', 100.00, 'ingreso',
   'p2020000-0000-0000-0000-000000000005', 2, 50.00, 20.00, 60.00,
   '2 faldas midi plisadas para Doña Sonia', 'venta 2 faldas midi', '2026-11-03', 'manual', true),
  ('b2222222-2222-2222-2222-222222222222', 'cd222222-2222-2222-2222-111111111111', '30c1bbc8-30f3-4cfe-b250-9db7333487b9', 110.00, 'ingreso',
   'p2020000-0000-0000-0000-000000000002', 1, 110.00, 45.00, 65.00,
   'Jeans rasgado marca Hollister', 'venta jeans americano hollister', '2026-11-03', 'texto', true),

  -- 04 Noviembre (Lunes regular, curva tranquila)
  ('b2222222-2222-2222-2222-222222222222', 'cd222222-2222-2222-2222-111111111111', '30c1bbc8-30f3-4cfe-b250-9db7333487b9', 45.00, 'ingreso',
   'p2020000-0000-0000-0000-000000000001', 1, 45.00, 18.00, 27.00,
   'Blusa negra de vestir', 'venta blusa vestir', '2026-11-04', 'texto', true),
  ('b2222222-2222-2222-2222-222222222222', 'cd222222-2222-2222-2222-111111111111', 'e12d32db-e332-4234-82fc-dcd7b2a7b28e', 35.00, 'egreso',
   null, null, null, null, 0.00,
   'Bolsas plásticas con asa para entrega de ropa', 'bolsas entrega de compras', '2026-11-04', 'manual', true),

  -- 05 Noviembre (Hoy - Excelente volumen)
  ('b2222222-2222-2222-2222-222222222222', 'cd222222-2222-2222-2222-222222222222', '30c1bbc8-30f3-4cfe-b250-9db7333487b9', 250.00, 'ingreso',
   'p2020000-0000-0000-0000-000000000004', 2, 125.00, 55.00, 140.00,
   '2 chaquetas de temporada transferidas por Bi en línea', 'venta 2 chaquetas temporada', '2026-11-05', 'texto', true),
  ('b2222222-2222-2222-2222-222222222222', 'cd222222-2222-2222-2222-111111111111', '30c1bbc8-30f3-4cfe-b250-9db7333487b9', 110.00, 'ingreso',
   'p2020000-0000-0000-0000-000000000002', 1, 110.00, 45.00, 65.00,
   'Pantalón de caballero para don Roberto en efectivo', 'venta pantalon caballero', '2026-11-05', 'manual', true);
