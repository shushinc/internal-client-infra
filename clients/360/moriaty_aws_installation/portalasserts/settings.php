<?php

$databases['default']['default'] = array (
  'database' => "{{ db_name }}",
  'username' => "{{ db_user }}",
  'password' => "{{ db_password }}",
  'prefix' => '',
  'host' => "{{ db_host }}",
  'port' => '3306',
  'driver' => 'mysql',
  'namespace' => 'Drupal\\mysql\\Driver\\Database\\mysql',
  'autoload' => 'core/modules/mysql/src/Driver/Database/mysql/',
);


// $settings['config_sync_directory'] = '/var/www/html/shushportal/web/sites/default/files/config';
// $settings['config_sync_directory'] = '/var/www/html/shushportal/web/sites/default/files/config/sync';

$settings['config_sync_directory'] = '/var/www/html/shushportal/config/sync';
$settings['file_private_path'] = '/var/www/html/shushportal/private-files';
$settings['update_free_access'] = FALSE;
$settings['allow_authorize_operations'] = FALSE;
// $settings['file_public_path'] = '/var/www/html/shushportal/web/sites/default/files';
$settings['file_public_path'] = 'var/www/html/shushportal/web/sites/default/files';
$settings['file_temp_path'] = '/tmp';

#$settings['reverse_proxy'] = TRUE;
#$settings['reverse_proxy_addresses'] = ['127.0.0.1', '0.0.0.0'];

$salt_file = $settings['file_private_path'] ."/salt.txt";
if(!file_exists($salt_file)) {
    file_put_contents($salt_file, 'secret');
}
$settings['hash_salt'] = file_get_contents($salt_file);

if(file_exists('/var/www/html/shushportal/__PORTAL_NAME__/settings.custom.php')) {
    include '/var/www/html/shushportal/__PORTAL_NAME__/settings.custom.php';
}
