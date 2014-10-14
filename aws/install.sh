#!/bin/bash

# install php and nginx
apt-get install --assume-yes --force-yes nginx-full php5-fpm php5-cli php5-curl

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
WEBROOT=/usr/share/nginx/html/hello
mkdir -p $WEBROOT
cat << EOF > /etc/nginx/sites-enabled/hello
server {
 listen 80 default_server;
 root /usr/share/nginx/html/hello;

index index.php;

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

# install composer - so we can install the AWS PHP SDK
cd $WEBROOT
curl -sS https://getcomposer.org/installer | php
# lay composer.json file down
cat << EOF > $WEBROOT/composer.json
{
	"name": "hello-world-aws",
	"description": "Hello Dynamo",
	"config": 
	{
		"vendor-dir": "Vendor"
	},
	"minimum-stability": "dev",
	"require": 
	{
		"aws/aws-sdk-php": "2.5.4"
	},
	"preferred-install": "dist"
}
EOF

# install the php stuff
COMPOSER_HOME=$WEBROOT php composer.phar install &> /tmp/composer.out

echo "$?" >> /tmp/composer.rc

# lay down php file
cat << 'EOF' > $WEBROOT/index.php
<?php
require 'Vendor/autoload.php';
use Aws\Common\Aws;

try {
	$tableName = 'test-hello-aws';
	$tableStatus = getTableStatus ( $tableName );
	echo $tableName . ' is ' . $tableStatus;
} catch ( \Exception $e ) {
	var_dump ( $e->getMessage () );
}
function getAWSFactory() {
	return Aws::factory ( array( 'region' => 'us-east-1' ) );
}
function getDynamoClient() {
	$aws = getAwsFactory ( );
	return $aws->get ( 'dynamodb' );
}
function getTableStatus($tableName) {
	$result = getDynamoClient ()->describeTable ( array (
			'TableName' => $tableName 
	) );
	return $result ['Table'] ['TableStatus'];
}
EOF
