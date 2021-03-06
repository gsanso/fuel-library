# ROLE: primary-controller
# ROLE: controller
require 'spec_helper'
require 'shared-examples'
manifest = 'ironic/ironic.pp'


ironic_enabled = Noop.hiera_structure 'ironic/enabled'
if ironic_enabled

  describe manifest do
    shared_examples 'catalog' do
      default_log_levels_hash = Noop.hiera_hash 'default_log_levels'
      default_log_levels = Noop.puppet_function 'join_keys_to_values',default_log_levels_hash,'='
      primary_controller = Noop.hiera 'primary_controller'
      amqp_durable_queues = Noop.hiera_structure 'ironic/amqp_durable_queues', 'false'
      admin_tenant = Noop.hiera_structure('ironic/tenant', 'services')
      admin_user = Noop.hiera_structure('ironic/auth_name', 'ironic')
      admin_password = Noop.hiera_structure('ironic/user_password', 'ironic')

      database_vip = Noop.hiera('database_vip')
      ironic_db_type = Noop.hiera_structure 'ironic/db_type', 'mysql+pymysql'
      ironic_db_password = Noop.hiera_structure 'ironic/db_password', 'ironic'
      ironic_db_user = Noop.hiera_structure 'ironic/db_user', 'ironic'
      ironic_db_name = Noop.hiera_structure 'ironic/db_name', 'ironic'

      ironic_hash = Noop.hiera_structure 'ironic', {}
      rabbit_hash = Noop.hiera_structure 'rabbit', {}

      service_endpoint = Noop.hiera 'service_endpoint'
      management_vip = Noop.hiera 'management_vip'
      public_vip = Noop.hiera 'public_vip'

      let(:ssl_hash) { Noop.hiera_hash 'use_ssl', {} }
      let(:public_ssl_hash) { Noop.hiera_hash 'public_ssl', {} }
      let(:internal_auth_protocol) { Noop.puppet_function 'get_ssl_property',ssl_hash,{},'keystone','internal','protocol','http' }
      let(:internal_auth_address) { Noop.puppet_function 'get_ssl_property',ssl_hash,{},'keystone','internal','hostname',[service_endpoint, management_vip] }
      let(:internal_auth_url) do
          "#{internal_auth_protocol}://#{internal_auth_address}:5000"
      end
      let(:admin_auth_protocol) { Noop.puppet_function 'get_ssl_property',ssl_hash,{},'keystone','admin','protocol','http' }
      let(:admin_auth_address) { Noop.puppet_function 'get_ssl_property',ssl_hash,{},'keystone','admin','hostname', [service_endpoint, management_vip] }
      let(:admin_auth_uri) do
          "#{admin_auth_protocol}://#{admin_auth_address}:35357"
      end
      let(:public_protocol) { Noop.puppet_function 'get_ssl_property',ssl_hash,public_ssl_hash,'ironic','admin','protocol','http' }
      let(:public_address) { Noop.puppet_function 'get_ssl_property',ssl_hash,public_ssl_hash,'ironic','admin','hostname', public_vip }
      let(:neutron_endpoint_default) {Noop.hiera 'neutron_endpoint', management_vip }
      let(:neutron_protocol) { Noop.puppet_function 'get_ssl_property',ssl_hash,{},'neutron','internal','protocol','http' }
      let(:neutron_address) { Noop.puppet_function 'get_ssl_property',ssl_hash,{},'neutron','internal','hostname', neutron_endpoint_default }
      let(:neutron_url) do
          "#{neutron_protocol}://#{neutron_address}:9696"
      end

      let(:memcached_servers) { Noop.hiera 'memcached_servers' }
      let(:local_memcached_server) { Noop.hiera 'local_memcached_server' }

      let(:transport_url) { Noop.hiera 'transport_url', 'rabbit://guest:password@127.0.0.1:5672/' }

      rabbit_heartbeat_timeout_threshold = Noop.puppet_function 'pick', ironic_hash['rabbit_heartbeat_timeout_threshold'], rabbit_hash['heartbeat_timeout_treshold'], 60
      rabbit_heartbeat_rate = Noop.puppet_function 'pick', ironic_hash['rabbit_heartbeat_rate'], rabbit_hash['heartbeat_rate'], 2

      it 'should configure RabbitMQ Heartbeat parameters' do
        should contain_ironic_config('oslo_messaging_rabbit/heartbeat_timeout_threshold').with_value(rabbit_heartbeat_timeout_threshold)
        should contain_ironic_config('oslo_messaging_rabbit/heartbeat_rate').with_value(rabbit_heartbeat_rate)
      end

      it 'should configure default_log_levels' do
        should contain_ironic_config('DEFAULT/default_log_levels').with_value(default_log_levels.sort.join(','))
      end

      it 'should declare ironic::neutron class correctly' do
        should contain_class('ironic::neutron').with(
          'api_endpoint' => neutron_url,
          'auth_url'     => admin_auth_uri,
          'project_name' => admin_tenant,
          'username'     => admin_user,
          'password'     => admin_password,
        )
      end

      it 'should declare ironic class correctly' do
        should contain_class('ironic').with(
          'default_transport_url' => transport_url,
          'sync_db'               => primary_controller,
          'control_exchange'      => 'ironic',
          'amqp_durable_queues'   => amqp_durable_queues,
          'database_max_retries'  => '-1',
        )
      end

      it 'should declare ironic::api::authtoken class correctly' do
        should contain_class('ironic::api::authtoken').with(
          'username'          => admin_user,
          'password'          => admin_password,
          'project_name'      => admin_tenant,
          'auth_url'          => admin_auth_uri,
          'auth_uri'          => internal_auth_url,
          'memcached_servers' => local_memcached_server,
        )
      end

      it 'ironic config should have propper neutron config options' do
        should contain_ironic_config('neutron/url').with('value' => neutron_url)
        should contain_ironic_config('neutron/auth_url').with('value' => admin_auth_uri)
        should contain_ironic_config('neutron/username').with('value' => admin_user)
        should contain_ironic_config('neutron/password').with('value' => admin_password)
        should contain_ironic_config('neutron/project_name').with('value' => admin_tenant)
      end

      it 'should correctly configure authtoken parameters' do
        should contain_ironic_config('keystone_authtoken/username').with(:value => admin_user)
        should contain_ironic_config('keystone_authtoken/password').with(:value => admin_password)
        should contain_ironic_config('keystone_authtoken/project_name').with(:value => admin_tenant)
        should contain_ironic_config('keystone_authtoken/auth_url').with(:value => admin_auth_uri)
        should contain_ironic_config('keystone_authtoken/auth_uri').with(:value => internal_auth_url)
        should contain_ironic_config('keystone_authtoken/memcached_servers').with(:value => local_memcached_server)
      end

      it 'should declare ironic::api class correctly' do
        should contain_class('ironic::api').with(
          'public_endpoint'      => "#{public_protocol}://#{public_address}:6385"
        )
      end

      it 'should configure the database connection string' do
        if facts[:os_package_type] == 'debian'
          extra_params = '?charset=utf8&read_timeout=60'
        else
          extra_params = '?charset=utf8'
        end
        should contain_class('ironic').with(
          :database_connection => "#{ironic_db_type}://#{ironic_db_user}:#{ironic_db_password}@#{database_vip}/#{ironic_db_name}#{extra_params}"
        )
      end

      it 'should properly configure default transport url' do
        should contain_ironic_config('DEFAULT/transport_url').with_value(transport_url)
      end

      it 'should configure kombu compression' do
        kombu_compression = Noop.hiera 'kombu_compression', facts[:os_service_default]
        should contain_ironic_config('oslo_messaging_rabbit/kombu_compression').with(:value => kombu_compression)
      end

    end # end of shared_examples
    test_ubuntu_and_centos manifest
  end
end
