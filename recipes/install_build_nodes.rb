workspace = '/var/opt/delivery/workspace'
delivery_databag = data_bag_item('automate', 'automate')

chef_ingredient 'chefdk'

directory '/etc/chef/trusted_certs' do
  action :create
  recursive true
end

template '/etc/chef/client.rb' do
  source 'build-node-client.rb.erb'
end

%W(#{node['chef_server']['fqdn']} #{node['chef_automate']['fqdn']}).each do |server|
  execute "fetch ssl cert for #{server}" do
    command "knife ssl fetch https://#{server} -c /etc/chef/client.rb"
  end
end

directory workspace do
  action :create
  recursive true
end

group 'dbuild'

user 'dbuild' do
  home '/var/opt/delivery/workspace'
  group 'dbuild'
end

%w(.chef bin lib etc).each do |dir|
  directory "#{workspace}/#{dir}"
end

execute 'Change workspace permissions' do
  command 'chown 0755 /var/opt/delivery -R'
end

%w(etc/builder_key .chef/builder_key).each do |builder_key|
  file "#{workspace}/#{builder_key}" do
    content delivery_databag['builder_pem']
    mode 0600
    owner 'root'
    group 'root'
  end
end

%w(etc/delivery_key .chef/delivery_key).each do |delivery_key|
  file "#{workspace}/#{delivery_key}" do
    content delivery_databag['user_pem']
    mode 0600
    owner 'root'
    group 'root'
  end
end

%w(etc/delivery.rb .chef/knife.rb).each do |knife_config|
  cookbook_file "#{workspace}/#{knife_config}" do
    source 'config.rb'
    mode 0644
    owner 'dbuild'
    group 'dbuild'
  end
end

cookbook_file "#{workspace}/bin/git_ssh" do
  source 'git-ssh-wrapper'
  mode 0755
end

cookbook_file "#{workspace}/bin/delivery-cmd" do
  source 'delivery-cmd'
  mode 00755
  owner 'dbuild'
  group 'dbuild'
end

execute 'chown workspace to dbuild' do
  command "chown dbuild:dbuild -R #{workspace}"
end

file '/etc/chef/client.pem' do
  owner 'root'
  group 'dbuild'
end

directory '/etc/chef/trusted_certs' do
  mode 00755
end

file '/etc/chef/client.rb' do
  mode 00755
end

execute 'chmod trusted certs' do
  command 'chmod 0644 /etc/chef/trusted_certs/*'
end

file '/etc/chef/client.pem' do
  mode 0640
end

include_recipe 'chef-services::install_push_jobs'
