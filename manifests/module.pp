# This resources defines a module for a given beat
#
# @summary This resources defines a module for a given beat
#
# @example
#  elastic_beats::module { 'filebeat_log':
#    beat          => 'filebeat',
#    instance      => 'my instance'
#    configuration => [{
#      'module'    => 'system',
#      'enabled'   => true,
#      'var.paths' => ['/var/log/my_log'],
#   }]
# }
#

define elastic_beats::module (
  Enum[
    'auditbeat',
    'filebeat',
    'heartbeat',
    'journalbeat',
    'metricbeat',
    'packetbeat'
  ] $beat,
  String $instance,
  Enum['absent','present'] $ensure        = $elastic_beats::ensure,
  Tuple                    $configuration = [{}],
) {

  $beat_downcase = downcase($beat)

  if $ensure == 'present' {
    file { "/etc/${beat_downcase}/conf_${instance}.d/${name}.yml":
      ensure  => 'file',
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      replace => true,
      notify  => Service["${beat_downcase}_${instance}"],
      content => epp("${module_name}/module/module.yml.epp", {
        'configuration' => $configuration,
      }),
    }
  }
  else {
    file { "/etc/${beat_downcase}/conf_${instance}.d/${name}.yml":
      ensure => absent,
      notify => Service["${beat_downcase}_${instance}"],
    }
  }
}
