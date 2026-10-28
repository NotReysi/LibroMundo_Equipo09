# 🏛️ Contexto del Proyecto y Arquitectura de Datos — LibroMundo

> **Rol del Documento:** Fuente Única de la Verdad (*Single Source of Truth*) para agentes de IA, arquitectos de datos, ingenieros de BI y desarrolladores que colaboren en el repositorio de **LibroMundo (Caso Retail 9 - Equipo 09)**.

---

## 1. Descripción General del Proyecto (LibroMundo)

### ¿Qué es LibroMundo?
**LibroMundo** es una cadena de librerías especializada en la comercialización de **libros, papelería, juegos de mesa, regalos, material escolar, productos de temporada y eventos culturales**. Opera bajo un esquema omnicanal y multiformato que abarca:
- **Red de sucursales físicas** distribuidas por ciudad y región.
- **Comercio electrónico (e-commerce)**.
- **Ventas institucionales** dirigidas a escuelas y empresas (con esquemas de límite de crédito y descuentos especiales).
- **Comunidad y cultura:** Miembros del club de lectura, preventas editoriales con fecha de lanzamiento y organización de eventos en sucursal.

### Objetivo Macro de Arquitectura
Históricamente, la información operativa de LibroMundo ha estado fragmentada en múltiples sistemas transaccionales aislados (**POS**, **ERP**, **CRM**, **Compras**, **Inventario**, **Marketing**, **Operación** y **Catálogo Editorial**).

El objetivo macro del proyecto es **diseñar, construir y poblar un Data Mart de Ventas empresarial** sobre **MySQL 8.0+** que consolide las operaciones históricas y permita la **toma de decisiones analíticas** (evaluación de margen por tipo de producto, desempeño de preventas, impacto de eventos en sucursal, efectividad de promociones estacionales, tasa de devoluciones y comparativas de rentabilidad intertrimestral), superando las limitaciones de los sistemas OLTP aislados.

---

## 2. Hitos y Decisiones de Arquitectura (Lo que ya hicimos)

A lo largo de las **Unidades 2 y 3**, el equipo de arquitectura definió y validó los cimientos lógicos, dimensionales y analíticos del Data Mart:

### 2.1. Modelo Lógico Entidad-Relación (ER)
Contamos con un **Modelo Lógico ER aprobado** que integra los productos editoriales (con ISBN, autor, editorial, género, idioma y fecha de lanzamiento) junto con los productos no editoriales (identificados por SKU, categoría y marca) bajo una superentidad unificada (`dim_item`), y resuelve explícitamente las **relaciones complejas $N:M$**:
- **Libros con múltiples autores** (`bridge_item_autor`) y **múltiples géneros literarios** (`bridge_item_genero`), incorporando un `factor_asignacion` ponderado $(0 < f \le 1)$ para evitar duplicidad al agregar métricas financieras.
- **Líneas de venta con múltiples promociones estacionales, editoriales o por género** (`bridge_venta_promocion`).
- **Asociación entre transacciones de venta y eventos culturales en sucursal** (`bridge_venta_evento`).

### 2.2. Esquema Estrella (Constelación de Hechos)
El modelo dimensional implementado en el Data Mart (`dm_libromundo` / `lm_bi`) se estructura como una constelación con **tres tablas de hechos** y **dimensiones conformadas**:

* **Tablas de Hechos:**
  1. `FactVentas` (`fact_ventas`): Registra las transacciones comerciales con métricas aditivas calculadas y almacenadas (`cantidad`, `precio_unitario`, `descuento`, `costo_unitario`, `venta_bruta`, `venta_neta`, `costo_total`, `margen`) y el indicador booleano `es_preventa`.
  2. `FactDevoluciones` (`fact_devoluciones`): Registra las devoluciones asociadas a una venta e ítem (`importe_devuelto`, `cantidad_devuelta`, `motivo_devolucion`), permitiendo políticas diferenciadas por tipo de producto y evitando multiplicar filas en `FactVentas`.
  3. `FactEventos` (`fact_eventos`): Registra la ejecución de eventos culturales por sucursal y fecha, incluyendo métricas de desempeño (`asistentes_registrados`, `costo_evento`).

* **Dimensiones Conformadas y Específicas:**
  - `DimFecha` (`dim_fecha`): Calendario analítico compartido por ventas, devoluciones y eventos (`fecha_key`, `dia`, `semana`, `mes`, `trimestre`, `anio`, `es_fin_semana`).
  - `DimSucursal` (`dim_sucursal`): Dimensión geográfica conformada entre los tres procesos de negocio (`sucursal_id`, `nombre`, `ciudad`, `region`).
  - `DimItem` (`dim_item`): Catálogo unificado con restricción `CHECK` que distingue entre `'LIBRO'` (exige `isbn`) y `'PRODUCTO_NO_EDITORIAL'` (exige `sku`).
  - `DimCliente` (`dim_cliente`): Incluye clientes finales, institucionales y el registro semilla `cliente_id = -1` (*"Cliente no identificado"*) para ventas de mostrador anónimas.
  - `DimCanal` (`dim_canal`), `DimTemporada` (`dim_temporada`), `DimPromocion` (`dim_promocion`), `DimEvento` (`dim_evento`), `DimAutor` (`dim_autor`) y `DimGenero` (`dim_genero`).

