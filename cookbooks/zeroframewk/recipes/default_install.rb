#
# zeroframewk::default_install.rb
#

execute 'dont_collect_yum' do
  command "sed -i 's/keepcache=1/keepcache=0/g' /etc/yum.conf"
  action :run
end
include_recipe 'zeroframewk::package'

# Make some initial directories
initdirs = [
  '/opt/zeroframewk/',
  '/var/zeroframewk'
]

make_dirs(initdirs)

# Create initial dummy manifest for OTA download
make_templates(['/var/zeroframewk/server_latest_manifest'])
