require 'spec_helper'
require 'crx_packmgr_api_client'
require 'xmlsimple'

describe Puppet::Type.type(:aem_crx_package).provider(:ruby) do

  RSpec::Matchers.define :match_api_config do |expected|
    match do |api|
      actual = api.config
      actual.username == expected.username &&
        actual.password == expected.password &&
        actual.timeout == expected.timeout &&
        actual.host == expected.host &&
        actual.base_path == expected.base_path
    end
  end

  let(:source) do
    File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'files', 'test-1.0.0.zip')
  end

  let(:resource) do
    Puppet::Type.type(:aem_crx_package).new(
      ensure:   :present,
      name:     'test',
      group:    'my_packages',
      home:     '/opt/aem',
      password: 'admin',
      pkg:      'test',
      source:   source,
      timeout:  1,
      username: 'admin',
      version:  '3.0.0'
    )
  end

  let(:provider) do
    provider = described_class.new(resource)
    provider
  end

  let(:exception) do
    Errno::ECONNREFUSED.new
  end

  let(:default_config) do
    config = CrxPackageManager::Configuration.new
    config.configure do |c|
      c.username  = 'admin'
      c.password  = 'admin'
      c.timeout   = 1
      c.host      = 'localhost:4502'
    end
    config
  end

  let(:list_all_installed) do
    path = File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'files', 'pkg_list_all_installed.json')
    file = File.new(path)
    json = JSON.parse(file.read, symbolize_names: true).to_hash
    CrxPackageManager::PackageList.new.build_from_hash(json)
  end

  let(:list_all_present) do
    path = File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'files', 'pkg_list_all_present.json')
    file = File.new(path)
    json = JSON.parse(file.read, symbolize_names: true).to_hash
    CrxPackageManager::PackageList.new.build_from_hash(json)
  end

  let(:list_two_installed) do
    path = File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'files', 'pkg_list_two_installed.json')
    file = File.new(path)
    json = JSON.parse(file.read, symbolize_names: true).to_hash
    CrxPackageManager::PackageList.new.build_from_hash(json)
  end

  let(:list_two_present) do
    path = File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'files', 'pkg_list_two_present.json')
    file = File.new(path)
    json = JSON.parse(file.read, symbolize_names: true).to_hash
    CrxPackageManager::PackageList.new.build_from_hash(json)
  end

  let(:list_one_installed) do
    path = File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'files', 'pkg_list_one_installed.json')
    file = File.new(path)
    json = JSON.parse(file.read, symbolize_names: true).to_hash
    CrxPackageManager::PackageList.new.build_from_hash(json)
  end

  let(:list_one_present) do
    path = File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'files', 'pkg_list_one_present.json')
    file = File.new(path)
    json = JSON.parse(file.read, symbolize_names: true).to_hash
    CrxPackageManager::PackageList.new.build_from_hash(json)
  end

  let(:list_missing) do
    path = File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'files', 'pkg_list_missing.json')
    file = File.new(path)
    json = JSON.parse(file.read, symbolize_names: true).to_hash
    CrxPackageManager::PackageList.new.build_from_hash(json)
  end

  let(:service_response) do
    File.new(File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'files', 'api_response.xml')).read
  end

  let(:service_failure) do
    File.new(File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'files', 'api_error.xml')).read
  end

  let(:service_exec_failure) do
    CrxPackageManager::ServiceExecResponse.new(success: false, msg: 'An Error Occurred')
  end

  describe 'retrieve ensure attribute' do
    shared_examples 'resource_check' do |opts|
      it do
        opts[:port] ||= 4502

        crline = "CONTEXT_ROOT='#{opts[:context_root]}'" if opts[:context_root]
        envdata = <<-EOF