### 2.3. Definición Inmutable del Grano

> [!IMPORTANT]
> **Definición del Grano Principal:**
> **El grano de `FactVentas` es un ítem vendido dentro de una transacción.**
> *(Asegurado físicamente mediante la restricción única compuesta `UNIQUE (venta_id, item_key)` / línea de detalle de venta).*

* **Grano de `FactDevoluciones`:** Un registro de devolución de un ítem asociado a una transacción de venta original.
* **Grano de `FactEventos`:** Un evento cultural realizado en una sucursal y fecha determinadas (`UNIQUE (evento_key, fecha_key, sucursal_key)`).

### 2.4. Decisiones Clave de Diseño y Reglas de Negocio
- **La preventa es una condición analítica, NO un canal:** Aunque la narrativa inicial del negocio mencionaba la preventa junto a los canales, arquitectónicamente una preventa ocurre *a través* de un canal (Tienda o E-commerce). Por ello, `DimCanal` solo aloja canales reales de contacto y la preventa se modela mediante el atributo booleano `es_preventa` en `FactVentas` apoyado por `fecha_lanzamiento` en `DimItem`.
- **Medición de eventos sin asumir causalidad directa rígida:** Los eventos en sucursal miden su impacto en ventas a través de la tabla puente `bridge_venta_evento` (distinguiendo entre relación `'DIRECTA'` y `'ASOCIADA_TEMPORAL'`) y por correlación espacio-temporal (`DimSucursal` + `DimFecha`), sin forzar una clave foránea en `FactVentas` que obligue a asumir causalidad directa en cada ticket.
- **Prevención de Fan Trap / Chasm Trap en SQL Analítico:** Las devoluciones se pre-agregan en CTEs independientes antes de cruzar con las ventas, y las tablas puente (`bridge_*`) solo se invocan cuando el análisis requiere desglose por autor, género, promoción o evento.

---

## 3. Objetivo Actual (Laboratorio 4: Flujo ETL)

Nuestra meta en la etapa actual (**Unidad 4 / Laboratorio 4**) es **construir una tubería ETL (*Extract, Transform, Load*) reproducible e idempotente en MySQL 8.0+ puro**, capaz de ingerir los archivos crudos del ecosistema LibroMundo, auditar su calidad, limpiar anomalías y poblar el Data Mart analítico registrando cada corrida en `etl_log` / `etl_auditoria`.

### Fases Inmutables del Pipeline ETL

1. **Perfilado de Datos Crudos (*Data Profiling*):**
   - Inspección de cardinalidades, conteo de registros por fuente, detección de claves primarias o de negocio repetidas (`venta_id`, `cliente_id`, `producto_id`), formatos de fecha heterogéneos, estados/regiones no estandarizados, valores nulos y montos/cantidades no positivos ($\le 0$).
2. **Staging (`raw_` y `stg_`):**
   - **`raw_*` (Zona de aterrizaje inmutable):** Ingesta fiel 1:1 de los archivos `.csv` de origen sin alterar su contenido.
   - **`stg_*` (Zona de transformación y limpieza):** Tablas intermedias donde se aplican reglas de tipado, deduplicación y estandarización.
3. **Normalización:**
   - Estandarización de catálogos geográficos (ciudades, estados y regiones mediante catálogos canónicos), homologación de cadenas de texto (`TRIM`, `UPPER`), banderas booleanas y conversión de fechas en múltiples formatos (`YYYY-MM-DD`, `DD/MM/YYYY`) al tipo nativo `DATE` / `DATETIME`.
4. **Validación y Rechazos (*Data Quality & Quarantine*):**
   - Verificación de integridad referencial (ej. ventas o devoluciones que apuntan a un cliente, sucursal o producto inexistente), fechas válidas, importes y cantidades mayores a cero, y detección de duplicados.
   - **Separación de basura:** Todo registro inválido se desvía a tablas de rechazo/cuarentena documentando explícitamente el **motivo de rechazo**, sin contaminar el esquema estrella.
