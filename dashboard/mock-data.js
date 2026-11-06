/**
 * Mock Data de respaldo automático para visualización inmediata
 * En caso de que aún no se haya ejecutado el script SQL en Supabase,
 * el dashboard muestra estos datos idénticos a los del script.
 */
window.MOCK_DATA = {
  negocios: [
    {
      id: 'b1111111-1111-1111-1111-111111111111',
      nombre: 'Glow & Glam MakeUp',
      rubro: 'Cosméticos y Maquillaje',
      regimen_tributario: 'pequeño contribuyente',
      creado_en: '2026-10-31T08:00:00Z'
    },
    {
      id: 'b2222222-2222-2222-2222-222222222222',
      nombre: 'Ropa Americana Lucía',
      rubro: 'Ropa y Moda Americana',
      regimen_tributario: 'pequeño contribuyente',
      creado_en: '2026-10-31T08:30:00Z'
    }
  ],
  productos: {
    'b1111111-1111-1111-1111-111111111111': [
      { id: 'p1', nombre: 'Labial Mate Larga Duración', precio_compra: 22, precio_venta: 45, stock_minimo: 5 },
      { id: 'p2', nombre: 'Paleta de Sombras Nude 12 Colores', precio_compra: 45, precio_venta: 95, stock_minimo: 3 },
      { id: 'p3', nombre: 'Base Líquida Cobertura Media', precio_compra: 35, precio_venta: 75, stock_minimo: 4 },
      { id: 'p4', nombre: 'Rímel A prueba de Agua Extra Volumen', precio_compra: 20, precio_venta: 40, stock_minimo: 6 },
      { id: 'p5', nombre: 'Polvo Compacto Traslúcido', precio_compra: 25, precio_venta: 50, stock_minimo: 4 },
      { id: 'p6', nombre: 'Set de Brochas Profesionales x8', precio_compra: 50, precio_venta: 110, stock_minimo: 2 }
    ],
    'b2222222-2222-2222-2222-222222222222': [
      { id: 'p11', nombre: 'Blusa Casual Premium', precio_compra: 18, precio_venta: 45, stock_minimo: 8 },
      { id: 'p12', nombre: 'Pantalón Jeans Americano Levi/AE', precio_compra: 45, precio_venta: 110, stock_minimo: 5 },
      { id: 'p13', nombre: 'Vestido de Verano Estampado', precio_compra: 28, precio_venta: 65, stock_minimo: 4 },
      { id: 'p14', nombre: 'Chaqueta Denim / Suéter Ligero', precio_compra: 55, precio_venta: 125, stock_minimo: 3 },
      { id: 'p15', nombre: 'Falda Midi Plisada', precio_compra: 20, precio_venta: 50, stock_minimo: 4 }
    ]
  },
  transacciones: {
    'b1111111-1111-1111-1111-111111111111': [
      { fecha: '2026-10-31', tipo: 'ingreso', monto: 45.00, cantidad: 1, utilidad_calculada: 23.00, descripcion_original: 'Venta de labial mate tono rosa', origen: 'manual' },
      { fecha: '2026-10-31', tipo: 'egreso', monto: 30.00, cantidad: null, utilidad_calculada: 0.00, descripcion_original: 'Bolsitas de regalo y papel de seda', origen: 'manual' },
      { fecha: '2026-11-01', tipo: 'ingreso', monto: 40.00, cantidad: 1, utilidad_calculada: 20.00, descripcion_original: 'Un rímel contra agua para una vecina', origen: 'texto' },
      { fecha: '2026-11-02', tipo: 'ingreso', monto: 170.00, cantidad: 2, utilidad_calculada: 100.00, descripcion_original: '2 bases líquidas transferidas por banca virtual', origen: 'texto' },
      { fecha: '2026-11-02', tipo: 'ingreso', monto: 95.00, cantidad: 1, utilidad_calculada: 50.00, descripcion_original: 'Paleta de sombras para regalo de cumpleaños', origen: 'manual' },
      { fecha: '2026-11-03', tipo: 'ingreso', monto: 245.00, cantidad: 1, utilidad_calculada: 60.00, descripcion_original: 'Set de brochas profesionales + polvo traslúcido y labial', origen: 'texto' },
      { fecha: '2026-11-03', tipo: 'ingreso', monto: 90.00, cantidad: 2, utilidad_calculada: 46.00, descripcion_original: '2 labiales mate rojo cereza y nude', origen: 'manual' },
      { fecha: '2026-11-03', tipo: 'egreso', monto: 50.00, cantidad: null, utilidad_calculada: 0.00, descripcion_original: 'Publicidad en Instagram y TikTok para la semana', origen: 'manual' },
      { fecha: '2026-11-04', tipo: 'ingreso', monto: 50.00, cantidad: 1, utilidad_calculada: 25.00, descripcion_original: 'Polvo traslúcido tono 2', origen: 'texto' },
      { fecha: '2026-11-04', tipo: 'egreso', monto: 25.00, cantidad: null, utilidad_calculada: 0.00, descripcion_original: 'Envío mensajería en moto a zona 10', origen: 'manual' },
      { fecha: '2026-11-05', tipo: 'ingreso', monto: 190.00, cantidad: 2, utilidad_calculada: 100.00, descripcion_original: '2 paletas de sombras pedido express', origen: 'texto' },
      { fecha: '2026-11-05', tipo: 'ingreso', monto: 115.00, cantidad: 1, utilidad_calculada: 40.00, descripcion_original: 'Base líquida + rímel volumen', origen: 'manual' }
    ],
    'b2222222-2222-2222-2222-222222222222': [
      { fecha: '2026-10-31', tipo: 'ingreso', monto: 45.00, cantidad: 1, utilidad_calculada: 27.00, descripcion_original: 'Blusa blanca bordada de paca americana', origen: 'manual' },
      { fecha: '2026-10-31', tipo: 'egreso', monto: 80.00, cantidad: null, utilidad_calculada: 0.00, descripcion_original: 'Ganchos de plástico para ropa y etiquetas de precio', origen: 'manual' },
      { fecha: '2026-11-01', tipo: 'ingreso', monto: 220.00, cantidad: 2, utilidad_calculada: 130.00, descripcion_original: '2 pantalones Jeans Levi Strauss originales', origen: 'manual' },
      { fecha: '2026-11-01', tipo: 'ingreso', monto: 65.00, cantidad: 1, utilidad_calculada: 37.00, descripcion_original: 'Vestido floreado de verano talla M', origen: 'texto' },
      { fecha: '2026-11-02', tipo: 'ingreso', monto: 180.00, cantidad: 4, utilidad_calculada: 108.00, descripcion_original: '4 blusas surtidas promoción de fin de semana', origen: 'manual' },
      { fecha: '2026-11-02', tipo: 'ingreso', monto: 125.00, cantidad: 1, utilidad_calculada: 70.00, descripcion_original: 'Chaqueta de mezclilla American Eagle transferida por BI', origen: 'texto' },
      { fecha: '2026-11-02', tipo: 'egreso', monto: 40.00, cantidad: null, utilidad_calculada: 0.00, descripcion_original: 'Pago de luz del local de ropa', origen: 'manual' },
      { fecha: '2026-11-03', tipo: 'ingreso', monto: 100.00, cantidad: 2, utilidad_calculada: 60.00, descripcion_original: '2 faldas midi plisadas para Doña Sonia', origen: 'manual' },
      { fecha: '2026-11-03', tipo: 'ingreso', monto: 110.00, cantidad: 1, utilidad_calculada: 65.00, descripcion_original: 'Jeans rasgado marca Hollister', origen: 'texto' },
      { fecha: '2026-11-04', tipo: 'ingreso', monto: 45.00, cantidad: 1, utilidad_calculada: 27.00, descripcion_original: 'Blusa negra de vestir', origen: 'texto' },
      { fecha: '2026-11-04', tipo: 'egreso', monto: 35.00, cantidad: null, utilidad_calculada: 0.00, descripcion_original: 'Bolsas plásticas con asa para entrega de ropa', origen: 'manual' },
      { fecha: '2026-11-05', tipo: 'ingreso', monto: 250.00, cantidad: 2, utilidad_calculada: 140.00, descripcion_original: '2 chaquetas de temporada transferidas por Bi en línea', origen: 'texto' },
      { fecha: '2026-11-05', tipo: 'ingreso', monto: 110.00, cantidad: 1, utilidad_calculada: 65.00, descripcion_original: 'Pantalón de caballero para don Roberto en efectivo', origen: 'manual' }
    ]
  }
};
