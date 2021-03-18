Facter.add('installed_beats') do
  confine :kernel => :linux
  setcode do
    `ls /usr/share/`.split("\n").grep(/.*beat/)
  end
end
