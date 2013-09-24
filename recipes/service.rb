#
# Cookbook Name:: openvpn
# Recipe:: service
#

service 'openvpn' do
  action [:enable, :start]
end
