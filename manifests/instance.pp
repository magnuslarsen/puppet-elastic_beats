# This resource creates a instance resource, needed for beats and its modules
#
# @summary Installs configured beats
#
# @example
#   ::elastic_beats::instance { 'audit':
#     beats               => ['auditbeat', 'filebeat'],
#     beats_ensure        => 'latest',
#     filebeat_output_url => 'logstash.clm-prod.jppol.net:5000',
#     kibana_url          => 'kibana.clm-prod.jppol.net:5601',
#   }
#
# @param $absent_beats             - Which beats to remove from an instance (without removing the whole instance)
# @param $beats                    - Which beats to install
# @param $kibana_url               - The URL to Kibana
# @param $output_password          - Which password to use against Logstash
# @param $beats_ensure             - What version the beats should be
# @param $ensure                   - Whether this resource should be present or absent
# @param $filebeat_modules         - Which modules to enable in Filebeat with default configuration
# @param $migration                - Whether migrating to a new version or not
# @param $monitor_enabled          - If the beat should report back to Kibana (Monitoring page)
# @param $auditbeat_output_url     - The output url for Auditbeat
# @param $filebeat_output_url      - The output url for Filebeat
# @param $functionbeat_output_url  - The output url for Functionbeat
# @param $heartbeat_output_url     - The output url for Heartbeat
# @param $http_protocol            - Whether to use HTTP or HTTPS
# @param $journalbeat_output_url   - The output url for Journalbeat
# @param $metricbeat_output_url    - The output url for Metricbeat
# @param $monitor_password         - Which password to use against Kibana (for monitoring only)
# @param $monitor_url              - The URL to Kibana (for monitoring only)
# @param $monitor_username         - Which username to use against Kibana (for monitoring only)
# @param $output_type              - Which output to use (use 'logstash')
# @param $output_username          - Which username to use against Logstash
# @param $packetbeat_output_url    - The output url for Packetbeat
# @param $ingest_pipeline_hosts    - The hosts which to upload ingest pipelines to
# @param $ingest_pipeline_port     - The port used to upload ingest pipelines
# @param $ingest_pipeline_protocol - The protocol used to upload ingest pipelines
#
define elastic_beats::instance (
  Array[Enum[
    'auditbeat',
    'filebeat',
    'functionbeat',
    'heartbeat',
    'journalbeat',
    'metricbeat',
    'packetbeat',
  ]] $beats,
  String                   $kibana_url,
  Array                    $ingest_pipeline_hosts,
  Enum['http', 'https']    $ingest_pipeline_protocol = 'https',
  Integer                  $ingest_pipeline_port     = 9200,
  Array[Enum[
    'auditbeat',
    'filebeat',
    'functionbeat',
    'heartbeat',
    'journalbeat',
    'metricbeat',
    'packetbeat',
  ]]                       $absent_beats            = [],
  Array                    $filebeat_modules        = [],
  Boolean                  $migration               = false,
  Boolean                  $monitor_enabled         = false,
  Enum['absent','present'] $ensure                  = $elastic_beats::ensure,
  String                   $beats_ensure            = $elastic_beats::beats_ensure,
  String                   $http_protocol           = 'https',
  String                   $output_password         = $elastic_beats::output_password,
  String                   $output_type             = 'logstash',
  Variant[String,Undef]    $auditbeat_output_url    = undef,
  Variant[String,Undef]    $filebeat_output_url     = undef,
  Variant[String,Undef]    $functionbeat_output_url = undef,
  Variant[String,Undef]    $heartbeat_output_url    = undef,
  Variant[String,Undef]    $journalbeat_output_url  = undef,
  Variant[String,Undef]    $metricbeat_output_url   = undef,
  Variant[String,Undef]    $monitor_password        = undef,
  Variant[String,Undef]    $monitor_url             = undef,
  Variant[String,Undef]    $monitor_username        = 'beats_system',
  Variant[String,Undef]    $output_username         = $elastic_beats::output_username,
  Variant[String,Undef]    $packetbeat_output_url   = undef,
) {


  # Install beats
  ensure_packages($beats, {
    ensure => $beats_ensure,
  })

  # Load ingest pipelines only if not already loaded for that specific version
  $ingest_pipeline_hosts.each |String $host| {
    exec { "filebeat_${name}_ingest_pipelines_${host}":
      path    => ['/bin', '/usr/bin'],
      command => @("COMMAND"/L),
        filebeat setup --pipelines --modules "$(ls -m /usr/share/filebeat/module/ | tr -d "\n" | tr -d " ")" \
        -c filebeat_${name}.yml \
        -E 'output.logstash.enabled=false' \
        -E 'output.elasticsearch.hosts=["${host}:${ingest_pipeline_port}"]' \
        -E 'output.elasticsearch.username="${output_username}"' \
        -E 'output.elasticsearch.password="${output_password}"' \
        -E 'output.elasticsearch.protocol="${ingest_pipeline_protocol}"' \
        -E 'setup.ilm.enabled="false"'
        |-COMMAND
      unless  => "[ $(curl -XGET \"${ingest_pipeline_protocol}://${host}:${ingest_pipeline_port}/_ingest/pipeline/filebeat-${::filebeat_version}*\" -u ${output_username}:${output_password} -w '%{http_code}' -s -o /dev/null) -eq 200 ] && exit 0 || exit 1",
      timeout => 10,
      require => File["/etc/filebeat/filebeat_${name}.yml"],
    }
  }

  # Reload the configuration files on demand
  exec { "daemon_reload_${name}":
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
  }

  if $ensure == 'present' {
    $beats.each |String $beat| {
      $beat_downcase = downcase($beat)

      case $beat_downcase {
        ## FILEBEAT ##
        # Filebeat is different. It has inputs and modules has to be listed in the main config
        'filebeat': {

          if $filebeat_output_url == '' or $filebeat_output_url == undef {
            fail('Logstash URL is empty!')
          }

          file { "/etc/filebeat/conf_${name}.d":
            ensure => directory,
            owner  => 'root',
            group  => 'root',
            mode   => '0600',
          }

          file { "/etc/filebeat/input_${name}.d":
            ensure => directory,
            owner  => 'root',
            group  => 'root',
            mode   => '0600',
          }

          file { "/etc/filebeat/filebeat_${name}.yml":
            ensure  => 'file',
            owner   => 'root',
            group   => 'root',
            mode    => '0600',
            replace => true,
            notify  => Service["filebeat_${name}"],
            content => epp("${module_name}/filebeat/filebeat.yml.epp", {
              'filebeat_modules' => $filebeat_modules,
              'http_protocol'    => $http_protocol,
              'kibana_url'       => $kibana_url,
              'migration'        => $migration,
              'monitor_enabled'  => $monitor_enabled,
              'monitor_password' => $monitor_password,
              'monitor_url'      => $monitor_url,
              'monitor_username' => $monitor_username,
              'name'             => $name,
              'output_password'  => $output_password,
              'output_type'      => $output_type,
              'output_url'       => $filebeat_output_url,
              'output_username'  => $output_username,
            }),
          }
        }

        ## REST ##
        # All of these require the same structure
        default: {

          $output_url = $beat_downcase ? {
            'auditbeat'    => $auditbeat_output_url,
            'functionbeat' => $functionbeat_output_url,
            'journalbeat'  => $journalbeat_output_url,
            'metricbeat'   => $metricbeat_output_url,
            'packetbeat'   => $packetbeat_output_url,
          }

          if $output_url == '' or $output_url == undef {
            fail('Logstash URL is empty!')
          }

          file { "/etc/${beat_downcase}/conf_${name}.d":
            ensure => directory,
            owner  => 'root',
            group  => 'root',
            mode   => '0600',
          }

          file { "/etc/${beat_downcase}/${beat_downcase}_${name}.yml":
            ensure  => 'file',
            owner   => 'root',
            group   => 'root',
            mode    => '0600',
            replace => true,
            notify  => Service["${beat_downcase}_${name}"],
            content => epp("${module_name}/${beat_downcase}/${beat_downcase}.yml.epp", {
              'http_protocol'    => $http_protocol,
              'kibana_url'       => $kibana_url,
              'migration'        => $migration,
              'monitor_enabled'  => $monitor_enabled,
              'monitor_password' => $monitor_password,
              'monitor_url'      => $monitor_url,
              'monitor_username' => $monitor_username,
              'name'             => $name,
              'output_password'  => $output_password,
              'output_type'      => $output_type,
              'output_url'       => $output_url,
              'output_username'  => $output_username,
            }),
          }
        }
      }

      # Create the systemd unit file, for the specific service
      file { "/lib/systemd/system/${beat_downcase}_${name}.service":
        ensure  => file,
        notify  => Exec["daemon_reload_${name}"],
        mode    => '0664',
        owner   => 'root',
        group   => 'root',
        content => epp("${module_name}/systemd.service.epp", {
          'name' => $name,
          'beat' => $beat_downcase,
        }),
      }

      # Ensure that the beat are running with specific name
      service { "${beat_downcase}_${name}":
        ensure  => running,
        enable  => true,
        require => File["/lib/systemd/system/${beat_downcase}_${name}.service"],
      }

    }
  }
  # Remove the whole instance
  elsif $ensure == 'absent' {
    ['auditbeat','filebeat','functionbeat','heartbeat','journalbeat','metricbeat','packetbeat'].each |String $beat_downcase| {

      # Remove inputs, modules and the configuration file
      file { "/etc/${beat_downcase}/input_${name}.d":
        ensure => absent,
        force  => true,
      }
      file { "/etc/${beat_downcase}/conf_${name}.d":
        ensure => absent,
        force  => true,
      }
      file { "/etc/${beat_downcase}/${beat_downcase}_${name}.yml":
        ensure => absent,
      }

      # Ensure that the beat with specific name is stopped
      service { "${beat_downcase}_${name}":
        ensure => stopped,
        enable => false,
      }

      # Remove the systemd file
      file { "/lib/systemd/system/${beat_downcase}_${name}.service":
        ensure  => absent,
        notify  => Exec["daemon_reload_${name}"],
        require => Service["${beat_downcase}_${name}"],
      }
    }
  }

  # Remove just selective beats
  if !empty($absent_beats) {
    $absent_beats.each |String $beat| {
      $beat_downcase = downcase($beat)

      # Remove inputs, modules and the configuration file
      file { "/etc/${beat_downcase}/input_${name}.d":
        ensure => absent,
        force  => true,
      }
      file { "/etc/${beat_downcase}/conf_${name}.d":
        ensure => absent,
        force  => true,
      }
      file { "/etc/${beat_downcase}/${beat_downcase}_${name}.yml":
        ensure => absent,
      }

      # Ensure that the beat with specific name is stopped
      service { "${beat_downcase}_${name}":
        ensure => stopped,
        enable => false,
      }

      # Remove the systemd file
      file { "/lib/systemd/system/${beat_downcase}_${name}.service":
        ensure  => absent,
        notify  => Exec["daemon_reload_${name}"],
        require => Service["${beat_downcase}_${name}"],
      }
    }
  }
}
