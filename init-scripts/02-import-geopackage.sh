#!/bin/bash
set -e

echo "Esperando a que PostGIS esté completamente listo..."
sleep 5

# Usar el GeoPackage de Chocó
GEOPACKAGE_FILE="/geopackage/choco.gpkg"

if [ ! -f "$GEOPACKAGE_FILE" ]; then
    echo "ERROR: No se encontró el archivo GeoPackage en $GEOPACKAGE_FILE"
    exit 1
fi

echo "Verificando disponibilidad de GDAL..."
if ! command -v ogr2ogr &> /dev/null; then
    echo "ERROR: ogr2ogr no está disponible. GDAL debe estar instalado en la imagen."
    exit 1
fi
echo "GDAL está disponible. Versión: $(ogrinfo --version)"

echo "Listando las capas disponibles en el GeoPackage..."
ogrinfo "$GEOPACKAGE_FILE"

# Definir las capas a importar
LAYERS=("dpto_choco" "puntos_administrativos")

# Importar cada capa a su propia tabla
# Durante la inicialización, usamos la conexión por socket Unix (sin host)
for LAYER in "${LAYERS[@]}"; do
    echo "========================================="
    echo "Importando capa: $LAYER"
    echo "========================================="

    ogr2ogr -f "PostgreSQL" \
        PG:"dbname=$POSTGRES_DB user=$POSTGRES_USER password=$POSTGRES_PASSWORD" \
        "$GEOPACKAGE_FILE" \
        "$LAYER" \
        -overwrite \
        -progress \
        -lco GEOMETRY_NAME=geom \
        -lco FID=gid \
        -nln "$LAYER"

    echo "Capa $LAYER importada exitosamente!"
done

echo "========================================="
echo "Todas las capas han sido importadas!"
echo "========================================="

echo "Verificando las tablas importadas..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    \dt

    SELECT 'dpto_choco' as tabla, COUNT(*) as total_registros FROM dpto_choco
    UNION ALL
    SELECT 'puntos_administrativos' as tabla, COUNT(*) as total_registros FROM puntos_administrativos;
EOSQL
