# DataFlow — Pipeline de Monitoreo de Calidad del Aire

Pipeline de datos end-to-end construido como proyecto integrador. Integra base de datos relacional, proceso ETL, almacenamiento en MongoDB y modelos predictivos sobre datos de calidad del aire en Bogotá, Medellín y Cali.

---

## Dominio

Red de sensores ambientales que registra métricas horarias de cinco contaminantes (PM2.5, PM10, NO₂, O₃, CO) en 15 estaciones distribuidas en tres ciudades colombianas. El pipeline transforma 327,600 lecturas crudas en documentos diarios enriquecidos y predice el Índice de Calidad del Aire (ICA) del día siguiente.

---

## Flujo del pipeline

```
Supabase (PostgreSQL)
       │
       │  mediciones_raw + clima_diario
       ▼
   ETL (Python — Google Colab)
   ├── Limpieza: outliers y nulos
   ├── Cálculo ICA (breakpoints IDEAM)
   ├── Agregación diaria por estación
   └── Features ML: lag1, lag7, media7d
       │
       ▼
  MongoDB Atlas
  ├── resumen_diario (2,730 docs)
  ├── predicciones
  └── log_etl
       │
       ├──────────────────────────────────┐
       ▼                                  ▼
  Modelo 1 — Python (Colab)         Modelo 2 — KNIME
  Random Forest                     Trabajo_final2.knwf
  ├── Regresión ICA numérico        ├── Árbol de Decisión
  └── Clasificación por categoría   └── Gradient Boosted Trees
```

---

## Estructura del repositorio

```
dataflow-aire/
├── datos_sinteticos/
│   ├── ciudades.csv                 # 3 filas
│   ├── estaciones.csv               # 15 filas
│   ├── contaminantes.csv            # 5 filas
│   ├── clima_diario.csv             # 546 filas
│   └── mediciones_raw.csv           # 327,600 filas
├── 01_supabase_ddl.sql              # Esquema relacional completo
├── 03_dml_prueba_v3.sql             # DML con datos de verificación
├── DataFlow_Pipeline_Calidad_Aire_v5.ipynb  # Pipeline completo en Colab
├── Trabajo_final2.knwf              # Flujo KNIME — modelos predictivos
├── modelo_output/
│   ├── modelo_regresion.pkl         # Random Forest regresión
│   ├── modelo_clasificacion.pkl     # Random Forest clasificación
│   └── reporte_metricas.json        # MAE, RMSE, R², AUC
├── .env.example                     # Plantilla de variables de entorno
├── .gitignore
└── README.md
```

---

## Componentes

### 1. Base de datos relacional — Supabase (PostgreSQL)

Cinco tablas normalizadas con integridad referencial y una vista para el ETL:

| Tabla | Descripción | Filas |
|---|---|---|
| `ciudades` | Bogotá, Medellín, Cali | 3 |
| `estaciones` | Puntos de medición (5 por ciudad) | 15 |
| `contaminantes` | Catálogo PM2.5, PM10, NO₂, O₃, CO | 5 |
| `clima_diario` | Variables meteorológicas por ciudad/día | 546 |
| `mediciones_raw` | Lecturas horarias crudas de sensores | 327,600 |
| `v_mediciones_completas` | Vista desnormalizada para el ETL | — |

Los datos sintéticos incluyen intencionalmente 2.5% de nulos (fallos de sensor) y 0.8% de outliers etiquetados con `flag_anomalia = TRUE` para que el ETL tenga trabajo real de limpieza.

Conexión desde Colab vía **Transaction Pooler** (puerto 6543) para compatibilidad con redes IPv4 dinámicas.

### 2. Proceso ETL — Python / Pandas (Google Colab)

El notebook `DataFlow_Pipeline_Calidad_Aire_v5.ipynb` ejecuta el pipeline completo en 6 secciones:

| Sección | Descripción |
|---|---|
| Setup | Credenciales desde Secrets de Colab, montaje de Drive |
| 1 | DDL en Supabase + colecciones en MongoDB |
| 2 | Carga de 5 CSVs desde Drive a Supabase |
| 3 | Limpieza: eliminación de outliers, imputación con media móvil 3h |
| 4 | ETL: agregación diaria, cálculo ICA, carga a MongoDB |
| 5 | Modelo Random Forest (regresión + clasificación) |
| 6 | Evaluación: MAE, RMSE, R², matriz de confusión, curva ROC |

