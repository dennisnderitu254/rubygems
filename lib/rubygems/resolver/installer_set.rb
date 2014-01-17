##
# A set of gems for installation sourced from remote sources and local .gem
# files

class Gem::Resolver::InstallerSet < Gem::Resolver::Set

  ##
  # List of Gem::Specification objects that must always be installed.

  attr_reader :always_install # :nodoc:

  ##
  # Only install gems in the always_install list

  attr_accessor :ignore_dependencies # :nodoc:

  ##
  # Do not look in the installed set when finding specifications.  This is
  # used by the --install-dir option to `gem install`

  attr_accessor :ignore_installed # :nodoc:

  ##
  # Creates a new InstallerSet that will look for gems in +domain+.

  def initialize domain
    super()

    @domain = domain
    @remote = consider_remote?

    @f = Gem::SpecFetcher.fetcher

    @always_install      = []
    @ignore_dependencies = false
    @ignore_installed    = false
    @local               = {}
    @remote_set          = Gem::Resolver::BestSet.new
    @specs               = {}
  end

  ##
  # Looks up the latest specification for +dependency+ and adds it to the
  # always_install list.

  def add_always_install dependency
    request = Gem::Resolver::DependencyRequest.new dependency, nil

    found = find_all request

    if found.empty? then
      raise Gem::UnsatisfiableDependencyError, request
    end

    newest = found.max_by do |s|
      [s.version, s.platform == Gem::Platform::RUBY ? -1 : 1]
    end

    @always_install << newest.spec
  end

  ##
  # Adds a local gem requested using +dep_name+ with the given +spec+ that can
  # be loaded and installed using the +source+.

  def add_local dep_name, spec, source
    @local[dep_name] = [spec, source]
  end

  ##
  # Should local gems should be considered?

  def consider_local? # :nodoc:
    @domain == :both or @domain == :local
  end

  ##
  # Should remote gems should be considered?

  def consider_remote? # :nodoc:
    @domain == :both or @domain == :remote
  end

  ##
  # Returns an array of IndexSpecification objects matching DependencyRequest
  # +req+.

  def find_all req
    res = []

    dep  = req.dependency

    return res if @ignore_dependencies and
              @always_install.none? { |spec| dep.matches_spec? spec }

    name = dep.name

    dep.matching_specs.each do |gemspec|
      next if @always_install.include? gemspec

      res << Gem::Resolver::InstalledSpecification.new(self, gemspec)
    end unless @ignore_installed

    if consider_local? then
      matching_local = @local.values.select do |spec, _|
        req.matches_spec? spec
      end.map do |spec, source|
        Gem::Resolver::LocalSpecification.new self, spec, source
      end

      res.concat matching_local

      local_source = Gem::Source::Local.new

      if spec = local_source.find_gem(name, dep.requirement) then
        res << Gem::Resolver::IndexSpecification.new(
          self, spec.name, spec.version, local_source, spec.platform)
      end
    end

    res.concat @remote_set.find_all req if consider_remote?

    res
  end

  def inspect # :nodoc:
    always_install = @always_install.map { |s| s.full_name }

    '#<%s domain: %s specs: %p always install: %p>' % [
      self.class, @domain, @specs.keys, always_install,
    ]
  end

  ##
  # Called from IndexSpecification to get a true Specification
  # object.

  def load_spec name, ver, platform, source # :nodoc:
    key = "#{name}-#{ver}-#{platform}"

    @specs.fetch key do
      tuple = Gem::NameTuple.new name, ver, platform

      @specs[key] = source.fetch_spec tuple
    end
  end

  ##
  # Has a local gem for +dep_name+ been added to this set?

  def local? dep_name # :nodoc:
    spec, = @local[dep_name]

    spec
  end

  def pretty_print q # :nodoc:
    q.group 2, '[InstallerSet', ']' do
      q.breakable
      q.text "domain: #{@domain}"

      q.breakable
      q.text 'specs: '
      q.pp @specs.keys

      q.breakable
      q.text 'always install: '
      q.pp @always_install
    end
  end

  def remote= remote # :nodoc:
    case @domain
    when :local then
      @domain = :both if remote
    when :remote then
      @domain = nil unless remote
    when :both then
      @domain = :local unless remote
    end
  end

end

