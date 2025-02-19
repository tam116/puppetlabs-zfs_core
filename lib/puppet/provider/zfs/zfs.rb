Puppet::Type.type(:zfs).provide(:zfs) do
  desc 'Provider for zfs.'

  commands zfs: 'zfs'

  def self.instances
    zfs(:list, '-H').split("\n").map do |line|
      name, _used, _avail, _refer, _mountpoint = line.split(%r{\s+})
      new(name: name, ensure: :present)
    end
  end

  def add_properties
    properties = []
    Puppet::Type.type(:zfs).validproperties.each do |property|
      next if property == :ensure
      if (value = @resource[property]) && value != ''
        if property == :volsize
          properties << '-V' << value.to_s
        else
          properties << '-o' << "#{property}=#{value}"
        end
      end
    end
    properties
  end

  def create
    zfs(*([:create] + add_properties + [@resource[:name]]))
  end

  def destroy
    zfs(:destroy, @resource[:name])
  end

  def exists?
    zfs(:list, @resource[:name])
    true
  rescue Puppet::ExecutionFailure
    false
  end

  # On FreeBSD zoned is called jailed
  def container_property
    case Facter.value('os.name')
    when 'FreeBSD'
      :jailed
    else
      :zoned
    end
  end

  PARAMETER_UNSET_OR_NOT_AVAILABLE = '-'.freeze unless defined? PARAMETER_UNSET_OR_NOT_AVAILABLE

  # https://docs.oracle.com/cd/E19963-01/html/821-1448/gbscy.html
  # shareiscsi (added in build 120) was removed from S11 build 136
  # aclmode was removed from S11 in build 139 but it may have been added back
  # acltype is for ZFS on Linux, and allows disabling or enabling POSIX ACLs
  # http://webcache.googleusercontent.com/search?q=cache:-p74K0DVsdwJ:developers.slashdot.org/story/11/11/09/2343258/solaris-11-released+&cd=13
  [:aclmode, :acltype, :shareiscsi, :overlay].each do |field|
    # The zfs commands use the property value '-' to indicate that the
    # property is not set. We make use of this value to indicate that the
    # property is not set since it is not available. Conversely, if these
    # properties are attempted to be unset, and resulted in an error, our
    # best bet is to catch the exception and continue.
    define_method(field) do
      zfs(:get, '-H', '-o', 'value', field, @resource[:name]).strip
    rescue
      PARAMETER_UNSET_OR_NOT_AVAILABLE
    end
    define_method(field.to_s + '=') do |should|
      zfs(:set, "#{field}=#{should}", @resource[:name])
    rescue
      PARAMETER_UNSET_OR_NOT_AVAILABLE
    end
  end

  [:aclinherit, :atime, :canmount, :checksum,
   :compression, :copies, :dedup, :devices, :exec, :logbias,
   :mountpoint, :nbmand, :primarycache, :quota, :readonly,
   :recordsize, :refquota, :refreservation, :relatime, :reservation,
   :secondarycache, :setuid, :sharenfs, :sharesmb,
   :snapdir, :sync, :version, :volsize, :vscan, :xattr].each do |field|
    define_method(field) do
      zfs(:get, '-H', '-o', 'value', field, @resource[:name]).strip
    end

    define_method(field.to_s + '=') do |should|
      zfs(:set, "#{field}=#{should}", @resource[:name])
    end
  end

  define_method(:zoned) do
    zfs(:get, '-H', '-o', 'value', container_property, @resource[:name]).strip
  end

  define_method('zoned=') do |should|
    zfs(:set, "#{container_property}=#{should}", @resource[:name])
  end
end
