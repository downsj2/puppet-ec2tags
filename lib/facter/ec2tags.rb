require 'facter'
require 'yaml'

def gettags
    cachedir = '/opt/puppetlabs/puppet/cache/aws-tags'
    metadata = Facter.value(:ec2_metadata)
    instance_id = metadata['instance-id']
    region = metadata['placement']['availability-zone'][0...-1]

    begin
        require 'aws-sdk'

        ec2 = Aws::EC2::Client.new(region:region)
        instance = ec2.describe_instances(instance_ids:[instance_id])
        tags = instance.reservations[0].instances[0].tags
    rescue
        begin
            tags = YAML::load(File.read("#{cachedir}/#{instance_id}.yaml"))
        rescue
            tags = {}
        end
    else
        FileUtils.mkpath(cachedir, :mode => 0750)
        File.write("#{cachedir}/#{instance_id}.yaml", YAML::dump(tags), { :perm => 0640 })
    end

    tags
end

def getinfo
    tags = gettags()
    metadata = Facter.value(:ec2_metadata)
    region = metadata['placement']['availability-zone'][0...-1]
    role = nil
    tags_fact = {}

    tags.each do |tag|
        key = tag["key"].downcase
        if key == 'puppet_role' then
            role = tag["value"] # role is special
        end
        tags_fact[key] = tag["value"]
    end

    {
        :role => role,
        :region => region,
        :tags => tags,
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
        getinfo()[:role]
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
        info = getinfo()
        {
            :region => info[:region],
            :tags => info[:tags_fact]
        }
    end
end
