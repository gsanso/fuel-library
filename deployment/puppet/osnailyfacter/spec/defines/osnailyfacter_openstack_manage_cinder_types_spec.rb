require 'spec_helper'

describe 'osnailyfacter::openstack::manage_cinder_types' do

  let :facts do
    {
      :osfamily               => 'Debian',
      :operatingsystem        => 'Ubuntu',
      :operatingsystemrelease => '16.04',
      :concat_basedir         => '/var/lib/puppet/concat'
    }
  end


  context 'with a present type' do
    let(:title) { 'volumes_lvm' }

    let(:params) do
      {
        :ensure => 'present',
        :volume_backend_names => {
          'volumes_lvm' => 'LVM-backend'
        }
      }
    end

    it 'should include a cinder_type' do
      is_expected.to contain_cinder_type('volumes_lvm').with(
        :properties => ["volume_backend_name=LVM-backend"]
      )
    end
  end

  context 'with an absent type' do
    let(:title) { 'volumes_lvm' }

    let(:params) do
      {
        :ensure => 'absent',
      }
    end

    it 'should include a cinder_type with absent' do
      is_expected.to contain_cinder_type('volumes_lvm').with(
        :ensure => 'absent',
      )
    end
  end
end
