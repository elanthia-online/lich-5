# extension to class Hash 2025-03-14

class Hash
  def self.put(target, path, val)
    path = [path] unless path.is_a?(Array)
    fail ArgumentError, "path cannot be empty" if path.empty?
    root = target
    path.slice(0..-2).each { |key| target = target[key] ||= {} }
    target[path.last] = val
    root
  end

  def to_struct
    OpenStruct.new self
  end
end
