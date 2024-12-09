require 'fiddle'
require 'fileutils'
require 'logger'
require 'pp'
require 'rubygems/package'
require 's3gem/exception'
require 'securerandom'
require 'yaml'
require 'zlib'

#require_relative 'exception.rb'

class Object
  def unfreeze
    Fiddle::Pointer.new(object_id * 2)[1] &= ~(1 << 3)
  end
end

class Logger
	def self.custom_level(tag)
		SEV_LABEL.unfreeze
		SEV_LABEL << tag 
		idx = SEV_LABEL.size - 1

		define_method(tag.downcase.gsub(/\W+/, '_').to_sym) do |progname, &block|
			add(idx, nil, progname, &block)
		end
	end
	custom_level 'DRYRUN'
end

module S3Gem
	class Utils
		attr_accessor :exception
		attr_accessor :logger

		def initialize(*args)
			self.logger = self.configure_logger()
			return self
		end

		def configure_logger()
			logger = Logger.new(STDOUT)
			logger.datetime_format = '%Y-%m-%d %H:%M:%S'
			logger.formatter = proc do |severity, datetime, progname, msg|
				format("[%s] %s\n", severity.capitalize, msg)
			end
			return logger
		end

		def generate_random(length=8)
			return SecureRandom.hex(n=length)
		end

		def which(cmd)
		  exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
		  ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
		    exts.each { |ext|
		      exe = File.join(path, format('%s%s', cmd, ext))
		      return exe if File.executable?(exe) && !File.directory?(exe)
		    }
		  end
		  return nil
		end

		def validate_prereqs()
			prereqs = %w(gem)
			errors = []
			prereqs.each do |prereq|
				if which(prereq) == nil
					errors.push(prereq)
				end
			end

			if errors.length > 0
				puts format('The following binaries are missing: %s. Please fix this and try again.', errors.join(', '))
				exit 1
			end
		end

		def validate_yaml(string)
			return nil if string == ''
			begin
				return YAML.load(string)
			rescue
				return nil
			end
		end

		def validate_repo_directory(path: nil)
			# Use exceptions
			gems_path = format('%s/gems', path)
			return false unless File.exists?(path)
			return false unless File.directory?(path)
			return false unless File.exists?(gems_path)
			return false unless File.directory?(gems_path)
			return true
		end
		
		def read_config(config_path: nil)
			begin
				contents = File.read(config_path)
			rescue Errno::ENOENT => e
				raise S3gem::FileReadError.new(path: config_path, message: 'No such file or directory')
			rescue Errno::EACCES => e
				raise S3Gem::FileReadError.new(path: config_path, message: 'Permission denied')
			rescue Errno::EISDIR
				raise S3Gem::FileReadError.new(path: config_path, message: 'Is a directory')
			rescue Exception => e
				raise S3Gem::FileReadError.new(path: config_path, message: e)
			end
		end

		def parse_config(repo: nil)
			config_path = format('%s/.s3gem.yml', Dir.home)
			contents = File.read(config_path)

			if contents.length <= 0
				raise S3Gem::InvalidConfigFile.new(path: config_path, message: 'Zero-length file')
			end

			config = self.validate_yaml(contents)
			if config
				if not config.has_key?('repos')
					raise S3Gem::InvalidConfigFile.new(path: config_path, message: 'Missing repos section')
				end
			else
				raise S3Gem::InvalidConfigFile.new(path: config_path, message: 'File contains invalid YAML')
			end

			if repo == nil
				if config.has_key?('default')
					repo = config['default']
				else
					raise S3Gem::NoDefaultRepo.new()
				end
			end

			if repo != nil
				if config['repos'].has_key?(repo)
					['region', 'bucket', 'path', 'profile'].each do |key|
						if not config['repos'][repo].has_key?(key)
							raise S3Gem::InvalidRepo.new(repo: repo, message: format('No %s specified', key))
						end
					end
					return config['repos'][repo]
				else
					raise S3Gem::RepoNotFound.new(repo: repo)
				end
			end
		end

		def validate_gem(path: nil)
			type = 'unknown'

			begin
				contents = File.read(path)
			rescue Errno::ENOENT => e
				raise S3Gem::FileReadError.new(path: path, message: 'No such file or directory')
			rescue Errno::EACCES => e
				raise S3Gem::FileReadError.new(path: path, message: 'Permission denied')
			rescue Errno::EISDIR => e
				raise S3Gem::FileReadError.new(path: path, message: 'Is a directory')
			rescue Exception => e
				raise S3Gem::FileReadError.new(path: path, message: e)
			end

			begin
				type = `file --b --mime-type "#{path}"`.strip
			rescue
				type = 'unknown'
			end

			if type != 'application/x-tar'
				raise S3Gem::NotAGem.new(path: path)
			end

			required = ['metadata.gz', 'data.tar.gz', 'checksums.yaml.gz']
			contains = []
			File.open(path, 'rb') do |file|
				Gem::Package::TarReader.new(file) do |tar|
					tar.each do |entry|
						contains.push(entry.full_name) if required.include?(entry.full_name)
					end
				end
			end

			missing = required - contains
			raise S3Gem::InvalidGem.new(path: path) if missing.length != 0
		end

		def create_path(path: nil)
			begin
				FileUtils.mkpath(path)
			rescue Errno::EACCES => e
				raise S3Gem::MkdirError.new(path: path, message: 'Permission denied')
			rescue Errno::EEXIST => e
				raise S3Gem::MkdirError.new(path: path, message: 'File exists')
			rescue Exception => e
				raise S3Gem::MkdirError.new(path: path, message: e)
			end
		end

		def copy_file(src: nil, dest: nil)
			begin
				FileUtils.cp src, dest
			rescue Errno::ENOENT => e
				raise S3Gem::FileCopyError.new(path: path, message: 'No such file or directory')
			rescue Errno::EACCES => e
				raise S3Gem::FileCopyError.new(path: path, message: 'Permission denied')
			rescue Errno::EISDIR => e
				raise S3Gem::FileCopyError.new(path: path, message: 'Is a directory')
			rescue Exception => e
				raise S3Gem::FileCopyError.new(path: path, message: e)
			end
		end

		def delete_file(path: nil)
			begin
				FileUtils.rm path
			rescue Errno::ENOENT => e
				raise S3Gem::FileDeleteError.new(path: path, message: 'No such file or directory')
			rescue Errno::EACCES => e
				raise S3Gem::FileDeleteError.new(path: path, message: 'Permission denied')
			rescue Errno::EISDIR => e
				raise S3Gem::FileDeleteError.new(path: path, message: 'Is a directory')
			rescue Exception => e
				raise S3Gem::FileDeleteError.new(path: path, message: e)
			end
		end

		def is_bool(var)
			if !!var == var
					return true
			else
					return false
			end
		end
	end
end
