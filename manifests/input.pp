# This resources defines a input for a given beat
#
# @summary This resources defines a input for a given beat
#
# @example
#  elastic_beats::input { 'filebeat_log':
#    beat          => 'filebeat',
#    instance      => 'my instance'
#    configuration => [{
#      'module'  => 'log',
#      'enabled' => true,
#      'paths'   => ['/var/log/my_log'],
#   }]
# }
#

define elastic_beats::input (
  String $instance,
  Enum['absent','present'] $ensure        = $elastic_beats::ensure,
  Tuple                    $configuration = [{}],
  String                   $beat          = 'filebeat',
) {

  $beat_downcase = downcase($beat)

  if $ensure == 'present' {
    file { "/etc/${beat_downcase}/input_${instance}.d/${name}.yml":
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
    file { "/etc/${beat_downcase}/input_${instance}.d/${name}.yml":
      ensure => absent,
      notify => Service["${beat_downcase}_${instance}"],
    }
  }
}