PORT=#{opts[:port]}
#{crline}
        EOF

        config = CrxPackageManager::Configuration.new
        config.configure do |c|
          c.username  = 'admin'
          c.password  = 'admin'
          c.timeout   = 1
          c.host      = "localhost:#{opts[:port]}"
          c.base_path = "/#{opts[:context_root]}/crx/packmgr" if opts[:context_root]
        end

        expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield(envdata)

        expect(
          CrxPackageManager::DefaultApi
        ).to receive(:new).with(match_api_config(config)).and_call_original

        expect_any_instance_of(
          CrxPackageManager::DefaultApi
        ).to receive(:list).with(
          path: '/etc/packages/my_packages/test-3.0.0.zip',
          include_versions: true
        ).and_return(send(opts[:return_val]))

        expect(provider.retrieve).to eq(opts[:expected])
      end
    end

    describe 'package exists' do
      it_should_behave_like(
        'resource_check',
        expected: :present,
        return_val: :list_all_present
      )
    end
    describe 'package does not exist' do
      it_should_behave_like(
        'resource_check',
        expected: :installed,
        return_val: :list_all_installed
      )
    end
    describe 'package does not exist' do
      it_should_behave_like(
        'resource_check',
        expected: :absent,
        return_val: :list_two_installed
      )
    end

    describe 'supports context root' do
      it_should_behave_like(
        'resource_check',
        expected: :installed,
        return_val: :list_all_installed,
        context_root: 'contextroot'
      )
    end

    describe 'supports port' do
      it_should_behave_like(
        'resource_check',
        expected: :present,
        return_val: :list_all_present,
        port: '8080'
      )
    end
    describe 'supports port & context root' do
      it_should_behave_like(
        'resource_check',
        expected: :installed,
        return_val: :list_all_installed,
        context_root: 'contextroot',
        port: '8080'
      )
    end
  end

  describe 'flush' do
    context 'nothing exists' do
      context 'changes to uploaded' do
        let(:resource) do
          Puppet::Type.type(:aem_crx_package).new(
            ensure:   :present,
            name:     'test',
            group:    'my_packages',
            home:     '/opt/aem',
            password: 'admin',
            pkg:      'test',
            source:   source,
            timeout:  1,
            username: 'admin',
            version:  '1.0.0'
          )
        end
        it 'should work' do
          expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield('')

          expect(
            CrxPackageManager::DefaultApi
          ).to receive(:new).with(
            match_api_config(default_config)
          ).and_call_original

          expect_any_instance_of(
            CrxPackageManager::DefaultApi
          ).to receive(:list).with(
            path: '/etc/packages/my_packages/test-1.0.0.zip', include_versions: true
          ).and_return(list_missing, list_one_present)

          expect_any_instance_of(
            CrxPackageManager::DefaultApi
          ).to receive(:service_post).with(
            instance_of(File)
          ).and_return(service_response)

          expect { provider.retrieve }.not_to raise_error
          expect { provider.upload }.not_to raise_error
          expect { provider.flush }.not_to raise_error

          expect(provider.group).to eq(resource[:group])
          expect(provider.name).to eq(resource[:name])
          expect(provider.version).to eq(resource[:version])
          expect(provider.ensure).to eq(resource[:ensure])
        end
      end
      context 'changes to installed' do
        let(:resource) do
          Puppet::Type.type(:aem_crx_package).new(
            ensure:   :installed,
            name:     'test',
            group:    'my_packages',
            home:     '/opt/aem',
            password: 'admin',
            pkg:      'test',
            source:   source,
            timeout:  1,
            username: 'admin',
            version:  '1.0.0'
          )
        end
        it 'should work' do
          expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield('')

          expect(
            CrxPackageManager::DefaultApi
          ).to receive(:new).with(
            match_api_config(default_config)
          ).and_call_original

          expect_any_instance_of(
            CrxPackageManager::DefaultApi
          ).to receive(:list).with(
            path: '/etc/packages/my_packages/test-1.0.0.zip', include_versions: true
          ).and_return(list_missing, list_one_installed)

          # Should upload file
          expect_any_instance_of(
            CrxPackageManager::DefaultApi
          ).to receive(:service_post).with(
            instance_of(File)
          ).and_return(service_response)

          expect_any_instance_of(
            CrxPackageManager::DefaultApi
          ).to receive(:service_exec).with(
            'install', 'test', 'my_packages', '1.0.0'
          ).and_return(service_response)

          expect { provider.retrieve }.not_to raise_error
          expect { provider.install }.not_to raise_error
          expect { provider.flush }.not_to raise_error

          expect(provider.group).to eq(resource[:group])
          expect(provider.name).to eq(resource[:name])
          expect(provider.version).to eq(resource[:version])
          expect(provider.ensure).to eq(resource[:ensure])
        end
      end
    end
    context 'one uploaded' do
      context 'changes to installed' do
        let(:resource) do
          Puppet::Type.type(:aem_crx_package).new(
            ensure:   :installed,
            name:     'test',
            group:    'my_packages',
            home:     '/opt/aem',
            password: 'admin',
            pkg:      'test',
            source:   source,
            timeout:  1,
            username: 'admin',
            version:  '1.0.0'
          )
        end
        it 'should work' do
          expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield('')

          expect(
            CrxPackageManager::DefaultApi
          ).to receive(:new).with(
            match_api_config(default_config)
          ).and_call_original

          expect_any_instance_of(
            CrxPackageManager::DefaultApi
          ).to receive(:list).with(
            path: '/etc/packages/my_packages/test-1.0.0.zip', include_versions: true
          ).and_return(list_one_present, list_one_installed)

          expect_any_instance_of(
            CrxPackageManager::DefaultApi
          ).to receive(:service_exec).with(
            'install', 'test', 'my_packages', '1.0.0'
          ).and_return(service_response)

          expect { provider.retrieve }.not_to raise_error
          expect { provider.install }.not_to raise_error
          expect { provider.flush }.not_to raise_error

          expect(provider.group).to eq(resource[:group])
          expect(provider.name).to eq(resource[:name])
          expect(provider.version).to eq(resource[:version])
          expect(provider.ensure).to eq(resource[:ensure])
        end
      end
      context 'to-be does not match version' do
        context 'uploads new version' do
          let(:resource) do
            Puppet::Type.type(:aem_crx_package).new(
              ensure:   :present,
              name:     'test',
              group:    'my_packages',
              home:     '/opt/aem',
              password: 'admin',
              pkg:      'test',
              source:   source,
              timeout:  1,
              username: 'admin',
              version:  '2.0.0'
            )
          end
          it 'should work' do
            expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield('')

            expect(
              CrxPackageManager::DefaultApi
            ).to receive(:new).with(
              match_api_config(default_config)
            ).and_call_original

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:list).with(
              path: '/etc/packages/my_packages/test-2.0.0.zip', include_versions: true
            ).and_return(list_one_present, list_two_present)

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:service_post).with(
              instance_of(File)
            ).and_return(service_response)

            expect { provider.retrieve }.not_to raise_error
            expect { provider.upload }.not_to raise_error
            expect { provider.flush }.not_to raise_error

            expect(provider.group).to eq(resource[:group])
            expect(provider.name).to eq(resource[:name])
            expect(provider.version).to eq(resource[:version])
            expect(provider.ensure).to eq(resource[:ensure])
          end
        end
        context 'installs new version' do
          let(:resource) do
            Puppet::Type.type(:aem_crx_package).new(
              ensure:   :installed,
              name:     'test',
              group:    'my_packages',
              home:     '/opt/aem',
              password: 'admin',
              pkg:      'test',
              source:   source,
              timeout:  1,
              username: 'admin',
              version:  '2.0.0'
            )
          end
          it 'should work' do
            expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield('')

            expect(
              CrxPackageManager::DefaultApi
            ).to receive(:new).with(
              match_api_config(default_config)
            ).and_call_original

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:list).with(
              path: '/etc/packages/my_packages/test-2.0.0.zip', include_versions: true
            ).and_return(list_one_present, list_two_installed)

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:service_post).with(
              instance_of(File)
            ).and_return(service_response)

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:service_exec).with(
              'install', 'test', 'my_packages', '2.0.0'
            ).and_return(service_response)

            expect { provider.retrieve }.not_to raise_error
            expect { provider.install }.not_to raise_error
            expect { provider.flush }.not_to raise_error

            expect(provider.group).to eq(resource[:group])
            expect(provider.name).to eq(resource[:name])
            expect(provider.version).to eq(resource[:version])
            expect(provider.ensure).to eq(resource[:ensure])
          end
        end
      end
      context 'changes to absent' do
        context 'not uninstalled first - was not installed' do
          let(:resource) do
            Puppet::Type.type(:aem_crx_package).new(
              ensure:   :purged,
              name:     'test',
              group:    'my_packages',
              home:     '/opt/aem',
              password: 'admin',
              pkg:      'test',
              source:   source,
              timeout:  1,
              username: 'admin',
              version:  '1.0.0'
            )
          end
          it 'should work' do
            expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield('')

            expect(
              CrxPackageManager::DefaultApi
            ).to receive(:new).with(
              match_api_config(default_config)
            ).and_call_original

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:list).with(
              path: '/etc/packages/my_packages/test-1.0.0.zip', include_versions: true
            ).and_return(list_one_present, list_missing)

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:service_exec).with(
              'delete', 'test', 'my_packages', '1.0.0'
            ).and_return(service_response)

            expect { provider.retrieve }.not_to raise_error
            expect { provider.purge }.not_to raise_error
            expect { provider.flush }.not_to raise_error

            expect(provider.group).to eq(resource[:group])
            expect(provider.name).to eq(resource[:name])
            expect(provider.version).to eq(resource[:version])
            expect(provider.ensure).to eq(:absent)
          end
        end
        context 'removed but not uninstalled first' do
          let(:resource) do
            Puppet::Type.type(:aem_crx_package).new(
              ensure:   :absent,
              name:     'test',
              group:    'my_packages',
              home:     '/opt/aem',
              password: 'admin',
              pkg:      'test',
              source:   source,
              timeout:  1,
              username: 'admin',
              version:  '1.0.0'
            )
          end
          it 'should work' do
            expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield('')

            expect(
              CrxPackageManager::DefaultApi
            ).to receive(:new).with(
              match_api_config(default_config)
            ).and_call_original

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:list).with(
              path: '/etc/packages/my_packages/test-1.0.0.zip', include_versions: true
            ).and_return(list_one_present, list_missing)

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:service_exec).with(
              'delete', 'test', 'my_packages', '1.0.0'
            ).and_return(service_response)

            expect { provider.retrieve }.not_to raise_error
            expect { provider.remove }.not_to raise_error
            expect { provider.flush }.not_to raise_error

            expect(provider.group).to eq(resource[:group])
            expect(provider.name).to eq(resource[:name])
            expect(provider.version).to eq(resource[:version])
            expect(provider.ensure).to eq(resource[:ensure])
          end
        end
      end
    end
    context 'one installed' do
      context 'changes to uploaded' do
        let(:resource) do
          Puppet::Type.type(:aem_crx_package).new(
            ensure:   :present,
            name:     'test',
            group:    'my_packages',
            home:     '/opt/aem',
            password: 'admin',
            pkg:      'test',
            source:   source,
            timeout:  1,
            username: 'admin',
            version:  '1.0.0'
          )
        end
        it 'should work' do
          expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield('')

          expect(
            CrxPackageManager::DefaultApi
          ).to receive(:new).with(
            match_api_config(default_config)
          ).and_call_original

          expect_any_instance_of(
            CrxPackageManager::DefaultApi
          ).to receive(:list).with(
            path: '/etc/packages/my_packages/test-1.0.0.zip', include_versions: true
          ).and_return(list_one_installed, list_one_present)

          expect_any_instance_of(
            CrxPackageManager::DefaultApi
          ).to receive(:service_exec).with(
            'uninstall', 'test', 'my_packages', '1.0.0'
          ).and_return(service_response)

          expect { provider.retrieve }.not_to raise_error
          expect { provider.upload }.not_to raise_error
          expect { provider.flush }.not_to raise_error

          expect(provider.group).to eq(resource[:group])
          expect(provider.name).to eq(resource[:name])
          expect(provider.version).to eq(resource[:version])
          expect(provider.ensure).to eq(resource[:ensure])
        end
      end
      context 'to-be does not match version' do
        context 'uploads new version' do
          let(:resource) do
            Puppet::Type.type(:aem_crx_package).new(
              ensure:   :present,
              name:     'test',
              group:    'my_packages',
              home:     '/opt/aem',
              password: 'admin',
              pkg:      'test',
              source:   source,
              timeout:  1,
              username: 'admin',
              version:  '2.0.0'
            )
          end
          it 'should work' do
            expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield('')

            expect(
              CrxPackageManager::DefaultApi
            ).to receive(:new).with(
              match_api_config(default_config)
            ).and_call_original

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:list).with(
              path: '/etc/packages/my_packages/test-2.0.0.zip', include_versions: true
            ).and_return(list_one_installed, list_two_present)

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:service_post).with(
              instance_of(File)
            ).and_return(service_response)

            expect { provider.retrieve }.not_to raise_error
            expect { provider.upload }.not_to raise_error
            expect { provider.flush }.not_to raise_error

            expect(provider.group).to eq(resource[:group])
            expect(provider.name).to eq(resource[:name])
            expect(provider.version).to eq(resource[:version])
            expect(provider.ensure).to eq(resource[:ensure])
          end
        end
        context 'installs new version' do
          let(:resource) do
            Puppet::Type.type(:aem_crx_package).new(
              ensure:   :installed,
              name:     'test',
              group:    'my_packages',
              home:     '/opt/aem',
              password: 'admin',
              pkg:      'test',
              source:   source,
              timeout:  1,
              username: 'admin',
              version:  '2.0.0'
            )
          end
          it 'should work' do
            expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield('')

            expect(
              CrxPackageManager::DefaultApi
            ).to receive(:new).with(
              match_api_config(default_config)
            ).and_call_original

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:list).with(
              path: '/etc/packages/my_packages/test-2.0.0.zip', include_versions: true
            ).and_return(list_one_installed, list_two_installed)

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:service_post).with(
              instance_of(File)
            ).and_return(service_response)

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:service_exec).with(
              'install', 'test', 'my_packages', '2.0.0'
            ).and_return(service_response)

            expect { provider.retrieve }.not_to raise_error
            expect { provider.install }.not_to raise_error
            expect { provider.flush }.not_to raise_error

            expect(provider.group).to eq(resource[:group])
            expect(provider.name).to eq(resource[:name])
            expect(provider.version).to eq(resource[:version])
            expect(provider.ensure).to eq(resource[:ensure])
          end
        end
      end
      context 'changes to absent' do
        context 'uninstalled first' do
          let(:resource) do
            Puppet::Type.type(:aem_crx_package).new(
              ensure:   :purged,
              name:     'test',
              group:    'my_packages',
              home:     '/opt/aem',
              password: 'admin',
              pkg:      'test',
              source:   source,
              timeout:  1,
              username: 'admin',
              version:  '1.0.0'
            )
          end
          it 'should work' do
            expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield('')

            expect(
              CrxPackageManager::DefaultApi
            ).to receive(:new).with(
              match_api_config(default_config)
            ).and_call_original

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:list).with(
              path: '/etc/packages/my_packages/test-1.0.0.zip', include_versions: true
            ).and_return(list_one_installed, list_missing)

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:service_exec).with(
              'uninstall', 'test', 'my_packages', '1.0.0'
            ).and_return(service_response)

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:service_exec).with(
              'delete', 'test', 'my_packages', '1.0.0'
            ).and_return(service_response)

            expect { provider.retrieve }.not_to raise_error
            expect { provider.purge }.not_to raise_error
            expect { provider.flush }.not_to raise_error

            expect(provider.group).to eq(resource[:group])
            expect(provider.name).to eq(resource[:name])
            expect(provider.version).to eq(resource[:version])
            expect(provider.ensure).to eq(:absent)
          end
        end
        context 'removed but not uninstalled first' do
          let(:resource) do
            Puppet::Type.type(:aem_crx_package).new(
              ensure: :absent,
              name:     'test',
              group:    'my_packages',
              home:     '/opt/aem',
              password: 'admin',
              pkg:      'test',
              source:   source,
              timeout:  1,
              username: 'admin',
              version:  '1.0.0'
            )
          end
          it 'should work' do
            expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield('')

            expect(
              CrxPackageManager::DefaultApi
            ).to receive(:new).with(
              match_api_config(default_config)
            ).and_call_original

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:list).with(
              path: '/etc/packages/my_packages/test-1.0.0.zip', include_versions: true
            ).and_return(list_one_installed, list_missing)

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:service_exec).with(
              'delete', 'test', 'my_packages', '1.0.0'
            ).and_return(service_response)

            expect { provider.retrieve }.not_to raise_error
            expect { provider.remove }.not_to raise_error
            expect { provider.flush }.not_to raise_error

            expect(provider.group).to eq(resource[:group])
            expect(provider.name).to eq(resource[:name])
            expect(provider.version).to eq(resource[:version])
            expect(provider.ensure).to eq(resource[:ensure])
          end
        end
      end
    end
    context 'two uploaded' do
      context 'changes to installed' do
        let(:resource) do
          Puppet::Type.type(:aem_crx_package).new(
            ensure:   :installed,
            name:     'test',
            group:    'my_packages',
            home:     '/opt/aem',
            password: 'admin',
            pkg:      'test',
            source:   source,
            timeout:  1,
            username: 'admin',
            version:  '2.0.0'
          )
        end
        it 'should work' do
          expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield('')

          expect(
            CrxPackageManager::DefaultApi
          ).to receive(:new).with(
            match_api_config(default_config)
          ).and_call_original

          expect_any_instance_of(
            CrxPackageManager::DefaultApi
          ).to receive(:list).with(
            path: '/etc/packages/my_packages/test-2.0.0.zip', include_versions: true
          ).and_return(list_two_present, list_two_installed)

          expect_any_instance_of(
            CrxPackageManager::DefaultApi
          ).to receive(:service_exec).with(
            'install', 'test', 'my_packages', '2.0.0'
          ).and_return(service_response)

          expect { provider.retrieve }.not_to raise_error
          expect { provider.install }.not_to raise_error
          expect { provider.flush }.not_to raise_error

          expect(provider.group).to eq(resource[:group])
          expect(provider.name).to eq(resource[:name])
          expect(provider.version).to eq(resource[:version])
          expect(provider.ensure).to eq(resource[:ensure])
        end
      end
      context 'to-be does not match version' do
        context 'uploads new version' do
          let(:resource) do
            Puppet::Type.type(:aem_crx_package).new(
              ensure:   :present,
              name:     'test',
              group:    'my_packages',
              home:     '/opt/aem',
              password: 'admin',
              pkg:      'test',
              source:   source,
              timeout:  1,
              username: 'admin',
              version:  '3.0.0'
            )
          end
          it 'should work' do
            expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield('')

            expect(
              CrxPackageManager::DefaultApi
            ).to receive(:new).with(
              match_api_config(default_config)
            ).and_call_original

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:list).with(
              path: '/etc/packages/my_packages/test-3.0.0.zip', include_versions: true
            ).and_return(list_two_present, list_all_present)

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:service_post).with(
              instance_of(File)
            ).and_return(service_response)

            expect { provider.retrieve }.not_to raise_error
            expect { provider.upload }.not_to raise_error
            expect { provider.flush }.not_to raise_error

            expect(provider.group).to eq(resource[:group])
            expect(provider.name).to eq(resource[:name])
            expect(provider.version).to eq(resource[:version])
            expect(provider.ensure).to eq(resource[:ensure])
          end
        end
        context 'installs new version' do
          let(:resource) do
            Puppet::Type.type(:aem_crx_package).new(
              ensure:   :installed,
              name:     'test',
              group:    'my_packages',
              home:     '/opt/aem',
              password: 'admin',
              pkg:      'test',
              source:   source,
              timeout:  1,
              username: 'admin',
              version:  '3.0.0'
            )
          end
          it 'should work' do
            expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield('')

            expect(
              CrxPackageManager::DefaultApi
            ).to receive(:new).with(
              match_api_config(default_config)
            ).and_call_original

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:list).with(
              path: '/etc/packages/my_packages/test-3.0.0.zip', include_versions: true
            ).and_return(list_two_present, list_all_installed)

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:service_post).with(
              instance_of(File)
            ).and_return(service_response)

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:service_exec).with(
              'install', 'test', 'my_packages', '3.0.0'
            ).and_return(service_response)

            expect { provider.retrieve }.not_to raise_error
            expect { provider.install }.not_to raise_error
            expect { provider.flush }.not_to raise_error

            expect(provider.group).to eq(resource[:group])
            expect(provider.name).to eq(resource[:name])
            expect(provider.version).to eq(resource[:version])
            expect(provider.ensure).to eq(resource[:ensure])
          end
        end
      end
      context 'changes to absent' do
        context 'not uninstalled first - was not installed' do
          let(:resource) do
            Puppet::Type.type(:aem_crx_package).new(
              ensure:   :purged,
              name:     'test',
              group:    'my_packages',
              home:     '/opt/aem',
              password: 'admin',
              pkg:      'test',
              source:   source,
              timeout:  1,
              username: 'admin',
              version:  '2.0.0'
            )
          end
          it 'should work' do
            expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield('')

            expect(
              CrxPackageManager::DefaultApi
            ).to receive(:new).with(
              match_api_config(default_config)
            ).and_call_original

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:list).with(
              path: '/etc/packages/my_packages/test-2.0.0.zip', include_versions: true
            ).and_return(list_two_present, list_one_installed)

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:service_exec).with(
              'delete', 'test', 'my_packages', '2.0.0'
            ).and_return(service_response)

            expect { provider.retrieve }.not_to raise_error
            expect { provider.purge }.not_to raise_error
            expect { provider.flush }.not_to raise_error

            expect(provider.group).to eq(resource[:group])
            expect(provider.name).to eq(resource[:name])
            expect(provider.version).to eq(resource[:version])
            expect(provider.ensure).to eq(:absent)
          end
        end
        context 'removed but not uninstalled first' do
          let(:resource) do
            Puppet::Type.type(:aem_crx_package).new(
              ensure:   :absent,
              name:     'test',
              group:    'my_packages',
              home:     '/opt/aem',
              password: 'admin',
              pkg:      'test',
              source:   source,
              timeout:  1,
              username: 'admin',
              version:  '2.0.0'
            )
          end
          it 'should work' do
            expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield('')

            expect(
              CrxPackageManager::DefaultApi
            ).to receive(:new).with(
              match_api_config(default_config)
            ).and_call_original

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:list).with(
              path: '/etc/packages/my_packages/test-2.0.0.zip', include_versions: true
            ).and_return(list_two_present, list_one_installed)

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:service_exec).with(
              'delete', 'test', 'my_packages', '2.0.0'
            ).and_return(service_response)

            expect { provider.retrieve }.not_to raise_error
            expect { provider.remove }.not_to raise_error
            expect { provider.flush }.not_to raise_error

            expect(provider.group).to eq(resource[:group])
            expect(provider.name).to eq(resource[:name])
            expect(provider.version).to eq(resource[:version])
            expect(provider.ensure).to eq(resource[:ensure])
          end
        end
      end
    end
    context 'two installed' do
      context 'changes to uploaded' do
        let(:resource) do
          Puppet::Type.type(:aem_crx_package).new(
            ensure:   :present,
            name:     'test',
            group:    'my_packages',
            home:     '/opt/aem',
            password: 'admin',
            pkg:      'test',
            source:   source,
            timeout:  1,
            username: 'admin',
            version:  '2.0.0'
          )
        end
        it 'should work' do
          expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield('')

          expect(
            CrxPackageManager::DefaultApi
          ).to receive(:new).with(
            match_api_config(default_config)
          ).and_call_original

          expect_any_instance_of(
            CrxPackageManager::DefaultApi
          ).to receive(:list).with(
            path: '/etc/packages/my_packages/test-2.0.0.zip', include_versions: true
          ).and_return(list_two_installed, list_two_present)

          expect_any_instance_of(
            CrxPackageManager::DefaultApi
          ).to receive(:service_exec).with(
            'uninstall', 'test', 'my_packages', '2.0.0'
          ).and_return(service_response)

          expect { provider.retrieve }.not_to raise_error
          expect { provider.upload }.not_to raise_error
          expect { provider.flush }.not_to raise_error

          expect(provider.group).to eq(resource[:group])
          expect(provider.name).to eq(resource[:name])
          expect(provider.version).to eq(resource[:version])
          expect(provider.ensure).to eq(resource[:ensure])
        end
      end
      context 'to-be does not match version' do
        context 'uploads new version' do
          let(:resource) do
            Puppet::Type.type(:aem_crx_package).new(
              ensure:   :present,
              name:     'test',
              group:    'my_packages',
              home:     '/opt/aem',
              password: 'admin',
              pkg:      'test',
              source:   source,
              timeout:  1,
              username: 'admin',
              version:  '3.0.0'
            )
          end
          it 'should work' do
            expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield('')

            expect(
              CrxPackageManager::DefaultApi
            ).to receive(:new).with(
              match_api_config(default_config)
            ).and_call_original

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:list).with(
              path: '/etc/packages/my_packages/test-3.0.0.zip', include_versions: true
            ).and_return(list_two_installed, list_all_present)

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:service_post).with(
              instance_of(File)
            ).and_return(service_response)

            expect { provider.retrieve }.not_to raise_error
            expect { provider.upload }.not_to raise_error
            expect { provider.flush }.not_to raise_error

            expect(provider.group).to eq(resource[:group])
            expect(provider.name).to eq(resource[:name])
            expect(provider.version).to eq(resource[:version])
            expect(provider.ensure).to eq(resource[:ensure])
          end
        end
        context 'installs new version' do
          let(:resource) do
            Puppet::Type.type(:aem_crx_package).new(
              ensure:   :installed,
              name:     'test',
              group:    'my_packages',
              home:     '/opt/aem',
              password: 'admin',
              pkg:      'test',
              source:   source,
              timeout:  1,
              username: 'admin',
              version:  '3.0.0'
            )
          end
          it 'should work' do
            expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield('')

            expect(
              CrxPackageManager::DefaultApi
            ).to receive(:new).with(
              match_api_config(default_config)
            ).and_call_original

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:list).with(
              path: '/etc/packages/my_packages/test-3.0.0.zip', include_versions: true
            ).and_return(list_two_installed, list_all_installed)

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:service_post).with(
              instance_of(File)
            ).and_return(service_response)

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:service_exec).with(
              'install', 'test', 'my_packages', '3.0.0'
            ).and_return(service_response)

            expect { provider.retrieve }.not_to raise_error
            expect { provider.install }.not_to raise_error
            expect { provider.flush }.not_to raise_error

            expect(provider.group).to eq(resource[:group])
            expect(provider.name).to eq(resource[:name])
            expect(provider.version).to eq(resource[:version])
            expect(provider.ensure).to eq(resource[:ensure])
          end
        end
      end
      context 'changes to absent' do
        context 'uninstalled first' do
          let(:resource) do
            Puppet::Type.type(:aem_crx_package).new(
              ensure:   :purged,
              name:     'test',
              group:    'my_packages',
              home:     '/opt/aem',
              password: 'admin',
              pkg:      'test',
              source:   source,
              timeout:  1,
              username: 'admin',
              version:  '2.0.0'
            )
          end
          it 'should work' do
            expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield('')

            expect(
              CrxPackageManager::DefaultApi
            ).to receive(:new).with(
              match_api_config(default_config)
            ).and_call_original

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:list).with(
              path: '/etc/packages/my_packages/test-2.0.0.zip', include_versions: true
            ).and_return(list_two_installed, list_one_installed)

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:service_exec).with(
              'uninstall', 'test', 'my_packages', '2.0.0'
            ).and_return(service_response)

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:service_exec).with(
              'delete', 'test', 'my_packages', '2.0.0'
            ).and_return(service_response)

            expect { provider.retrieve }.not_to raise_error
            expect { provider.purge }.not_to raise_error
            expect { provider.flush }.not_to raise_error

            expect(provider.group).to eq(resource[:group])
            expect(provider.name).to eq(resource[:name])
            expect(provider.version).to eq(resource[:version])
            expect(provider.ensure).to eq(:absent)
          end
        end
        context 'removed but not uninstalled first' do
          let(:resource) do
            Puppet::Type.type(:aem_crx_package).new(
              ensure:   :absent,
              name:     'test',
              group:    'my_packages',
              home:     '/opt/aem',
              password: 'admin',
              pkg:      'test',
              source:   source,
              timeout:  1,
              username: 'admin',
              version:  '2.0.0'
            )
          end
          it 'should work' do
            expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield('')

            expect(
              CrxPackageManager::DefaultApi
            ).to receive(:new).with(
              match_api_config(default_config)
            ).and_call_original

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:list).with(
              path: '/etc/packages/my_packages/test-2.0.0.zip', include_versions: true
            ).and_return(list_two_installed, list_one_installed)

            expect_any_instance_of(
              CrxPackageManager::DefaultApi
            ).to receive(:service_exec).with(
              'delete', 'test', 'my_packages', '2.0.0'
            ).and_return(service_response)

            expect { provider.retrieve }.not_to raise_error
            expect { provider.remove }.not_to raise_error
            expect { provider.flush }.not_to raise_error

            expect(provider.group).to eq(resource[:group])
            expect(provider.name).to eq(resource[:name])
            expect(provider.version).to eq(resource[:version])
            expect(provider.ensure).to eq(resource[:ensure])
          end
        end
      end
    end
  end

  describe 'error cases' do

    describe 'finding package has a retry' do
      it 'should raise an error' do
        envdata = ''

        expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield(envdata)

        expect_any_instance_of(
          CrxPackageManager::DefaultApi
        ).to receive(:list).with(
          path: '/etc/packages/my_packages/test-3.0.0.zip',
          include_versions: true
        ).exactly(11).times.and_raise(CrxPackageManager::ApiError)

        expect { provider.retrieve }.to raise_error(CrxPackageManager::ApiError)
      end
    end

    context 'retry is configurable' do
      let(:resource) do

        Puppet::Type.type(:aem_crx_package).new(
          ensure:   :present,
          name:     'test',
          group:    'my_packages',
          home:     '/opt/aem',
          password: 'admin',
          pkg:      'test',
          retries:  1,
          source:   source,
          timeout:  1,
          username: 'admin',
          version:  '1.0.0'
        )
      end

      it 'should raise an error' do
        envdata = ''

        expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield(envdata)

        expect_any_instance_of(
          CrxPackageManager::DefaultApi
        ).to receive(:list).with(
          path: '/etc/packages/my_packages/test-1.0.0.zip',
          include_versions: true
        ).exactly(2).times.and_raise(CrxPackageManager::ApiError)

        expect { provider.retrieve }.to raise_error(CrxPackageManager::ApiError)
      end
    end

    describe 'ensure installed upload call fails' do

      it 'should raise an error' do
        envdata = ''

        expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield(envdata)

        expect_any_instance_of(
          CrxPackageManager::DefaultApi
        ).to receive(:list).with(
          path: '/etc/packages/my_packages/test-3.0.0.zip',
          include_versions: true
        ).and_return(list_missing)

        expect_any_instance_of(
          CrxPackageManager::DefaultApi
        ).to receive(:service_post).with(
          instance_of(File)
        ).and_return(service_failure)

        expect { provider.retrieve }.not_to raise_error
        expect { provider.upload }.not_to raise_error
        expect { provider.flush }.to raise_error(/An Error Occurred/)
      end
    end

    context 'ensure installed call fails' do
      let(:resource) do
        Puppet::Type.type(:aem_crx_package).new(
          ensure:   :installed,
          name:     'test',
          group:    'my_packages',
          home:     '/opt/aem',
          password: 'admin',
          pkg:      'test',
          username: 'admin',
          version:  '1.0.0'
        )
      end

      it 'should raise an error' do
        envdata = ''

        expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield(envdata)

        expect_any_instance_of(
          CrxPackageManager::DefaultApi
        ).to receive(:list).with(
          path: '/etc/packages/my_packages/test-1.0.0.zip',
          include_versions: true
        ).and_return(list_one_installed)

        expect_any_instance_of(
          CrxPackageManager::DefaultApi
        ).to receive(:service_exec).with(
          'install', 'test', 'my_packages', '1.0.0'
        ).and_return(service_exec_failure)

        expect { provider.retrieve }.not_to raise_error
        expect { provider.install }.not_to raise_error
        expect { provider.flush }.to raise_error(/An Error Occurred/)
      end
    end

    context 'ensure absent remove call fails' do
      let(:resource) do
        Puppet::Type.type(:aem_crx_package).new(
          ensure:   :absent,
          name:     'test',
          group:    'my_packages',
          home:     '/opt/aem',
          password: 'admin',
          pkg:      'test',
          username: 'admin',
          version:  '1.0.0'
        )
      end

      it 'should raise an error' do
        envdata = ''

        expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield(envdata)

        expect_any_instance_of(
          CrxPackageManager::DefaultApi
        ).to receive(:list).with(
          path: '/etc/packages/my_packages/test-1.0.0.zip',
          include_versions: true
        ).and_return(list_one_installed)

        expect_any_instance_of(
          CrxPackageManager::DefaultApi
        ).to receive(:service_exec).with(
          'delete', 'test', 'my_packages', '1.0.0'
        ).and_return(service_exec_failure)

        expect { provider.retrieve }.not_to raise_error
        expect { provider.remove }.not_to raise_error
        expect { provider.flush }.to raise_error(/An Error Occurred/)
      end
    end

    context 'ensure purged uninstall call fails' do
      let(:resource) do
        Puppet::Type.type(:aem_crx_package).new(
          ensure:   :purged,
          name:     'test',
          group:    'my_packages',
          home:     '/opt/aem',
          password: 'admin',
          pkg:      'test',
          username: 'admin',
          version:  '1.0.0'
        )
      end

      it 'should raise an error' do
        envdata = ''

        expect(File).to receive(:foreach).with('/opt/aem/crx-quickstart/bin/start-env').and_yield(envdata)

        expect_any_instance_of(
          CrxPackageManager::DefaultApi
        ).to receive(:list).with(
          path: '/etc/packages/my_packages/test-1.0.0.zip',
          include_versions: true
        ).and_return(list_one_installed)

        expect_any_instance_of(
          CrxPackageManager::DefaultApi
        ).to receive(:service_exec).with(
          'uninstall', 'test', 'my_packages', '1.0.0'
        ).and_return(service_exec_failure)

        expect { provider.retrieve }.not_to raise_error
        expect { provider.purge }.not_to raise_error
        expect { provider.flush }.to raise_error(/An Error Occurred/)
      end
    end
  end
end
