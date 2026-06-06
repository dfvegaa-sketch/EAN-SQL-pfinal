-- ============================================================
-- DataFlow — DML datos de prueba
-- ============================================================

-- 
-- ciudades
-- 
INSERT INTO ciudades (ciudad_id, nombre, altitud_msnm, poblacion, departamento) VALUES
(1, 'Bogotá',   2600, 7400000, 'Cundinamarca'),
(2, 'Medellín', 1495, 2600000, 'Antioquia'),
(3, 'Cali',      995, 2200000, 'Valle del Cauca');

-- 
-- contaminantes
-- 
INSERT INTO contaminantes (contaminante_id, nombre, unidad, limite_legal_diario, descripcion) VALUES
(1, 'PM2.5', 'µg/m³',  25.0, 'Partículas finas < 2.5 µm'),
(2, 'PM10',  'µg/m³',  50.0, 'Partículas gruesas < 10 µm'),
(3, 'NO2',   'µg/m³',  40.0, 'Dióxido de nitrógeno');

-- 
-- estaciones
-- 
INSERT INTO estaciones (estacion_id, ciudad_id, nombre, latitud, longitud, fecha_instalacion) VALUES
(1,  1, 'Kennedy',    4.6258, -74.1478, '2019-03-10'),
(2,  1, 'Usaquén',    4.7069, -74.0317, '2018-07-22'),
(6,  2, 'El Centro',  6.2442, -75.5812, '2018-04-18'),
(11, 3, 'San Fernando', 3.4516, -76.5320, '2019-08-07');

-- 
-- clima_diario
-- 
INSERT INTO clima_diario
  (ciudad_id, fecha, temperatura_c, humedad_pct, viento_kmh, lluvia, mm_lluvia, es_festivo)
VALUES
-- Bogotá — enero 2024
(1, '2024-01-01', 15.0, 73.9, 14.6, FALSE,  0.0, TRUE),   -- festivo, sin lluvia
(1, '2024-01-02', 17.0, 77.2, 16.0, TRUE,   1.4, FALSE),  -- con lluvia leve
(1, '2024-01-03', 12.8, 70.8,  9.7, FALSE,  0.0, FALSE);  -- día normal

-- 
-- mediciones_raw
-- 
INSERT INTO mediciones_raw
  (estacion_id, contaminante_id, valor, timestamp, flag_anomalia)
VALUES
-- Estación 1: Kennedy, Bogotá
(1, 1,  8.84, '2024-01-01 00:45:12', FALSE),   -- PM2.5
(1, 2, 29.72, '2024-01-01 00:40:15', FALSE),   -- PM10
(1, 3, 21.66, '2024-01-01 00:54:43', FALSE),   -- NO2

-- Estación 6: El Centro, Medellín
(6, 1, 12.55, '2024-01-01 00:02:19', FALSE),   -- PM2.5
(6, 2, 23.87, '2024-01-01 00:24:03', FALSE),   -- PM10
(6, 3,  7.86, '2024-01-01 00:24:37', FALSE),   -- NO2

-- Estación 11: San Fernando, Cali
(11, 1,  1.47, '2024-01-01 00:08:17', FALSE),
(11, 2, 16.71, '2024-01-01 00:19:35', FALSE),
(11, 3,  7.44, '2024-01-01 00:46:44', FALSE);
