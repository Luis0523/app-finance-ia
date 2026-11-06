/**
 * FIA — Finanzas IA
 * Panel de Control Financiero (Web Vanilla JS)
 * Conexión directa a Supabase REST API
 */

(function () {
  'use strict';

  // Estado Global
  const state = {
    negocios: [],
    selectedNegocio: null,
    transacciones: [],
    productos: [],
    filtroTransaccion: 'todos',
    charts: {
      flujo: null,
      categoria: null
    }
  };

  // Metadatos de presentación de los emprendimientos
  const emprendimientosInfo = {
    'Glow & Glam MakeUp': {
      avatarClass: 'makeup',
      shortIcon: 'M',
      propietaria: 'Sofía — Venta de Maquillaje y Cosméticos',
      descripcion: 'Venta de maquillaje, cosméticos y productos de cuidado facial'
    },
    'Ropa Americana Lucía': {
      avatarClass: 'clothes',
      shortIcon: 'R',
      propietaria: 'Lucía — Ropa Americana Seleccionada',
      descripcion: 'Venta de ropa americana seleccionada, jeans y prendas de temporada'
    },
    'Tienda de Doña María': {
      avatarClass: 'store',
      shortIcon: 'T',
      propietaria: 'Doña María — Abarrotes',
      descripcion: 'Tienda de barrio y productos de primera necesidad'
    }
  };

  // Clientes API Supabase
  const api = {
    async get(endpoint, customHeaders = {}) {
      const url = `${window.CONFIG.SUPABASE_URL}/rest/v1/${endpoint}`;
      const headers = {
        'apikey': window.CONFIG.SUPABASE_ANON_KEY,
        'Authorization': `Bearer ${window.CONFIG.SUPABASE_ANON_KEY}`,
        'Content-Type': 'application/json',
        ...customHeaders
      };
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 3500);
      try {
        const resp = await fetch(url, { headers, signal: controller.signal });
        clearTimeout(timeoutId);
        if (!resp.ok) {
          throw new Error(`HTTP Error ${resp.status} al consultar ${endpoint}`);
        }
        return await resp.json();
      } catch (err) {
        clearTimeout(timeoutId);
        throw err;
      }
    }
  };

  // Inicialización
  async function init() {
    bindEvents();
    await cargarNegocios();
  }

  function bindEvents() {
    // Botón refrescar
    const btnRefresh = document.getElementById('btnRefresh');
    if (btnRefresh) {
      btnRefresh.addEventListener('click', async () => {
        btnRefresh.textContent = 'Actualizando...';
        await recargarDatosNegocio();
        btnRefresh.textContent = 'Actualizar';
      });
    }

    // Filtros de tabla
    document.querySelectorAll('.filter-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
        e.target.classList.add('active');
        state.filtroTransaccion = e.target.dataset.filter;
        renderTablaTransacciones();
      });
    });

    // Menú de navegación
    document.querySelectorAll('.nav-menu li').forEach(item => {
      item.addEventListener('click', () => {
        document.querySelectorAll('.nav-menu li').forEach(li => li.classList.remove('active'));
        item.classList.add('active');
      });
    });
  }

  // Carga de Negocios
  async function cargarNegocios() {
    const selectorContainer = document.getElementById('businessSelector');
    const dbInfo = document.getElementById('dbInfoText');

    try {
      dbInfo.textContent = 'Consultando Supabase...';
      let negocios = await api.get('negocios?select=*&order=creado_en.asc');

      // Si aún no se corrió el SQL en Supabase, combinar con los emprendimientos simulados
      const nombresEnDB = negocios.map(n => n.nombre);
      const simuladosFaltantes = (window.MOCK_DATA?.negocios || []).filter(m => !nombresEnDB.includes(m.nombre));

      if (simuladosFaltantes.length > 0) {
        dbInfo.textContent = `${negocios.length} en DB + ${simuladosFaltantes.length} simulados`;
        negocios = [...simuladosFaltantes, ...negocios];
      } else {
        dbInfo.textContent = `${negocios.length} negocio(s) en Supabase`;
      }

      state.negocios = negocios;

      selectorContainer.innerHTML = '';
      negocios.forEach((negocio, index) => {
        const info = emprendimientosInfo[negocio.nombre] || {
          avatarClass: 'store',
          shortIcon: negocio.nombre.charAt(0).toUpperCase(),
          propietaria: negocio.rubro || 'Negocio'
        };

        const card = document.createElement('div');
        card.className = `business-card-select ${index === 0 ? 'active' : ''}`;
        card.dataset.id = negocio.id;
        card.innerHTML = `
          <div class="business-avatar ${info.avatarClass}">
            ${info.shortIcon}
          </div>
          <div class="business-info-select">
            <h4>${escapeHtml(negocio.nombre)}</h4>
            <p>${escapeHtml(negocio.rubro || 'Emprendimiento')}</p>
          </div>
        `;

        card.addEventListener('click', () => {
          document.querySelectorAll('.business-card-select').forEach(c => c.classList.remove('active'));
          card.classList.add('active');
          seleccionarNegocio(negocio);
        });

        selectorContainer.appendChild(card);
      });

      if (negocios.length > 0) {
        await seleccionarNegocio(negocios[0]);
      }

    } catch (err) {
      console.warn('Conexión con Supabase lenta o restringida por RLS. Usando datos preparados:', err);
      dbInfo.textContent = 'Datos Simulados';
      const fallbackNegocios = window.MOCK_DATA?.negocios || [];
      state.negocios = fallbackNegocios;

      selectorContainer.innerHTML = '';
      fallbackNegocios.forEach((negocio, index) => {
        const info = emprendimientosInfo[negocio.nombre] || {
          avatarClass: 'store',
          shortIcon: negocio.nombre.charAt(0).toUpperCase()
        };
        const card = document.createElement('div');
        card.className = `business-card-select ${index === 0 ? 'active' : ''}`;
        card.dataset.id = negocio.id;
        card.innerHTML = `
          <div class="business-avatar ${info.avatarClass}">
            ${info.shortIcon}
          </div>
          <div class="business-info-select">
            <h4>${escapeHtml(negocio.nombre)}</h4>
            <p>${escapeHtml(negocio.rubro)}</p>
          </div>
        `;
        card.addEventListener('click', () => {
          document.querySelectorAll('.business-card-select').forEach(c => c.classList.remove('active'));
          card.classList.add('active');
          seleccionarNegocio(negocio);
        });
        selectorContainer.appendChild(card);
      });

      if (fallbackNegocios.length > 0) {
        await seleccionarNegocio(fallbackNegocios[0]);
      }
    }
  }

  async function seleccionarNegocio(negocio) {
    state.selectedNegocio = negocio;

    // Header info
    document.getElementById('currentBusinessName').textContent = negocio.nombre;
    const info = emprendimientosInfo[negocio.nombre] || {
      descripcion: negocio.rubro || 'Control y registro de finanzas'
    };
    document.getElementById('currentBusinessDescription').textContent = info.descripcion;

    await recargarDatosNegocio();
  }

  async function recargarDatosNegocio() {
    if (!state.selectedNegocio) return;
    const nid = state.selectedNegocio.id;

    try {
      // 1. Obtener Transacciones con x-negocio-id
      let transacciones = [];
      try {
        transacciones = await api.get(
          `transacciones?select=*&negocio_id=eq.${nid}&order=fecha.desc,creado_en.desc`,
          { 'x-negocio-id': nid }
        );
      } catch (e) {
        console.warn('Consulta transacciones Supabase:', e);
      }

      // Si no hay en DB y hay en MOCK_DATA, usar mock
      if ((!transacciones || transacciones.length === 0) && window.MOCK_DATA?.transacciones[nid]) {
        transacciones = window.MOCK_DATA.transacciones[nid];
      }
      state.transacciones = transacciones || [];

      // 2. Obtener Productos
      let productos = [];
      try {
        productos = await api.get(
          `productos?select=*&negocio_id=eq.${nid}&order=nombre.asc`,
          { 'x-negocio-id': nid }
        );
      } catch (e) {
        console.warn('Consulta productos Supabase:', e);
      }

      if ((!productos || productos.length === 0) && window.MOCK_DATA?.productos[nid]) {
        productos = window.MOCK_DATA.productos[nid];
      }
      state.productos = productos || [];

      // Renderizar Vistas
      renderKPIs();
      renderGraficoFlujo();
      renderGraficoCategorias();
      renderTablaTransacciones();
      renderCatalogo();

    } catch (err) {
      console.error('Error al recargar datos del negocio:', err);
    }
  }

  // Renderizado de KPIs
  function renderKPIs() {
    const txs = state.transacciones;
    let totalIngresos = 0;
    let totalEgresos = 0;
    let countVentas = 0;
    let countGastos = 0;

    txs.forEach(t => {
      const monto = parseFloat(t.monto) || 0;
      if (t.tipo === 'ingreso') {
        totalIngresos += monto;
        countVentas++;
      } else {
        totalEgresos += monto;
        countGastos++;
      }
    });

    const gananciaNeta = totalIngresos - totalEgresos;
    const margen = totalIngresos > 0 ? ((gananciaNeta / totalIngresos) * 100).toFixed(1) : 0;
    const ticketPromedio = countVentas > 0 ? (totalIngresos / countVentas).toFixed(2) : '0.00';

    document.getElementById('kpiIngresos').textContent = `Q ${totalIngresos.toFixed(2)}`;
    document.getElementById('kpiVentasCount').textContent = `${countVentas} ventas`;

    document.getElementById('kpiEgresos').textContent = `Q ${totalEgresos.toFixed(2)}`;
    document.getElementById('kpiGastosCount').textContent = `${countGastos} compras/gastos`;

    document.getElementById('kpiGananciaNeta').textContent = `Q ${gananciaNeta.toFixed(2)}`;
    document.getElementById('kpiMargen').textContent = `${margen}%`;

    document.getElementById('kpiTicketPromedio').textContent = `Q ${ticketPromedio}`;
  }

  // Gráfico Diario de Ventas vs Gastos
  function renderGraficoFlujo() {
    const canvas = document.getElementById('flujoChart');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');

    const dias = ['2026-10-31', '2026-11-01', '2026-11-02', '2026-11-03', '2026-11-04', '2026-11-05'];
    const etiquetas = ['31 Oct (Inicio)', '01 Nov', '02 Nov', '03 Nov', '04 Nov', '05 Nov (Hoy)'];

    const ingresosPorDia = { '2026-10-31': 0, '2026-11-01': 0, '2026-11-02': 0, '2026-11-03': 0, '2026-11-04': 0, '2026-11-05': 0 };
    const egresosPorDia = { '2026-10-31': 0, '2026-11-01': 0, '2026-11-02': 0, '2026-11-03': 0, '2026-11-04': 0, '2026-11-05': 0 };

    state.transacciones.forEach(t => {
      const fecha = t.fecha;
      const monto = parseFloat(t.monto) || 0;
      if (ingresosPorDia.hasOwnProperty(fecha)) {
        if (t.tipo === 'ingreso') {
          ingresosPorDia[fecha] += monto;
        } else {
          egresosPorDia[fecha] += monto;
        }
      }
    });

    const dataIngresos = dias.map(d => ingresosPorDia[d]);
    const dataEgresos = dias.map(d => egresosPorDia[d]);

    if (state.charts.flujo) {
      state.charts.flujo.destroy();
    }

    state.charts.flujo = new Chart(ctx, {
      type: 'line',
      data: {
        labels: etiquetas,
        datasets: [
          {
            label: 'Ventas (Q)',
            data: dataIngresos,
            borderColor: '#6366F1',
            backgroundColor: 'rgba(99, 102, 241, 0.12)',
            tension: 0.3,
            fill: true,
            borderWidth: 2.5,
            pointBackgroundColor: '#6366F1',
            pointRadius: 4,
            pointHoverRadius: 6
          },
          {
            label: 'Gastos (Q)',
            data: dataEgresos,
            borderColor: '#EF4444',
            backgroundColor: 'transparent',
            tension: 0.3,
            fill: false,
            borderWidth: 2,
            borderDash: [4, 4],
            pointBackgroundColor: '#EF4444',
            pointRadius: 3.5
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: '#1E293B',
            titleColor: '#F8FAFC',
            bodyColor: '#E2E8F0',
            borderColor: '#334155',
            borderWidth: 1,
            padding: 10,
            callbacks: {
              label: (context) => ` ${context.dataset.label}: Q ${context.parsed.y.toFixed(2)}`
            }
          }
        },
        scales: {
          x: {
            grid: { color: 'rgba(255, 255, 255, 0.05)' },
            ticks: { color: '#94A3B8', font: { size: 11 } }
          },
          y: {
            grid: { color: 'rgba(255, 255, 255, 0.05)' },
            ticks: {
              color: '#94A3B8',
              font: { size: 11 },
              callback: (val) => `Q ${val}`
            }
          }
        }
      }
    });
  }

  // Gráfico Donut
  function renderGraficoCategorias() {
    const canvas = document.getElementById('categoriaChart');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');

    const ventasPorProducto = {};
    state.transacciones.filter(t => t.tipo === 'ingreso').forEach(t => {
      const nombre = t.descripcion_normalizada || t.descripcion_original || 'Venta';
      const cleanNombre = nombre.replace(/^venta\s+/i, '');
      const short = cleanNombre.charAt(0).toUpperCase() + cleanNombre.slice(1, 22);
      ventasPorProducto[short] = (ventasPorProducto[short] || 0) + parseFloat(t.monto);
    });

    const labels = Object.keys(ventasPorProducto);
    const data = Object.values(ventasPorProducto);

    if (state.charts.categoria) {
      state.charts.categoria.destroy();
    }

    const palette = ['#6366F1', '#EC4899', '#10B981', '#F59E0B', '#0EA5E9', '#8B5CF6'];

    state.charts.categoria = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: labels.length ? labels : ['Sin ventas'],
        datasets: [{
          data: data.length ? data : [1],
          backgroundColor: labels.length ? palette.slice(0, labels.length) : ['#334155'],
          borderWidth: 0,
          hoverOffset: 4
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: '70%',
        plugins: {
          legend: {
            position: 'bottom',
            labels: {
              color: '#94A3B8',
              font: { size: 11 },
              boxWidth: 8,
              padding: 10
            }
          },
          tooltip: {
            callbacks: {
              label: (context) => ` Q ${context.parsed.toFixed(2)}`
            }
          }
        }
      }
    });
  }

  // Tabla de Transacciones
  function renderTablaTransacciones() {
    const tbody = document.getElementById('tablaBody');
    if (!tbody) return;

    let txs = state.transacciones;
    if (state.filtroTransaccion !== 'todos') {
      txs = txs.filter(t => t.tipo === state.filtroTransaccion);
    }

    if (txs.length === 0) {
      tbody.innerHTML = '<tr><td colspan="7" class="loading-td">No hay transacciones registradas para este filtro.</td></tr>';
      return;
    }

    tbody.innerHTML = txs.map(t => {
      const esIngreso = t.tipo === 'ingreso';
      const badgeClass = esIngreso ? 'ingreso' : 'egreso';
      const badgeText = esIngreso ? 'Venta' : 'Gasto';
      const montoSign = esIngreso ? '+' : '-';
      const utilidad = t.utilidad_calculada ? `Q ${parseFloat(t.utilidad_calculada).toFixed(2)}` : '—';
      const cantidad = t.cantidad ? t.cantidad : '1';

      return `
        <tr>
          <td><strong style="color:#CBD5E1;">${t.fecha}</strong></td>
          <td><span class="badge-tag ${badgeClass}">${badgeText}</span></td>
          <td>${escapeHtml(t.descripcion_original || t.descripcion_normalizada || 'Transacción')}</td>
          <td><span style="color:#94A3B8;font-size:12px;">${t.origen || 'manual'}</span></td>
          <td>${cantidad}</td>
          <td><strong style="color:${esIngreso ? '#34D399' : '#F87171'};">${montoSign} Q ${parseFloat(t.monto).toFixed(2)}</strong></td>
          <td><span style="color:#818CF8;font-weight:600;">${utilidad}</span></td>
        </tr>
      `;
    }).join('');
  }

  // Catálogo de Productos
  function renderCatalogo() {
    const grid = document.getElementById('catalogoGrid');
    if (!grid) return;

    if (state.productos.length === 0) {
      grid.innerHTML = '<p style="color:#94A3B8;grid-column:1/-1;">No hay productos registrados en el catálogo.</p>';
      return;
    }

    grid.innerHTML = state.productos.map(p => {
      const pVenta = parseFloat(p.precio_venta || 0);
      const pCompra = parseFloat(p.precio_compra || 0);
      const margenUni = pVenta - pCompra;
      const margenPorc = pVenta > 0 ? ((margenUni / pVenta) * 100).toFixed(0) : 0;

      return `
        <div class="product-item-card">
          <div>
            <div class="product-item-title">${escapeHtml(p.nombre)}</div>
            <div class="product-price-row">
              <span>Precio Venta:</span>
              <strong>Q ${pVenta.toFixed(2)}</strong>
            </div>
            <div class="product-price-row">
              <span>Costo Compra:</span>
              <span>Q ${pCompra.toFixed(2)}</span>
            </div>
            <div class="product-price-row">
              <span>Margen Ganancia:</span>
              <span style="color:#34D399;font-weight:600;">Q ${margenUni.toFixed(2)} (${margenPorc}%)</span>
            </div>
          </div>
          <div>
            <span class="product-stock-tag">
              Stock Mínimo: ${p.stock_minimo || 0} unidades
            </span>
          </div>
        </div>
      `;
    }).join('');
  }

  function escapeHtml(str) {
    if (!str) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
