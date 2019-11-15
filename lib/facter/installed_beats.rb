Facter.add('installed_beats') do
  setcode do
    `ls /usr/share/`.split("\n").grep(/.*beat/)
  end
end
