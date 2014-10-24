<?php

$fname 	= $_POST['fname'];
$lname 	= $_POST['lname'];
$email 	= $_POST['email'];

echo "
	<script type=\"text/javascript\">function goBack(){window.history.back();}</script>
	<span style=\"font-size:20px;font-weight:bold;\">$fname $lname's</span> email address is <a href=\"mailto:$email\">$email</a><br /><br />
	<button onclick=\"goBack()\">Click here to go back</button>
";

?>