**Transformaciones clave:**
- Eliminación de outliers con `flag_anomalia = TRUE`
- Imputación de nulos con media móvil de 3 horas por estación y contaminante
- Cálculo del ICA diario según fórmula de breakpoints IDEAM con PM2.5 como contaminante crítico
- Agregación diaria: promedio, máximo y mínimo por contaminante
- Generación de features: `ica_lag1`, `ica_lag7`, `ica_media7d`

### 3. MongoDB Atlas

Tres colecciones de destino del ETL. La colección principal `resumen_diario` almacena un documento por estación por día:

```json
{
  "_id": "1_2024-03-15",
  "estacion_id": 1,
  "estacion": "Kennedy",
  "ciudad": "Bogotá",
  "fecha": "2024-03-15",
  "ica_calculado": 87.3,
  "categoria": "Moderado",
  "contaminantes": {
    "PM2_5": { "promedio": 22.4, "maximo": 41.1, "minimo": 8.2 },
    "PM10":  { "promedio": 35.1, "maximo": 68.0, "minimo": 12.0 },
    "NO2":   { "promedio": 18.7, "maximo": 34.2, "minimo": 6.1 }
  },
  "clima": {
    "temperatura_c": 14.5, "humedad_pct": 72.0,
    "lluvia": true, "mm_lluvia": 5.2, "es_festivo": false
  },
  "features_ml": {
    "ica_lag1": 79.0, "ica_lag7": 91.0, "ica_media7d": 84.3
  }
}
```

Índices creados: `estacion_id+fecha` (único), `ciudad_id+fecha`, `ica_calculado`, `categoria`.

### 4. Modelos predictivos

El proyecto implementa **dos enfoques** de modelado que parten de la colección `resumen_diario` de MongoDB:

#### 4.1 Python — Random Forest (Colab)

Implementado en la Sección 5 del notebook. Entrena dos modelos en paralelo:

- **Regresión** — predice el valor numérico del ICA del día siguiente
- **Clasificación** — predice la categoría ICA (Bueno, Moderado, Dañino GS, Dañino, Muy dañino)

**Features (16):** `ica_lag1`, `ica_lag7`, `ica_media7d`, `temperatura`, `humedad`, `viento`, `lluvia`, `mm_lluvia`, `es_festivo`, `pm25`, `pm10`, `no2`, `dia_semana`, `mes`, `es_fin_semana`, `ciudad_cod`.

**Validación:** split temporal 80/20 (sin mezcla de fechas).

| Métrica | Valor |
|---|---|
| MAE | 5.83 pts ICA |
| RMSE | 8.12 pts ICA |
| R² | 0.91 (91% varianza explicada) |
| AUC macro | ~0.94 |

#### 4.2 KNIME — Árbol de Decisión y Gradient Boosted Trees

Flujo: `Trabajo_final2.knwf`

Lee directamente de la colección `resumen_diario` de MongoDB Atlas mediante el conector MongoDB de KNIME e implementa dos modelos comparativos:

**Árbol de Decisión** — modelo interpretable que genera reglas de clasificación explícitas por categoría ICA. Permite visualizar qué combinaciones de features llevan a cada categoría.

**Gradient Boosted Trees** — modelo de ensamble que construye árboles secuenciales corrigiendo errores del anterior. Generalmente supera al árbol simple en precisión a cambio de menor interpretabilidad.

Ambos modelos usan las mismas features que el Random Forest para permitir comparación directa de resultados entre herramientas.

---

## Instalación y ejecución

### Requisitos

