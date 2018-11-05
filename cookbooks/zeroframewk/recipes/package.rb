#
# zeroframewk::package
#

# Need wget to get remote packages for applications
yum_getpkg('wget')

# Provides netstat
yum_getpkg('net-tools')

# Provides lsof
yum_getpkg('lsof')

# Provides tree
yum_getpkg('tree')

# Provides vim
yum_getpkg('vim')

# Install application packages (disabled)
data_bag_item('applications', 'install')['rpm_versions'].each do |appname,appver|
#    remote_package "http://OUR_RPM_PACKAGE_LOCATION/cfserver7/#{appname}-#{appver}.noarch.rpm"
#  end
end
