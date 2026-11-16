# frozen_string_literal: true

# Record production policy, manifest and activation without replacing decisions.
# RUBYOPT carries this passive observer into the production repair restart.
directory = ENV.fetch('LICH_CI_RUNTIME_ARTIFACTS')
process_path = File.join(directory, "process-#{Process.pid}.txt")
File.write("#{process_path}.tmp", "#{$PROGRAM_NAME}\n#{Time.now.to_f}\n")
File.rename("#{process_path}.tmp", process_path)
policy_path = File.expand_path('../../lib/accepted_gem_policy.rb', __dir__).tr('\\', '/')
recovery_path = File.expand_path('../../lib/dependency_recovery.rb', __dir__).tr('\\', '/')
write_record = lambda do |name, data|
  path = File.join(directory, name)
  File.write("#{path}.tmp", JSON.pretty_generate(data))
  File.rename("#{path}.tmp", path)
end
observer = TracePoint.new(:return) do |event|
  path = File.expand_path(event.path).tr('\\', '/')
  if path == recovery_path && event.method_id == :fetch && event.return_value.is_a?(String)
    File.write(File.join(directory, "manifest-#{Process.pid}.json"), event.return_value)
  elsif path == policy_path && event.method_id == :check
    check = event.return_value
    next unless check.respond_to?(:needed)

    write_record.call("policy-#{Process.pid}.json", {
      pid: Process.pid, needed: check.needed, units: check.plan.units.map { |unit| unit.fetch('id') },
      gem_home: Gem.dir, gem_path: Gem.path,
      installed: Gem::Specification.map { |spec| [spec.name, spec.version.to_s, spec.platform.to_s] },
      active: Gem.loaded_specs.values.map { |spec| [spec.name, spec.version.to_s, spec.platform.to_s] }
    })
  elsif path == policy_path && event.method_id == :activate! && event.return_value == true
    write_record.call('ready.json', { pid: Process.pid, accepted_runtime_activated: true })
    observer.disable
  end
end
observer.enable
