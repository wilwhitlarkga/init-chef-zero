#
# zeroframewk_helper library
#

# Place all common methods to zeroframewk server install here.
  require 'securerandom'

  # Generates unique value for bypass of duplicate chef resources
  def adduuid
    "-#{SecureRandom.uuid.split('-').first}"
  end

  # Install package from local repo or any other available repo
  def remote_package(loc)
    hereloc    = loc.scan(/[^\/]+rpm/).first
    hereimport = hereloc.gsub(/\-[0-9]+\.[0-9]+\.[0-9]+.*\.rpm/,'.rpm')
    herename   = hereloc.gsub(/[^a-z]/,'')
    remote_file "/opt/#{hereloc}" do
      source loc
      action :create
    end
    execute "installrpm_#{herename}#{adduuid}" do
      command "yum install -y -q /opt/#{hereloc}"
      action :run
      not_if "rpm -qa | grep #{hereloc[0..-5]}"
    end
end

  # Install package from remote available yum repo
  def yum_getpkg(pkg,force="false")
    if force == "true" then
      execute "yuminstall_#{pkg}_force" do
        command "yum install -y -q #{pkg}"
        action :run
        ignore_failure true
      end
    else
      execute "yuminstall_#{pkg}" do
        command "yum install -y -q #{pkg}"
        action :run
        not_if "rpm -qa | grep #{pkg}"
      end
    end
  end

  # Make idempotent, recursive directories
  def make_dirs(dirs,ownedby='root')
    dirs.each do |thisdir|
      directory thisdir do
        action :create
        user ownedby
        group ownedby
        mode '755'
        recursive true
      end
    end
  end

  # Make simple users based on commonly-defined user template
  def create_user(uname,upass)
    template "/usr/local/bin/creatusr" do
      source "creatusr.erb"
      cookbook "cfserver"
      action :create
      user "root"
      group "root"
      mode "0700"
    end
    execute "creatuser-#{uname}" do
      command "/usr/local/bin/creatusr #{uname} #{upass}"
      sensitive true
      action :run
      not_if "getent passwd #{uname}"
    end
  end

  # Recursive directory chown
  def chown_dirs(dirs,ownedby='root')
    dirs.each do |thisdir|
      execute "chown-#{thisdir}#{adduuid}" do
        command "chown -R #{ownedby}. #{thisdir}"
        action :run
        only_if "test -d #{thisdir}"
      end
    end
  end

  # Shorthand for common template structure
  def make_templates( temps, ownedby='root', chmode='0644' )
    temps.each do |thistemp|
      tempsource = thistemp.scan(/[^\/]+$/).first
      template thistemp do
        source "#{tempsource}.erb"
        action :create
        user ownedby
        group ownedby
        mode chmode
        sensitive true
      end
    end
  end

  # Idempotently append line in file if no line
  def append_if_no_line(addline,location)
    ruby_block "appendifnoline_#{adduuid}" do
      block do
        unless File.readlines(location).include? "#{addline}\n"
          File.open(location,'a') { |f| f.write("#{addline}\n") }
        end
      end
    end
  end

  # Idempotently remove line
  def delete_line(delline,location)
    ruby_block "deleteline_#{adduuid}" do
      block do
        new_file = []
        File.readlines(location).each do |thisline|
          unless thisline == "#{delline}\n"
            new_file << thisline
          end
        end
        File.open(location, "w+") do |f|
          f.puts(new_file)
        end
      end
    end
  end

  # Idempotently modify provided line, or add
  def replace_or_add_line(linepattern,addline,location)
    ruby_block "replaceoraddline_#{adduuid}" do
      block do
        line_replaced = false
        new_file = []
        File.readlines(location).each do |thisline|
          if thisline.include? linepattern
            new_file << addline
            line_replaced = true
          else
            new_file << thisline
          end
        end
        unless line_replaced
          new_file << addline
        end
        File.open(location, "w+") do |f|
          f.puts(new_file)
        end
      end
    end
  end
