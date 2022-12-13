#!/bin/bash

cp /etc/sysctl.conf /root/sysctl.conf_backup
cat > /etc/sysctl.conf <<EOT
vm.max_map_count=262144
fs.file-max=65536
ulimit -n 65536
ulimit -u 4096
EOT

cp /etc/security/limits.conf /root/sec_limit.conf_backup
cat > /etc/security/limits.conf <<EOT
sonarqube   -   nofile   65536
sonarqube   -   nproc    409
EOT

sudo apt update
## Java & zip
sudo apt install openjdk-11-jdk openjdk-17-jdk zip net-tools -y

## PostgreSQL
# Create the file repository configuration
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
# Import the repository signin key
sudo wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
# Install postgresql
sudo apt install postgresql postgresql-contrib -y
# Enable service
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Config PostgreSQL SonarQube user
sudo echo "postgres:admin123" | chpasswd
runuser -l postgres -c "createuser sonar"
sudo -i -u postgres psql -c "ALTER USER sonar WITH ENCRYPTED PASSWORD 'admin123';"
sudo -i -u postgres psql -c "CREATE DATABASE sonarqube OWNER sonar;"
sudo -i -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE sonarqube to sonar;"
systemctl restart  postgresql
netstat -tulpena | grep postgres

## SonarQube
sudo mkdir -p /sonarqube/
cd /sonarqube/

# Download sonarqube
sudo curl -O https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.7.1.62043.zip
# Unzip files
sudo unzip -o sonarqube-9.7.1.62043.zip -d /opt/
# Rename folder
sudo mv /opt/sonarqube-9.7.1.62043/ /opt/sonarqube
# Create user & assign permission on sonarqube folder
sudo groupadd sonar
sudo useradd -c "SonarQube - User" -d /opt/sonarqube/ -g sonar sonar
sudo chown sonar:sonar /opt/sonarqube/ -R

cp /opt/sonarqube/conf/sonar.properties /root/sonar.properties_backup
cat > /opt/sonarqube/conf/sonar.properties <<EOT
sonar.jdbc.username=sonar
sonar.jdbc.password=admin123
sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube
sonar.web.host=0.0.0.0
sonar.web.port=9000
sonar.web.javaAdditionalOpts=-server
sonar.search.javaOpts=-Xmx512m -Xms512m -XX:+HeapDumpOnOutOfMemoryError
sonar.log.level=INFO
sonar.path.logs=logs
EOT

cat > /etc/systemd/system/sonarqube.service <<EOT
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking

ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop

User=sonar
Group=sonar
Restart=always

LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOT

# Restart services
systemctl daemon-reload
systemctl enable sonarqube.service
#sudo systemctl start sonarqube.service

## NGINX
sudo apt install nginx -y
sudo rm -rf /etc/nginx/sites-enabled/default
sudo rm -rf /etc/nginx/sites-available/default
sudo cat > /etc/nginx/sites-available/sonarqube <<EOT
server{
    listen      80;
    server_name sonarqube.groophy.in;
    access_log  /var/log/nginx/sonar.access.log;
    error_log   /var/log/nginx/sonar.error.log;
    proxy_buffers 16 64k;
    proxy_buffer_size 128k;
    location / {
        proxy_pass  http://127.0.0.1:9000;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
        proxy_redirect off;

        proxy_set_header    Host            \$host;
        proxy_set_header    X-Real-IP       \$remote_addr;
        proxy_set_header    X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header    X-Forwarded-Proto http;
    }
}
EOT

sudo ln -s /etc/nginx/sites-available/sonarqube /etc/nginx/sites-enabled/sonarqube
sudo systemctl enable nginx.service
sudo ufw allow 80,9000,9001/tcp

sleep 5
reboot