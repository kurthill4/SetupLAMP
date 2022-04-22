<?php

if (getenv('SDMC_ENV') === '$ENV') {
  $databases = [
    'default' =>
    [
      'default' =>
      [
        'database' => '$DATABASE',
        'username' => '$USERNAME',
        'password' => '$PASSWORD',
        'host' => 'localhost',
        'port' => '3306',
        'namespace' => 'Drupal\\Core\\Database\\Driver\\mysql',
        'driver' => 'mysql',
        'prefix' => '',
      ],
    ],
  ];

  #$config['config_split.config_split.local']['status'] = FALSE;
  #$config['config_split.config_split.dev']['status'] = TRUE;
  #$config['config_split.config_split.stage']['status'] = FALSE;
  #$config['config_split.config_split.prod']['status'] = FALSE;

  $config['google_analytics.settings']['account'] = 'UA-XXXXXXXX-X';

  // Memcache configuration.
  $settings['memcache']['servers'] = ['127.0.0.1:11211' => 'default'];
  $settings['memcache']['bins'] = ['default' => 'default'];
  $settings['memcache']['key_prefix'] = 'dev';
  $settings['cache']['default'] = 'cache.backend.memcache';
}
