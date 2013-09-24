#
# Cookbook Name:: openvpn
# Recipe:: setup
#

routes = node['openvpn']['routes']
routes << node['openvpn']['push'] if node['openvpn'].attribute?('push')
node.default['openvpn']['routes'] = routes.flatten

key_dir = node["openvpn"]["key_dir"]
key_size = node["openvpn"]["key"]["size"]

package "openvpn" do
  action :install
end

directory key_dir do
  owner "root"
  group "root"
  mode 0755
end

directory "/etc/openvpn/easy-rsa" do
  owner "root"
  group "root"
  mode 0755
end

%w{openssl.cnf pkitool vars Rakefile revoke-full}.each do |f|
  template "/etc/openvpn/easy-rsa/#{f}" do
    source "#{f}.erb"
    owner "root"
    group "root"
    mode 0755
  end
end

template "/etc/openvpn/server.up.sh" do
  source "server.up.sh.erb"
  owner "root"
  group "root"
  mode 0755
  notifies :restart, "service[openvpn]"
end

template "#{key_dir}/openssl.cnf" do
  source "openssl.cnf.erb"
  owner "root"
  group "root"
  mode 0644
end

file "#{key_dir}/index.txt" do
  owner "root"
  group "root"
  mode 0600
  action :create
end

file "#{key_dir}/serial" do
  content "01"
  not_if { ::File.exists?("#{key_dir}/serial") }
end

# Use unless instead of not_if otherwise OpenSSL::PKey::DH runs every time.
unless ::File.exists?("#{key_dir}/dh#{key_size}.pem")
  require 'openssl'
  file "#{key_dir}/dh#{key_size}.pem" do
    content OpenSSL::PKey::DH.new(key_size).to_s
    owner "root"
    group "root"
    mode 0600
  end
end

bash "openvpn-initca" do
  environment("KEY_CN" => "#{node['openvpn']['key']['org']} CA")
  code <<-EOF
    openssl req -batch -days #{node["openvpn"]["key"]["ca_expire"]} \
      -nodes -new -newkey rsa:#{key_size} -sha1 -x509 \
      -keyout #{node["openvpn"]["signing_ca_key"]} \
      -out #{node["openvpn"]["signing_ca_cert"]} \
      -config #{key_dir}/openssl.cnf
  EOF
  not_if { ::File.exists?(node["openvpn"]["signing_ca_cert"]) }
end

bash "openvpn-server-key" do
  environment("KEY_CN" => "server")
  code <<-EOF
    openssl req -batch -days #{node["openvpn"]["key"]["expire"]} \
      -nodes -new -newkey rsa:#{key_size} -keyout #{key_dir}/server.key \
      -out #{key_dir}/server.csr -extensions server \
      -config #{key_dir}/openssl.cnf && \
    openssl ca -batch -days #{node["openvpn"]["key"]["ca_expire"]} \
      -out #{key_dir}/server.crt -in #{key_dir}/server.csr \
      -extensions server -md sha1 -config #{key_dir}/openssl.cnf
  EOF
  not_if { ::File.exists?("#{key_dir}/server.crt") }
end

bash "openvpn-crl" do
  environment("KEY_CN" => "#{node["openvpn"]["key"]["org"]} CA")
  code <<-EOF
    openssl ca -gencrl -out #{node["openvpn"]["crl"]} -config #{node["openvpn"]["key_dir"]}/openssl.cnf
  EOF
  not_if { ::File.exists?(node["openvpn"]["crl"]) }
end

template "/etc/openvpn/server.conf" do
  source "server.conf.erb"
  owner "root"
  group "root"
  mode 0644
  notifies :restart, "service[openvpn]"
end

