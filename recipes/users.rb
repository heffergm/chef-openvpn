#
# Cookbook Name:: openvpn
# Recipe:: users
#

search("users", "*:*") do |u|
  execute "generate-openvpn-#{u['id']}" do
    command "./pkitool #{u['id']}"
    cwd "/etc/openvpn/easy-rsa"
    environment(
      'EASY_RSA' => '/etc/openvpn/easy-rsa',
      'KEY_CONFIG' => '/etc/openvpn/easy-rsa/openssl.cnf',
      'KEY_DIR' => node["openvpn"]["key_dir"],
      'CA_EXPIRE' => node["openvpn"]["key"]["ca_expire"].to_s,
      'KEY_EXPIRE' => node["openvpn"]["key"]["expire"].to_s,
      'KEY_SIZE' => node["openvpn"]["key"]["size"].to_s,
      'KEY_COUNTRY' => node["openvpn"]["key"]["country"],
      'KEY_PROVINCE' => node["openvpn"]["key"]["province"],
      'KEY_CITY' => node["openvpn"]["key"]["city"],
      'KEY_ORG' => node["openvpn"]["key"]["org"],
      'KEY_EMAIL' => node["openvpn"]["key"]["email"]
    )
    not_if { ::File.exists?("#{node["openvpn"]["key_dir"]}/#{u['id']}.crt") }
  end

  %w{ conf ovpn }.each do |ext|
    template "#{node["openvpn"]["key_dir"]}/#{u['id']}.#{ext}" do
      source "client.conf.erb"
      variables :username => u['id']
    end
  end

  execute "create-openvpn-tar-#{u['id']}" do
    cwd node["openvpn"]["key_dir"]
    command <<-EOH
      tar zcf #{u['id']}.tar.gz ca.crt #{u['id']}.crt #{u['id']}.key #{u['id']}.conf #{u['id']}.ovpn
    EOH
    not_if { ::File.exists?("#{node["openvpn"]["key_dir"]}/#{u['id']}.tar.gz") }
  end
end
