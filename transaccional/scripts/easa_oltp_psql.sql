-- Script de entrada para psql (NO apto para el editor SQL de pgAdmin).
-- Ejecucion: psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f easa_oltp_psql.sql
\set ON_ERROR_STOP on
\ir 00_crear_base.sql
\connect easa_oltp
\ir easa_oltp_schema.sql
-- Datos de catalogo opcionales, anular el comentario para cargarlos:
-- \ir 02_catalogos_opcionales.sql
