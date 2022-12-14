#!/bin/bash

# Installing Java
sudo apt update
sudo apt install openjdk-8-jdk -y

# Installing Nexus
mkdir -p /opt/nexus/
mkdir -p /tmp/nexus/
cd /tmp/nexus/
wget https://download.sonatype.com/nexus/3/latest-unix.tar.gz -O nexus.tar.gz

EXTOUT=`tar xzvf nexus.tar.gz`
NEXUSDIR=`echo $EXTOUT | cut -d '/' -f1`
rm -rf /tmp/nexus/nexus.tar.gz
rsync -avzh /tmp/nexus/ /opt/nexus/

useradd nexus
chown -R nexus.nexus /opt/nexus

cat >> /etc/systemd/system/nexus.service <<EOT
[Unit]
Description=nexus service
After=network.target

[Service]
Type=forking
LimitNOFILE=65536
ExecStart=/opt/nexus/$NEXUSDIR/bin/nexus start
ExecStop=/opt/nexus/$NEXUSDIR/bin/nexus stop
User=nexus
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOT

echo 'run_as_user="nexus"' > /opt/nexus/$NEXUSDIR/bin/nexus.rc

systemctl enable nexus
systemctl daemon-reload
systemctl start nexus