5. **Carga Incremental (*Idempotent Load*):**
   - Poblado de dimensiones (`dim_*`) y tablas de hechos (`fact_*`) utilizando **UPSERT (`INSERT ... ON DUPLICATE KEY UPDATE`) respaldado por claves de negocio estables**.
   - **Idempotencia garantizada:** Re-ejecutar el pipeline sin añadir nuevos registros en el origen debe mantener inalterado el conteo y los totales en las tablas de hechos.
6. **Conciliación y Auditoría:**
   - Cuadre aritmético y documental entre `filas_leidas` (en `raw_*`), `filas_cargadas` (registros únicos válidos en `dim_*` / `fact_*`) y `filas_rechazadas`, junto con la conciliación de importes monetarios entre Staging y el Data Mart, dejando trazabilidad completa en la bitácora (`etl_log` / `etl_auditoria`).

> [!CAUTION]
> **RESTRICCIÓN CRÍTICA DE ARQUITECTURA E INTEGRIDAD:**
> **Está estrictamente prohibido modificar los archivos `.csv` originales a mano** (ni en Excel, ni con editores de texto, ni con scripts externos previos a la base de datos). Los archivos dentro de `LibroMundo/ALUMNO/RAW/` contienen errores de calidad intencionales y deben permanecer 100% intactos; **toda limpieza, normalización, deduplicación y filtrado de rechazos debe ocurrir exclusivamente dentro del flujo SQL (capas `raw_` $\rightarrow$ `stg_` $\rightarrow$ Rechazos $\rightarrow$ Data Mart).**

---

## 4. Estructura del Repositorio

A continuación se documenta el árbol de directorios de referencia para localizar la documentación de negocio, el diccionario de datos, el script base de auditoría y cada uno de los archivos fuente por sistema transaccional (`COMPRAS`, `CRM`, `ERP`, `ESPECIFICO`, `INVENTARIO`, `MARKETING`, `OPERACION` y `POS`):

```plaintext
📁 Contexto/
  📄 09_LibroMundo_Caso_Retail_U2.pdf
  📄 actividad_unidad_3_sql_con_ia_alu...docx
  📄 laboratorio_unidad_4.docx
📁 LibroMundo/
  📁 ALUMNO/
    📁 DOCS/
      📊 diccionario_fuentes_raw.csv
      📄 README_ALUMNO.md
    📁 RAW/
      📁 COMPRAS/ (ordenes_compra.csv)
      📁 CRM/ (clientes.csv)
      📁 ERP/ (productos.csv, proveedores.csv)
      📁 ESPECIFICO/ (catalogo_editorial.csv)
      📁 INVENTARIO/ (existencias.csv)
      📁 MARKETING/ (promociones.csv)
      📁 OPERACION/ (sucursales.csv)
      📁 POS/ (detalle_ventas.csv, devoluciones.csv, ventas.csv)
    📁 SQL_BASE/
      🗄️ 00_crear_bd_y_log.sql
  📄 MANIFEST.json
```

### Mapa Rápido de Fuentes Crudas (`LibroMundo/ALUMNO/RAW/`)

| Sistema Origen | Archivo CSV | Clave Natural / Grano en Origen | Volumetría de Referencia (`MANIFEST.json`) | Destino Principal en Data Mart |
| :--- | :--- | :--- | :---: | :--- |
| **ERP** | `productos.csv` | `producto_id` (`LM-P...`) | $1,420$ | `dim_item` |
| **ERP** | `proveedores.csv` | `proveedor_id` (`LM-PR...`) | $170$ | Catálogo operativo / Compras |
| **ESPECIFICO** | `catalogo_editorial.csv` | `producto_id` + `isbn` | — | `dim_item`, `dim_autor`, `bridge_item_autor` |
| **CRM** | `clientes.csv` | `cliente_id` (`LM-C...`) | $11,400$ | `dim_cliente` |
| **OPERACION** | `sucursales.csv` | `sucursal_id` (`LM-S...`) | $17$ | `dim_sucursal` |
| **MARKETING** | `promociones.csv` | `promocion_id` (`LM-PROM...`) | — | `dim_promocion`, `bridge_venta_promocion` |
| **POS** | `ventas.csv` | `venta_id` (`LM-V...`) | $145,000$ | Cabecera transaccional $\rightarrow$ `fact_ventas`, `dim_canal`, `dim_fecha` |
| **POS** | `detalle_ventas.csv` | `venta_id` + `linea` (`producto_id`) | $343,281$ | **`fact_ventas`** (Grano: ítem por transacción) |
| **POS** | `devoluciones.csv` | `devolucion_id` (`LM-D...`) | $10,298$ | `fact_devoluciones` |
| **INVENTARIO** | `existencias.csv` | `sucursal_id` + `producto_id` | $24,140$ | Control de stock y punto de reorden |
| **COMPRAS** | `ordenes_compra.csv` | `orden_id` (`LM-OC...`) | $13,500$ | Abastecimiento y lead time |
