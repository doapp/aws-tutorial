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
	return Aws::factory ( 'config.php' );
}
function getDynamoClient() {
	$aws = getAwsFactory ( array (
			'region' => 'us-east-1' 
	) );
	return $aws->get ( 'dynamodb' );
}
function getTableStatus($tableName) {
	$result = getDynamoClient ()->describeTable ( array (
			'TableName' => $tableName 
	) );
	return $result ['Table'] ['TableStatus'];
}
