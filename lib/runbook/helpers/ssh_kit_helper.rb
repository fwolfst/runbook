module Runbook::Helpers
  module SSHKitHelper
    def ssh_kit_command(cmd, raw: false)
      return [cmd] if raw
      cmd, args = cmd.split(" ", 2)
      [cmd.to_sym, args]
    end

    def with_ssh_config(ssh_config, &exec_block)
      user = ssh_config[:user]
      group = ssh_config[:group]
      as_block =  _as_block(user, group, &exec_block)
      within_block = _within_block(ssh_config[:path], &as_block)
      with_block = _with_block(ssh_config[:env], &within_block)

      _with_umask(ssh_config[:umask]) do
        servers = _servers(ssh_config[:servers])
        parallelization = ssh_config[:parallelization]
        coordinator_options = _coordinator_options(parallelization)
        SSHKit::Coordinator.new(servers).each(coordinator_options) do
          instance_exec(&with_block)
        end
      end
    end

    def _servers(ssh_config_servers)
      return :local if ssh_config_servers.empty?
      return :local if ssh_config_servers == [:local]
      ssh_config_servers
    end

    def _coordinator_options(ssh_config_parallelization)
      ssh_config_parallelization.clone.tap do |options|
        if options[:strategy]
          options[:in] = options.delete(:strategy)
        end
      end
    end

    def _as_block(user, group, &block)
      if user || group
        -> { as({user: user, group: group}) { instance_exec(&block) } }
      else
        -> { instance_exec(&block) }
      end
    end

    def _with_block(env, &block)
      if env
        -> { with(env) { instance_exec(&block) } }
      else
        -> { instance_exec(&block) }
      end
    end

    def _within_block(path, &block)
      if path
        -> { within(path) { instance_exec(&block) } }
      else
        -> { instance_exec(&block) }
      end
    end

    def _with_umask(umask, &block)
      old_umask = SSHKit.config.umask
      begin
        SSHKit.config.umask = umask if umask
        instance_exec(&block)
      ensure
        SSHKit.config.umask = old_umask
      end
    end
  end
end
