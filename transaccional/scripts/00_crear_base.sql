-- Ejecutar conectado a la base 'postgres' (NO dentro de una transaccion).
-- PostgreSQL no admite CREATE DATABASE IF NOT EXISTS.
CREATE DATABASE easa_oltp WITH ENCODING = 'UTF8' TEMPLATE = template0;
