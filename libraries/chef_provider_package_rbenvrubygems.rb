#
# Cookbook Name:: rbenv
# Provider:: Chef::Provider::Package::RbenvRubygems
#
# Author:: Fletcher Nichol <fnichol@nichol.ca>
#
# Copyright 2011, Fletcher Nichol
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class Chef
  module Rbenv
    module Mixin
      module ShellOut
        # stub to satisfy RbenvRubygems (library load order not guarenteed)
      end
    end

    module ScriptHelpers
      # stub to satisfy RbenvRubygems (library load order not guarenteed)
    end
  end

  class Provider
    class Package
      class RbenvRubygems < Chef::Provider::Package::Rubygems

        class RbenvGemEnvironment < AlternateGemEnvironment
          attr_reader :rbenv_version, :rbenv_user

          include Chef::Rbenv::Mixin::ShellOut

          def initialize(gem_binary_location, rbenv_version, rbenv_user = nil)
            super(gem_binary_location)
            @rbenv_version = rbenv_version
            @rbenv_user = rbenv_user
          end

          def rubygems_version
              @rubygems_version ||= shell_out!("#{@gem_binary_location} --version").stdout.chomp
          end
        end

        attr_reader :rbenv_user

        include Chef::Rbenv::Mixin::ShellOut
        include Chef::Rbenv::ScriptHelpers

        def initialize(new_resource, run_context=nil)
          super
          normalize_version
          @new_resource.gem_binary(wrap_shim_cmd("gem"))
          @rbenv_user = new_resource.respond_to?("user") ? new_resource.user : nil
          @gem_env = RbenvGemEnvironment.new(
            gem_binary_path, new_resource.rbenv_version, rbenv_user)
        end

        def install_package(name, version)
          super
          rehash
          true
        end

        def remove_package(name, version)
          super
          rehash
          true
        end

        # pulls in patch from chef 14 to support rubygems 3+
        # (https://github.com/chef/chef/commit/537982312e1034f33e4bc3967f36d8f49bbafb4c)
        def install_via_gem_command(name, version)
          if @new_resource.source =~ /\.gem$/i
            name = @new_resource.source
          else
            src = @new_resource.source && "  --source=#{@new_resource.source} --source=http://rubygems.org"
          end
          if !version.nil? && !version.empty?
            shell_out!("#{gem_binary_path} install #{name} -q #{rdoc_string} -v \"#{version}\"#{src}#{opts}", env: nil)
          else
            shell_out!("#{gem_binary_path} install \"#{name}\" -q #{rdoc_string} #{src}#{opts}", env: nil)
          end
        end

        private

        def normalize_version
          if @new_resource.rbenv_version == "global"
            @new_resource.rbenv_version(current_global_version)
          end
        end

        def rdoc_string
          if needs_nodocument?
            "--no-document"
          else
            "--no-rdoc --no-ri"
          end
        end

        def needs_nodocument?
          Gem::Requirement.new(">= 3.0.0.beta1").satisfied_by?(Gem::Version.new(gem_env.rubygems_version))
        end

        def rehash
          e = ::Chef::Resource::RbenvRehash.new(new_resource, @run_context)
          e.root_path rbenv_root
          e.user rbenv_user if rbenv_user
          e.action :nothing
          e.run_action(:run)
        end
      end
    end
  end
end
