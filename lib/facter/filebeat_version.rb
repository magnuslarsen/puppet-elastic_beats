Facter.add('filebeat_version') do
  confine :kernel => :linux
  setcode do
    filebeat_ver = Facter::Util::Resolution.exec('filebeat version | sed -E \'s/^filebeat version ([0-9\\.]+)\\s.*/\\1/\'')
    filebeat_ver.match(%r{\d+\.\d+\.\d+})[0] if filebeat_ver
  end
end
