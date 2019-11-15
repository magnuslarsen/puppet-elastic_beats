# Overview
This module will install and configure Elastic Beats.

This module works on Debian- and RHEL-based OS'es, with systemd. \
Filebeat, Metricbeat and Auditbeat has been tested.

This module uses the idea of instances, meaning that one Beat will be created for each group of services. I.e to create two Filebeat instances, one monitoring system logs, and one monitoring InfluxDB logs, the configuration would be like so:
```puppet
## INFLUXDB LOGS ##
::elastic_beats::instance { 'influxdb':
  beats                 => ['filebeat'],
  filebeat_output_url   => 'logstash.url:5001',
  kibana_url            => 'kibana.url:5601',
  ingest_pipeline_hosts => ['prod_elasticsearch.domain', 'test_elasticsearch.domain'],
  require               => Class['::elastic_beats'],
}

# Define a Input, and attach to above instance
::elastic_beats::input { 'filebeat_influxdb':
  beat          => 'filebeat',
  instance      => 'influxdb',
  configuration => [{
    'type'  => 'log',
    'paths' => ['/var/log/influxdb/influxd.log'],
  }],
}

## SYSTEM LOGS ##
::elastic_beats::instance { 'syslog':
  beats                 => ['filebeat'],
  filebeat_output_url   => 'logstash.url:5002',
  kibana_url            => 'kibana.url:5601',
  filebeat_modules      => ['system'], # Use the built-in system module for Filebeat
  ingest_pipeline_hosts => ['prod_elasticsearch.domain', 'test_elasticsearch.domain'],
  require               => Class['::elastic_beats'],
}
```

To use a Filebeat module, but with custom settings, one would do this:
```puppet
::elastic_beats::instance { 'audit':
  auditbeat_output_url  => "logstash.url:5003",
  beats                 => ['auditbeat'],
  kibana_url            => "kibana.url:5601",
  ingest_pipeline_hosts => ['prod_elasticsearch.domain', 'test_elasticsearch.domain'],
  require               => Class['::elastic_beats'],
}

# Define a Module, and attach to above instance
::elastic_beats::module { 'auditbeat_system':
  beat          => 'auditbeat',
  instance      => 'audit',
  configuration => [{
    'module'                       => 'system',
    'enabled'                      => true,
    'period'                       => '1m',
    'user.detect_password_changes' => true,
    'login.btmp_file_pattern'      => '/var/log/btmp*',
    'login.wtmp_file_pattern'      => '/var/log/wtmp*',
    'state.period'                 => '12h',
    'datasets'                     => [
      'host',
      'login',
      'package',
      'process',
      'socket',
      'user',
    ],
  }],
}

::elastic_beats::module { 'auditbeat_auditd':
  beat          => 'auditbeat',
  instance      => 'audit',
  configuration => [{
    'module'           => 'auditd',
    'enabled'          => true,
    'backlog_limit'    => 32768,
    'failure_mode'     => 'log',
    'audit_rule_files' => '/etc/auditbeat/audit.rules.d/*.rules',
  }],
  require       => File['/etc/auditbeat/audit.rules.d/my_rules.rules'], # File type is not listed here, but needs to be defined
}
```
