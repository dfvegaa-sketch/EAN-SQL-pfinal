-- ============================================================
-- DataFlow — DDL 
-- ============================================================

-- 
-- ciudades
-- 
DROP TABLE IF EXISTS ciudades         CASCADE;
CREATE TABLE ciudades (
    ciudad_id       SERIAL PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL UNIQUE,
    altitud_msnm    INTEGER      NOT NULL,
    poblacion       INTEGER      NOT NULL,
    departamento    VARCHAR(100) NOT NULL,
    creado_en       TIMESTAMP    DEFAULT NOW()
);

-- 
-- contaminantes
-- 

DROP TABLE IF EXISTS contaminantes    CASCADE;
CREATE TABLE contaminantes (
    contaminante_id      SERIAL PRIMARY KEY,
    nombre               VARCHAR(20)  NOT NULL UNIQUE,
    unidad               VARCHAR(20)  NOT NULL,
    limite_legal_diario  NUMERIC(8,2) NOT NULL,
    descripcion          TEXT
);

-- 
-- estaciones
-- 

DROP TABLE IF EXISTS estaciones       CASCADE;
CREATE TABLE estaciones (
    estacion_id       SERIAL PRIMARY KEY,
    ciudad_id         INTEGER      NOT NULL REFERENCES ciudades(ciudad_id),
    nombre            VARCHAR(100) NOT NULL,
    latitud           NUMERIC(9,6) NOT NULL,
    longitud          NUMERIC(9,6) NOT NULL,
    fecha_instalacion DATE         NOT NULL,
    activa            BOOLEAN      DEFAULT TRUE,
    creado_en         TIMESTAMP    DEFAULT NOW()
);

CREATE INDEX idx_estaciones_ciudad ON estaciones(ciudad_id);

-- 
-- clima_diario
-- 

DROP TABLE IF EXISTS clima_diario     CASCADE;
CREATE TABLE clima_diario (
    clima_id        SERIAL PRIMARY KEY,
    ciudad_id       INTEGER      NOT NULL REFERENCES ciudades(ciudad_id),
    fecha           DATE         NOT NULL,
    temperatura_c   NUMERIC(5,1),
    humedad_pct     NUMERIC(5,1),
    viento_kmh      NUMERIC(5,1),
    lluvia          BOOLEAN      DEFAULT FALSE,
    mm_lluvia       NUMERIC(6,1) DEFAULT 0.0,
    es_festivo      BOOLEAN      DEFAULT FALSE,
    UNIQUE (ciudad_id, fecha)
);

CREATE INDEX idx_clima_ciudad_fecha ON clima_diario(ciudad_id, fecha);

-- 
-- mediciones_raw
-- 

DROP TABLE IF EXISTS mediciones_raw   CASCADE;
CREATE TABLE mediciones_raw (
    medicion_id      BIGSERIAL    PRIMARY KEY,
    estacion_id      INTEGER      NOT NULL REFERENCES estaciones(estacion_id),
    contaminante_id  INTEGER      NOT NULL REFERENCES contaminantes(contaminante_id),
    valor            NUMERIC(10,2),           -- NULL = sensor sin dato
    timestamp        TIMESTAMP    NOT NULL,
    flag_anomalia    BOOLEAN      DEFAULT FALSE
);

-- Índices críticos para las consultas del ETL
CREATE INDEX idx_mediciones_estacion   ON mediciones_raw(estacion_id);
CREATE INDEX idx_mediciones_timestamp  ON mediciones_raw(timestamp);
CREATE INDEX idx_mediciones_est_ts     ON mediciones_raw(estacion_id, timestamp);
CREATE INDEX idx_mediciones_anomalia   ON mediciones_raw(flag_anomalia) WHERE flag_anomalia = TRUE;

CREATE OR REPLACE VIEW v_mediciones_completas AS
SELECT
    m.medicion_id,
    e.nombre        AS estacion,
    c.nombre        AS ciudad,
    co.nombre       AS contaminante,
    co.unidad,
    co.limite_legal_diario,
    m.valor,
    m.timestamp,
    m.flag_anomalia,
    DATE(m.timestamp) AS fecha,
    EXTRACT(HOUR FROM m.timestamp)::INTEGER AS hora
FROM mediciones_raw  m
JOIN estaciones      e  ON m.estacion_id     = e.estacion_id
JOIN ciudades        c  ON e.ciudad_id        = c.ciudad_id
JOIN contaminantes   co ON m.contaminante_id  = co.contaminante_id;
