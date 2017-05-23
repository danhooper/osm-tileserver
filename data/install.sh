while [[ $# > 0 ]]
do
key="$1"
shift

SSL=false

case $key in
    -s|--ssl)
    SSL=true
    ;;
    *)
            # unknown option
    ;;
esac
done

sudo apt-get update

# Base packages
sudo apt install -y libboost-all-dev git-core tar unzip wget bzip2 build-essential autoconf libtool libxml2-dev libgeos-dev libgeos++-dev libpq-dev libbz2-dev libproj-dev munin-node munin libprotobuf-c0-dev protobuf-c-compiler libfreetype6-dev libpng12-dev libtiff5-dev libicu-dev libgdal-dev libcairo-dev libcairomm-1.0-dev apache2 apache2-dev libagg-dev liblua5.2-dev ttf-unifont lua5.1 liblua5.1-dev libgeotiff-epsg node-carto cmake

# Setting up PostgreSQL
sudo apt install -y postgresql postgresql-contrib postgis postgresql-9.5-postgis-2.2
sudo -u postgres createuser -S osmuser
sudo -u postgres createdb -E UTF8 -O osmuser gis
sudo useradd -m osmuser
sudo -u postgres psql --command="CREATE EXTENSION postgis;ALTER TABLE geometry_columns OWNER TO osmuser;ALTER TABLE spatial_ref_sys OWNER TO osmuser;" --dbname=gis

# Installing osm2pgsql
mkdir ~/src
git clone git://github.com/openstreetmap/osm2pgsql.git ~/src/osm2pgsql
cd ~/src/osm2pgsql
mkdir build && cd build
cmake ..
make
sudo make install

# Installing Mapnik
sudo apt install -y autoconf apache2-dev libtool libxml2-dev libbz2-dev libgeos-dev libgeos++-dev libproj-dev gdal-bin libgdal1-dev libmapnik-dev mapnik-utils python-mapnik

# Installing mod_tile and renderd
cd ~/src
git clone git://github.com/SomeoneElseOSM/mod_tile.git
cd mod_tile
./autogen.sh
./configure
make
sudo make install
sudo make install-mod_tile
sudo ldconfig


cd ~/src
git clone git://github.com/gravitystorm/openstreetmap-carto.git
cd openstreetmap-carto
git checkout `git rev-list -n 1 --before="2016-12-04 00:00" master`
cd ~/src/openstreetmap-carto
carto project.mml > mapnik.xml

cd ~/src/openstreetmap-carto/
scripts/get-shapefiles.py


sudo apt-get install -y fonts-noto-cjk fonts-noto-hinted fonts-noto-unhinted ttf-unifont



# Configure renderd & mod_tile
cp /data_share/config/renderd/renderd.conf /usr/local/etc/
echo "LoadModule tile_module /usr/lib/apache2/modules/mod_tile.so" >> /etc/apache2/conf-available/mod_tile.conf
echo "LoadModule headers_module /usr/lib/apache2/modules/mod_headers.so" >> /etc/apache2/conf-available/mod_tile.conf
cp /data_share/config/apache2/000-default.conf /etc/apache2/sites-available/
if [[ "$SSL" -eq "true" ]]; then
    cp /data_share/config/apache2/100-default-ssl.conf /etc/apache2/sites-available/
    ln -s /etc/apache2/sites-available/100-default-ssl.conf /etc/apache2/sites-enabled/
    a2enmod ssl
fi
a2enconf mod_tile
cp /data_share/config/renderd/renderd.init /etc/init.d/renderd
chmod u+x /etc/init.d/renderd
sudo cp ~/src/mod_tile/debian/renderd.service /lib/systemd/system/
mkdir /var/lib/mod_tile
chown osmuser /var/lib/mod_tile

# System tuning
# cp /data_share/config/postgres/postgresql.conf /etc/postgresql/9.3/main/
# cp /data_share/config/sysctl.conf /etc/

sudo mkdir -p /usr/local/share/maps/style
sudo cp ~/src/openstreetmap-carto/mapnik.xml /usr/local/share/maps/style/
sudo cp -R ~/src/openstreetmap-carto/data /usr/local/share/maps/style/
sudo cp -R ~/src/openstreetmap-carto/symbols /usr/local/share/maps/style/

# Import latest OSM-data for Egypt
sudo mkdir -p /usr/local/share/maps/Egypt
chown osmuser /usr/local/share/maps/Egypt
cd /usr/local/share/maps/Egypt
sudo wget -q http://download.geofabrik.de/africa/egypt-latest.osm.pbf
sudo cp /data_share/english.style /usr/local/share/maps/style/
sudo -u osmuser osm2pgsql --slim -d gis -C 2048 --number-processes 3 /usr/local/share/maps/Egypt/egypt-latest.osm.pbf  --style /usr/local/share/maps/style/english.style
sudo -u osmuser psql -d gis -f /data_share/english_names.sql


# Setup auto-updating for OSM-data
~/src/osm2pgsql/install-postgis-osm-user.sh gis osmuser
#cp /root/src/mod_tile/openstreetmap-tiles-update-expire /usr/bin/
#cp /root/src/mod_tile/osmosis-db_replag /usr/bin/
#mkdir /var/log/tiles && chown osmuser /var/log/tiles
#DATE=`date +%Y-%m-%d` &&  sudo -u osmuser openstreetmap-tiles-update-expire $DATE
#cp /data_share/config/osmosis/configuration.txt /var/lib/mod_tile/.osmosis/
#sudo -u osmuser openstreetmap-tiles-update-expire
#cp /data_share/config/osmosis/rc.local /etc/rc.local

# # Setup default map interface (TODO: replace with osmuser)
rm /var/www/html/index.html
cp /data_share/web/index.html /var/www/html/

# Starting services
mkdir /var/run/renderd
chown osmuser /var/run/renderd
/etc/init.d/renderd start
service apache2 restart &

echo "Restarted apache"

