aws-hello-world
======================

Hello AWS

## Reference

Cloud Formation: http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/Welcome.html
AMI Finder: http://cloud-images.ubuntu.com/locator/ec2/

## Setup Steps
1. Login to EC2 Key-Pair console: https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#KeyPairs:sort=keyName
1. Click on "Create Key Pair"
1. Enter in any name, ie: "test"
![keypair](https://s3.amazonaws.com/uploads.hipchat.com/15441/59702/wKXg0nYLqNxJ0Cd/upload.png)
1. They new key will be downloaded.  Store in a safe location, ie: ~/.ssh/test.pem

## Creating Elastic Load Balancer and assigning DNS
1. Login to Cloud Formation console: https://console.aws.amazon.com/cloudformation
1. Click on "Create Stack" button
![create stack](https://s3.amazonaws.com/uploads.hipchat.com/15441/59702/GYPMdxF4q1pYVyP/upload.png)
1. Enter a name for the stack. ie: test-hello-world
1. Specify this Amazon S3 template URL: https://s3.amazonaws.com/static.doapps.com/cloud_formation/elb_dns.json
1. Click "Next"
![create stack](https://s3.amazonaws.com/uploads.hipchat.com/15441/59702/X5W0DCkFqtgTWWJ/upload.png)
1. Enter parameters
HostedZoneName: <your domain here>
Prefix: <prefix of domain, ie: test, prod, etc>
Subdomain: <subdomain>
The resulting DNS will be <Prefix>-<Subdomain>.HostedZoneName ie: test-hello.doapps.com
1. Click "Next"
![parameters](https://s3.amazonaws.com/uploads.hipchat.com/15441/59702/JN2YvCvjPwIDQ2e/upload.png)
1. Click "Next" on Options page
![options](https://s3.amazonaws.com/uploads.hipchat.com/15441/59702/4WnXucwB4THOJ5m/upload.png)
1. Click "Create" on the Review page
![create](https://s3.amazonaws.com/uploads.hipchat.com/15441/59702/jIAkxI1ftZ5srY8/upload.png)
1. On completion, 2 resources are created.  An ELB and DNS entry.  You can now ping the domain created
![completed](https://s3.amazonaws.com/uploads.hipchat.com/15441/59702/D2ZUrNKLSBivL2w/.png)

## Creating Autoscale groups
1. Login to Cloud Formation console: https://console.aws.amazon.com/cloudformation
1. Click on stack created above and then click on "Update Stack" button
1. Specify this Amazon S3 template URL: https://s3.amazonaws.com/static.doapps.com/cloud_formation/autoscale.json
1. Click "Next"
![update-autoscale](https://s3.amazonaws.com/uploads.hipchat.com/15441/59702/UpfQ5DuP30Pefod/upload.png)
1. Enter parameters
KeyName: <the name of create created in setup steps>
AMI: <amazon machine image, use the default>
InstanceType: <t1.micro is the smallest/cheapest>
UserData: <leave blank for now>
1. Click "Next"
![update-autoscale-params](https://s3.amazonaws.com/uploads.hipchat.com/15441/59702/qh8h51ppIl773SV/upload.png)
1. Click "Next" on Options page
![update-autoscale-options](https://s3.amazonaws.com/uploads.hipchat.com/15441/59702/3cVNtRpueNXd9FW/upload.png)
1. Click "Update" on Review page
![update-autoscale-review](https://s3.amazonaws.com/uploads.hipchat.com/15441/59702/hULk1ASFMpKNeBi/upload.png)
1. On completion, you'll see a few more resources.
A security group was created that the instances in the AutoScale group will go into.  A launch config was also created, this tells the autoscale group how to launch the instances.
The Role and Profile resources are related to what access the ec2 instances will have to AWS resources, we'll get back to those later
![update-autoscale-complete](https://s3.amazonaws.com/uploads.hipchat.com/15441/59702/E0YtQNvMkMG6G0J/upload.png)
1. If you go over to the EC2 Load Balancer page, you'll see your load balancer with 0 of 1 instances in service.
This is because we setup the ELB health check to ping :81/elb_status.html on our instance to determine if it is healthy.  Since we haven't setup anything on the instance yet, the instance will never become healthy.
![update-autoscale-elb](https://s3.amazonaws.com/uploads.hipchat.com/15441/59702/NU8f7hwjYK3MRHE/upload.png)

## Logging into EC2 instance

Let's log into that EC2 instance to see what's going on

1. Click on the instances tab under the ELB
1. Click on the instance id
![elb-instances](https://s3.amazonaws.com/uploads.hipchat.com/15441/59702/iPwv2VwekzKDA0B/upload.png)
1. Copy the Public DNS name to use below
![ec2-dns](https://s3.amazonaws.com/uploads.hipchat.com/15441/59702/q3OhwnxdoZCg0OU/upload.png)
1. Use the key downloaded in the setup steps
```
ssh -i ~/.ssh/test.pem ubuntu@ec2-54-90-192-72.compute-1.amazonaws.com
ubuntu@ip-10-178-34-58:~$ sudo netstat -ltnp
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      1004/sshd       
tcp6       0      0 :::22                   :::*                    LISTEN      1004/sshd       
ubuntu@ip-10-178-34-58:~$ 
```
Only the SSH daemon is listening

## User Data

The User Data is what is run on the instance once it's come up.  Since we're dealing with a base ubuntu AMI, we'll need to install some stuff.
For starters, we'll install nginx and php5-fpm and lay down a config for the elb health check.
```
#!/bin/bash

# install php and nginx
apt-get install --assume-yes --force-yes nginx-full php5-fpm

# lay down elb status file
cat << EOF >> /usr/share/nginx/html/elb_status.html
<!doctype html><html lang="en"><head><meta charset="utf-8"><title>ok</title></head><body>ok</body></html>
EOF

# lay down elb status config
cat << EOF >> /etc/nginx/sites-enabled/elb_status
server {
  listen 81 default_server;
  root /usr/share/nginx/html;
}
EOF

service nginx restart
```
1. Copy the above into /tmp/install.sh
1. Base64 encode it
```
jeremy@jeremy-thinkpad-1:/tmp$ base64 -w 0 /tmp/install.sh && echo ''
IyEvYmluL2Jhc2gKCiMgaW5zdGFsbCBwaHAgYW5kIG5naW54CmFwdC1nZXQgaW5zdGFsbCAtLWFzc3VtZS15ZXMgLS1mb3JjZS15ZXMgbmdpbngtZnVsbCBwaHA1LWZwbQoKIyBsYXkgZG93biBlbGIgc3RhdHVzIGZpbGUKY2F0IDw8IEVPRiA+PiAvdXNyL3NoYXJlL25naW54L2h0bWwvZWxiX3N0YXR1cy5odG1sCjwhZG9jdHlwZSBodG1sPjxodG1sIGxhbmc9ImVuIj48aGVhZD48bWV0YSBjaGFyc2V0PSJ1dGYtOCI+PHRpdGxlPm9rPC90aXRsZT48L2hlYWQ+PGJvZHk+b2s8L2JvZHk+PC9odG1sPgpFT0YKCiMgbGF5IGRvd24gZWxiIHN0YXR1cyBjb25maWcKY2F0IDw8IEVPRiA+PiAvZXRjL25naW54L3NpdGVzLWVuYWJsZWQvZWxiX3N0YXR1cwpzZXJ2ZXIgewogIGxpc3RlbiA4MSBkZWZhdWx0X3NlcnZlcjsKICByb290IC91c3Ivc2hhcmUvbmdpbngvaHRtbDsKfQpFT0YKCiMgcmVzdGFydCBuZ2lueApzZXJ2aWNlIG5naW54IHJlc3RhcnQK
```
1. Login to the Cloud Formation console
1. Select the stack
1. Click on "Update Stack"
1. Select "Use existing template"
![update-userdata](https://s3.amazonaws.com/uploads.hipchat.com/15441/59702/1l78MDFZ4uTwcol/upload.png)
1. Copy and paste in the base64 encoded data from above into the UserData parameters
1. Click "Next"
![update-userdata-paste](https://s3.amazonaws.com/uploads.hipchat.com/15441/59702/5yiFfOqL2XxKTp5/upload.png)
1. Click "Next" on Options page
1. Click "Update"

After the update has completed, we'll need to get the user data to actually run.

## Terminate the instance
1. Go back to the instance and terminate it
![terminate](https://s3.amazonaws.com/uploads.hipchat.com/15441/59702/pISojdECeMTgTJk/upload.png)
1. Because this instance is in an autoscale group, a new instance will be brought up in it's place with the update launch configuration with our new User Data
1. Go to the Load Balancers page and wait for the instance to show up: https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#LoadBalancers:
![inservice](https://s3.amazonaws.com/uploads.hipchat.com/15441/59702/3pF4506TMKvViiG/upload.png)


## Let's log in again

We have a new ec2 instance now, so we have a new public DNS name

Click on the instance id in the load balancer page and copy the Public DNS name

```
ssh -i ~/.ssh/test.pem ubuntu@ec2-107-22-13-175.compute-1.amazonaws.com
ubuntu@ip-10-194-241-72:~$ sudo netstat -ltnp
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      2440/nginx      
tcp        0      0 0.0.0.0:81              0.0.0.0:*               LISTEN      2440/nginx      
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      1011/sshd       
tcp6       0      0 :::80                   :::*                    LISTEN      2440/nginx      
tcp6       0      0 :::22                   :::*                    LISTEN      1011/sshd       
```

Now we're listening on port 80 and 81

## Create a DynamoDB table
1. Login to the Cloud Formation console
1. Select your stack
1. Click on "Update Stack"
1. Select "Speciy an Amazon S3 template URL" and enter this url: https://s3.amazonaws.com/static.doapps.com/cloud_formation/dynamo.json
1. Click "Next"
1. On the Speciy Parameters page, enter new User Data enter the base64 encoded string below

base64 encoded string
```
IyEvYmluL2Jhc2gKCiMgaW5zdGFsbCBwaHAgYW5kIG5naW54CmFwdC1nZXQgaW5zdGFsbCAtLWFzc3VtZS15ZXMgLS1mb3JjZS15ZXMgbmdpbngtZnVsbCBwaHA1LWZwbSBwaHA1LWNsaSBwaHA1LWN1cmwKCiMgbGF5IGRvd24gZWxiIHN0YXR1cyBmaWxlCmNhdCA8PCBFT0YgPiAvdXNyL3NoYXJlL25naW54L2h0bWwvZWxiX3N0YXR1cy5odG1sCjwhZG9jdHlwZSBodG1sPjxodG1sIGxhbmc9ImVuIj48aGVhZD48bWV0YSBjaGFyc2V0PSJ1dGYtOCI+PHRpdGxlPm9rPC90aXRsZT48L2hlYWQ+PGJvZHk+b2s8L2JvZHk+PC9odG1sPgpFT0YKCiMgbGF5IGRvd24gZWxiIHN0YXR1cyBjb25maWcKY2F0IDw8IEVPRiA+IC9ldGMvbmdpbngvc2l0ZXMtZW5hYmxlZC9lbGJfc3RhdHVzCnNlcnZlciB7CiAgbGlzdGVuIDgxOwogIHJvb3QgL3Vzci9zaGFyZS9uZ2lueC9odG1sOwp9CkVPRgoKIyBsYXkgZG93biB3ZWJyb290IGNvbmZpZwpXRUJST09UPS91c3Ivc2hhcmUvbmdpbngvaHRtbC9oZWxsbwpta2RpciAtcCAkV0VCUk9PVApjYXQgPDwgRU9GID4gL2V0Yy9uZ2lueC9zaXRlcy1lbmFibGVkL2hlbGxvCnNlcnZlciB7CiBsaXN0ZW4gODAgZGVmYXVsdF9zZXJ2ZXI7CiByb290IC91c3Ivc2hhcmUvbmdpbngvaHRtbC9oZWxsbzsKCmluZGV4IGluZGV4LnBocDsKCiAgIyBQYXNzIHRoZSBQSFAgc2NyaXB0cyB0byBGYXN0Q0dJIHNlcnZlcgogIGxvY2F0aW9uIH4qIFwucGhwJCB7CiAgICBmYXN0Y2dpX3Bhc3MgdW5peDovdmFyL3J1bi9waHA1LWZwbS5zb2NrOwogICAgZmFzdGNnaV9pbmRleCBpbmRleC5waHA7CiAgICBmYXN0Y2dpX2ludGVyY2VwdF9lcnJvcnMgb247ICMgdG8gc3VwcG9ydCA0MDRzIGZvciBQSFAgZmlsZXMgbm90IGZvdW5kCiAgICBpbmNsdWRlIGZhc3RjZ2lfcGFyYW1zOwogIH0KfQpFT0YKCiMgcmVtb3ZlIG5naW54IGRlZmF1bHQgY29uZmlnCnJtIC9ldGMvbmdpbngvc2l0ZXMtZW5hYmxlZC9kZWZhdWx0CiMgcmVzdGFydCBuZ2lueApzZXJ2aWNlIG5naW54IHJlc3RhcnQKCiMgaW5zdGFsbCBjb21wb3NlciAtIHNvIHdlIGNhbiBpbnN0YWxsIHRoZSBBV1MgUEhQIFNESwpjZCAkV0VCUk9PVApjdXJsIC1zUyBodHRwczovL2dldGNvbXBvc2VyLm9yZy9pbnN0YWxsZXIgfCBwaHAKIyBsYXkgY29tcG9zZXIuanNvbiBmaWxlIGRvd24KY2F0IDw8IEVPRiA+ICRXRUJST09UL2NvbXBvc2VyLmpzb24KewoJIm5hbWUiOiAiaGVsbG8td29ybGQtYXdzIiwKCSJkZXNjcmlwdGlvbiI6ICJIZWxsbyBEeW5hbW8iLAoJImNvbmZpZyI6IAoJewoJCSJ2ZW5kb3ItZGlyIjogIlZlbmRvciIKCX0sCgkibWluaW11bS1zdGFiaWxpdHkiOiAiZGV2IiwKCSJyZXF1aXJlIjogCgl7CgkJImF3cy9hd3Mtc2RrLXBocCI6ICIyLjUuNCIKCX0sCgkicHJlZmVycmVkLWluc3RhbGwiOiAiZGlzdCIKfQpFT0YKCiMgaW5zdGFsbCB0aGUgcGhwIHN0dWZmCkNPTVBPU0VSX0hPTUU9JFdFQlJPT1QgcGhwIGNvbXBvc2VyLnBoYXIgaW5zdGFsbCAmPiAvdG1wL2NvbXBvc2VyLm91dAoKZWNobyAiJD8iID4+IC90bXAvY29tcG9zZXIucmMKCiMgbGF5IGRvd24gcGhwIGZpbGUKY2F0IDw8ICdFT0YnID4gJFdFQlJPT1QvaW5kZXgucGhwCjw/cGhwCnJlcXVpcmUgJ1ZlbmRvci9hdXRvbG9hZC5waHAnOwp1c2UgQXdzXENvbW1vblxBd3M7Cgp0cnkgewoJJGhvc3RuYW1lID0gJF9TRVJWRVJbJ0hUVFBfSE9TVCddOwoJJGRhc2ggPSBzdHJwb3MoJGhvc3RuYW1lLCAiLSIpOwoJJHByZWZpeCA9IHN1YnN0cigkaG9zdG5hbWUsIDAsICRkYXNoKTsKCSR0YWJsZU5hbWUgPSAkcHJlZml4IC4gJy1oZWxsby1hd3MnOwoJJHRhYmxlU3RhdHVzID0gZ2V0VGFibGVTdGF0dXMgKCAkdGFibGVOYW1lICk7CgllY2hvICR0YWJsZU5hbWUgLiAnIGlzICcgLiAkdGFibGVTdGF0dXM7Cn0gY2F0Y2ggKCBcRXhjZXB0aW9uICRlICkgewoJdmFyX2R1bXAgKCAkZS0+Z2V0TWVzc2FnZSAoKSApOwp9CmZ1bmN0aW9uIGdldEFXU0ZhY3RvcnkoKSB7CglyZXR1cm4gQXdzOjpmYWN0b3J5ICggYXJyYXkoICdyZWdpb24nID0+ICd1cy1lYXN0LTEnICkgKTsKfQpmdW5jdGlvbiBnZXREeW5hbW9DbGllbnQoKSB7CgkkYXdzID0gZ2V0QXdzRmFjdG9yeSAoICk7CglyZXR1cm4gJGF3cy0+Z2V0ICggJ2R5bmFtb2RiJyApOwp9CmZ1bmN0aW9uIGdldFRhYmxlU3RhdHVzKCR0YWJsZU5hbWUpIHsKCSRyZXN1bHQgPSBnZXREeW5hbW9DbGllbnQgKCktPmRlc2NyaWJlVGFibGUgKCBhcnJheSAoCgkJCSdUYWJsZU5hbWUnID0+ICR0YWJsZU5hbWUgCgkpICk7CglyZXR1cm4gJHJlc3VsdCBbJ1RhYmxlJ10gWydUYWJsZVN0YXR1cyddOwp9CkVPRgo=
```
for reference, the install script, which is base64 encoded above
```
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
```
1. Click "Next"
1. Click "Next"
1. Click "Update"
1. After the update completes, terminate the instance again
1. When the new instance comes back up and is behind the ELB, plug the url into your browser, you should see a message about not having authority
![not-authorized](https://s3.amazonaws.com/uploads.hipchat.com/15441/59702/wpYmOB7UmgtT4I5/upload.png)

## Authority
We'll now give the the instance authority to our dynamo table via the profile we created earlier.

1. Login to the Cloud Formation console
1. Select your stack
1. Click on "Update Stack"
1. Select "Speciy an Amazon S3 template URL" and enter this url: https://s3.amazonaws.com/static.doapps.com/cloud_formation/auth.json
1. Click "Next"
1. Click "Next"
1. Click "Update"
1. After the update completes, refresh the page in the browser, you'll now see that the table is active
![active](https://s3.amazonaws.com/uploads.hipchat.com/15441/59702/k8rwdLb5eaT1NcI/upload.png)

## installing code
1. Install the AWS CLI - http://aws.amazon.com/cli/
1. Create an S3 bucket to hold the code: https://console.aws.amazon.com/s3/home?region=us-east-1
1. Upload the code to the S3 bucket
```
aws s3 cp --recursive webroot_form/ s3://<bucket from above>/aws-tutorial/
```
1. Create a new cloudformation stack with the S3 template url below
https://s3.amazonaws.com/static.doapps.com/cloud_formation/app_install.json
1. Copy the script below to your local filesystem and replace <insert your bucket here> in the script below with the bucket you created earlier.
```
Which is the base64 from below
```
#!/bin/bash

# install php and nginx
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
```
1. Then, base64 encode that script and use as your user data