- Cuenta en [Supabase](https://supabase.com) (plan free)
- Cuenta en [MongoDB Atlas](https://cloud.mongodb.com) (plan M0 free)
- Google Colab (para el notebook Python)
- KNIME Analytics Platform con conector MongoDB (para `Trabajo_final2.knwf`)

### Paso 1 — Configurar credenciales en Colab

En el panel 🔑 Secrets de Colab agrega:

```
SUPABASE_POOLER_HOST  →  aws-1-us-west-2.pooler.supabase.com
SUPABASE_PASSWORD     →  tu_password
MONGO_URI             →  mongodb+srv://usuario:password@cluster.mongodb.net/
```

### Paso 2 — Subir archivos a Google Drive

Copia estos archivos a `/content/drive/MyDrive/SQL/data/`:
- `01_supabase_ddl.sql`
- `03_dml_prueba_v3.sql`
- Los 5 archivos CSV de `datos_sinteticos/`

### Paso 3 — Ejecutar el notebook

Abre `DataFlow_Pipeline_Calidad_Aire_v5.ipynb` en Colab y ejecuta sección por sección:

1. **Setup** — instala dependencias y monta Drive
2. **Sección 1** — crea tablas en Supabase y colecciones en MongoDB
3. **Sección 2** — carga los 5 CSVs a Supabase (~3 min por mediciones_raw)
4. **Sección 3** — limpieza de datos
5. **Sección 4** — ETL y carga de 2,730 documentos a MongoDB
6. **Sección 5** — entrena modelos Random Forest
7. **Sección 6** — genera métricas, matriz de confusión y curva ROC

### Paso 4 — Ejecutar flujo KNIME

1. Abre KNIME Analytics Platform
2. Importa `Trabajo_final2.knwf`
3. Configura el nodo MongoDB Reader con tu URI de Atlas
4. Ejecuta el flujo completo
5. Compara resultados de Árbol de Decisión vs Gradient Boosted Trees

---

## Consultas de demostración

### SQL (Supabase)

```sql
-- Promedio diario PM2.5 por ciudad
SELECT ciudad, DATE(timestamp) AS fecha,
       ROUND(AVG(valor), 2) AS pm25_promedio
FROM v_mediciones_completas
WHERE contaminante = 'PM2.5' AND valor IS NOT NULL
GROUP BY ciudad, fecha
ORDER BY fecha, ciudad;

-- Estaciones con más outliers
SELECT e.nombre, c.nombre AS ciudad, COUNT(*) AS outliers
FROM mediciones_raw m
JOIN estaciones e ON m.estacion_id = e.estacion_id
JOIN ciudades c ON e.ciudad_id = c.ciudad_id
WHERE m.flag_anomalia = TRUE
GROUP BY e.nombre, c.nombre
ORDER BY outliers DESC;
```

### MongoDB Atlas

```javascript
// ICA promedio por ciudad
db.resumen_diario.aggregate([
  { $group: { _id: "$ciudad", ica_promedio: { $avg: "$ica_calculado" }, docs: { $count: {} } } },
  { $sort: { ica_promedio: -1 } }
])

// Días con lluvia donde el ICA bajó bajo 60
db.resumen_diario.find({
  "clima.lluvia": true,
  "ica_calculado": { $lt: 60 }
}, { ciudad: 1, fecha: 1, ica_calculado: 1, _id: 0 }).limit(10)

// Categoría "Dañino" en Bogotá
db.resumen_diario.find(
  { ciudad: "Bogotá", categoria: "Dañino" },
  { estacion: 1, fecha: 1, ica_calculado: 1, _id: 0 }
)

// Predicciones generadas por el modelo
db.predicciones.find(
  { categoria_predicha: "Moderado" },
  { estacion_id: 1, fecha_prediccion: 1, ica_predicho: 1, _id: 0 }
).limit(5)
```

---

## Diagrama MER

Relaciones:
- `ciudades` 1→N `estaciones`
- `ciudades` 1→N `clima_diario`
- `estaciones` 1→N `mediciones_raw`
- `contaminantes` 1→N `mediciones_raw`

---

## Equipo

| Nombre | Responsabilidad |
|---|---|
| [ Nombre 1 ] | BD relacional — DDL, índices, vista |
| [ Nombre 2 ] | Proceso ETL y limpieza de datos |
| [ Nombre 3 ] | MongoDB — modelado de documentos y consultas |
| [ Nombre 4 ] | Modelos predictivos — Python y KNIME |

**Curso:** Fundamentos de Bases de Datos  
**Semestre:** 2024-1

---

## Decisiones de diseño

**¿Por qué PostgreSQL + MongoDB?** La BD relacional garantiza integridad referencial en los catálogos y permite consultas ad-hoc con SQL. MongoDB almacena documentos diarios desnormalizados optimizados para lectura directa por los modelos, sin JOINs. Cada tecnología cumple un rol diferente en el pipeline.

**¿Por qué dos herramientas de ML?** Python (Random Forest en Colab) y KNIME (Árbol de Decisión + Gradient Boosted Trees) permiten comparar resultados entre enfoques de código y herramientas visuales. Ambos leen de la misma fuente (MongoDB `resumen_diario`) para que la comparación sea válida.

**¿Por qué Gradient Boosted Trees en KNIME?** El boosting construye modelos secuenciales que corrigen errores anteriores, generalmente superando al árbol simple y siendo competitivo con Random Forest, con la ventaja de ejecutarse visualmente en KNIME sin código.

**¿Por qué upsert en MongoDB?** El ETL es idempotente: se puede re-ejecutar sin duplicar documentos, usando `_id = estacion_id + fecha` como clave natural.
