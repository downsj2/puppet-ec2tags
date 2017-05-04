require 'facter'
require 'yaml'
begin
    require 'aws-sdk'
    $__sdk_present = true
rescue LoadError
    $__sdk_present = false # fail silently so facter doesn't complain
end

# If we run multiple times in the same interpreter, don't query AWS again
$__ec2_tags = {}

def __gettags(metadata)
    tags_fact = {}	# Different format of the tags hash
    role = nil
    cachedir = '/opt/puppetlabs/puppet/cache/aws-tags'

    Dir.mkdir(cachedir, 0750) unless File.exists?(cachedir)

    instance_id = metadata['instance-id']
    region = metadata['placement']['availability-zone'][0...-1]

    begin
	if $__sdk_present && $__ec2_tags.empty?
	    ec2 = Aws::EC2::Client.new(region:region)
	    instance = ec2.describe_instances(instance_ids:[instance_id])
	    $__ec2_tags = instance.reservations[0].instances[0].tags

	    # Update cached tags
	    File.write("#{cachedir}/#{instance_id}.yaml", YAML::dump($__ec2_tags), { :perm => 0640 })
	end
    rescue
	# Get cached tags
	if File.exists?("#{cachedir}/#{instance_id}.yaml") then
	    $__ec2_tags = YAML::load(File.read("#{cachedir}/#{instance_id}.yaml"))
	end
    end

    $__ec2_tags.each do |tag|
	key = tag["key"].downcase

        if key == 'puppet_role'
	    role = tag["value"]	# role is special
	end

	tags_fact[key] = tag["value"]
    end

    {
	:role => role,
	:region => region,
	:tags => $__ec2_tags,
	:tags_fact => tags_fact
    }
end

Facter.add(:role) do
    confine :kernel => 'Linux'
    confine :dmi do |d|
	d['bios']['version'] =~ /amazon/
    end
    confine :ec2_metadata do |v|
	v != nil
    end

    setcode do
	val = __gettags(Facter.value(:ec2_metadata))
	val[:role]
    end
end

Facter.add(:ec2_data) do
    confine :kernel => 'Linux'
    confine :dmi do |d|
	d['bios']['version'] =~ /amazon/
    end
    confine :ec2_metadata do |v|
	v != nil
    end

    setcode do
	val = __gettags(Facter.value(:ec2_metadata))
	{
	    :region => val[:region],
	    :tags => val[:tags_fact]
	}
    end
end
