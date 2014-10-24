#!/bin/bash

# install php and nginx
apt-get update
apt-get install --assume-yes --force-yes nginx-full php5-fpm php5-cli php5-curl python-pip

# install aws cli
pip install awscli

# install auto-completer for aws
echo "complete -C aws_completer aws" >> /root/.bashrc
echo "complete -C aws_completer aws" >> /home/ubuntu/.bashrc

# create default aws config for root and ubuntu user
mkdir -p /root/.aws/
mkdir -p /home/ubuntu/.aws/
echo "[default]" > /root/.aws/config
echo "region = us-east-1" >> /root/.aws/config
echo "" >> /root/.aws/config
cp  /root/.aws/config /home/ubuntu/.aws/
chown -R ubuntu:ubuntu /home/ubuntu/.aws

BUCKET=<insert your bucket here>
WEBROOT=/usr/share/nginx/html/aws-tutorial

aws s3 cp --recursive s3://$BUCKET/aws-tutorial/ $WEBROOT

# lay down elb status file
cat << EOF > /usr/share/nginx/html/elb_status.html
<!doctype html><html lang="en"><head><meta charset="utf-8"><title>ok</title></head><body>ok</body></html>
EOF

# lay down elb status config
cat << EOF > /etc/nginx/sites-enabled/elb_status
server {
  listen 81;
  root /usr/share/nginx/html;
}
EOF

# lay down webroot config
mkdir -p $WEBROOT
cat << EOF > /etc/nginx/sites-enabled/aws-tutorial
server {
 listen 80 default_server;
 root $WEBROOT;

index index.html;

  # Pass the PHP scripts to FastCGI server
  location ~* \.php$ {
    fastcgi_pass unix:/var/run/php5-fpm.sock;
    fastcgi_index index.php;
    fastcgi_intercept_errors on; # to support 404s for PHP files not found
    include fastcgi_params;
  }
}
EOF

# remove nginx default config
rm /etc/nginx/sites-enabled/default
# restart nginx
service nginx restart
