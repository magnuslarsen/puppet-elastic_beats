# @dependencies elastic repo has to be defined
#   class { '::elastic_stack::repo':
#     version => $elastic_version,
#   }
#
# @summary Defines the base class for this module
#
# @example
#   class { '::elastic_beats':
#     ensure          => 'present'
#     beats_ensure    => 'latest',
#     output_password => $logstash_password,
#     output_username => $logstash_username,
#     require         => Class['::elastic_stack::repo'],
#   }
#
class elastic_beats (
  String $output_password,
  String $output_username,
  Enum['absent','present'] $ensure = 'present',
  String $beats_ensure             = 'latest',
) {

  # We don't need the original beat service anymore, since we use instances
  $::installed_beats.each |String $beat| {
    Service { $beat:
      ensure => stopped,
      enable => mask,
    }
  }

}
