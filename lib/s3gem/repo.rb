require 'find'
require 'open3'
require 'pathname'
require 's3gem/exception'
require 's3gem/utils'
require 's3sync'
require 'uri'

#require_relative 'exception.rb'
#require_relative 'utils.rb'

module S3Gem
	class Repo
		attr_accessor :gem_binary
		attr_accessor :local
		attr_accessor :local_gems_path
		attr_accessor :logger
		attr_accessor :pm
		attr_accessor :repo
		attr_accessor :syncer
		attr_accessor :utils
		def initialize(*args)
			args = args[0] || {}

			self.utils = S3Gem::Utils.new()
			self.logger = self.utils.configure_logger
			@debug = (args.key?(:debug) and self.utils.is_bool(args[:debug])) ? args[:debug] : false
			@dryrun = (args.key?(:dryrun) and self.utils.is_bool(args[:dryrun])) ? args[:dryrun] : false

			self.gem_binary = self.utils.which('gem')
			unless self.gem_binary
				# make exceptions
				puts 'the gem command was not found. please fix this'
				exit 1
			end

			#if not args[:repo]
			#	raise S3Gem::MissingConstructorParameter.new(parameter: 'repo')
			#end

			config = self.utils.parse_config(repo: args[:repo])

			config['path'] = config['path'].gsub(/^\//, '').gsub(/\/$/, '')
			self.repo = format(
				's3://%s/%s',
				config['bucket'],
				config['path'],
			)

			self.local = format(
				'%s/.s3gem/s3-%s.amazonaws.com/%s/%s',
				Dir.home,
				config['region'],
				config['bucket'],
				config['path'],
			)

			self.syncer = S3Sync::Syncer.new(
				source: self.repo,
				destination: self.local,
				region: config['region'],
				profile: config['profile'],
				acl: 'public-read',
				delete: true,
				debug: @debug,
				dryrun: @dryrun,
			)
		end

		def add(path: nil)
			# Do an initial sync
			self.syncer.sync

			# Determine if the specified gem file path is absolute or relative
			# and generate the absolute path if it's relative.
			if Pathname(path).relative?
				path = format('%s/%s', Dir.pwd, path)
			end

			# Validate the gem file
			self.utils.validate_gem(path: path)

			# Copy the gem file to the local library
			src = path
			dest = format('%s/gems/%s', self.local, File.basename(path))
			basedir = File.dirname(dest)

			# trap this
			utils.create_path(path: basedir)

			begin
				self.utils.copy_file(src: src, dest: dest)
			rescue S3Gem::FileCopyError => e
				puts e
				exit 1
			end

			# Regenerate the index
			generate_index(path: local)

			# Reverse the sync direction and sync back up to s3
			self.syncer.reverse
			self.syncer.sync
		end

		def delete(gemfile: nil)
			# Sync from s3 first
			self.syncer.sync

			package, version = package_info(gemfile)
			if package and version
				gem_path = format('%s/gems/%s', self.local, gemfile)
				gem_path = format('%s.gem', gem_path) unless gem_path.end_with?('.gem')
				marshal_path = format('%s/quick/Marshal.4.8/%s-%s.gemspec.rz', self.local, package, version)

				begin
					self.utils.delete_file(path: gem_path)
				rescue S3Gem::FileDeleteError => e
					puts e
					exit 1
				end

				begin
					self.utils.delete_file(path: marshal_path)
				rescue S3Gem::FileDeleteError => e
					puts e
					exit 1
				end

				# Regenerate the index
				generate_index(path: local)

				# Reverse the sync direction and sync back up to s3
				self.syncer.reverse
				self.syncer.sync
			end
		end

		def prune(package: nil, num:nil)
			# This will not be exposed to the CLI.
			# Sync from s3 first
			self.syncer.sync

			versions = []
			path = format('%s/gems/', self.local)

			Find.find(path) do |f|
				versions.push(extract_version(f)) if File.basename(f) =~ /^#{package}/
			end

			if num > versions.length
				puts "You asked to prune #{num} versions of #{package} but only #{versions.length} exist."
				exit 1
			elsif num == versions.length
				puts "You cannot delete all versions of #{package}."
				exit 1
			end

			start = (versions.length - num)
			older = version_sort(versions).slice!(start..-1)
			delete_list = older.map{|v| format('%s-%s.gem', package, v)}

			# Delete the files in delete_list
			delete_list.each do |gemfile|
				package, version = package_info(gemfile)
				if package and version
					gem_path = format('%s/gems/%s', self.local, gemfile)
					marshal_path = format('%s/quick/Marshal.4.8/%s-%s.gemspec.rz', self.local, package, version)
			
					if @dryrun
						puts "Pruning #{gemfile}..."
					else
						begin
							self.utils.delete_file(path: gem_path)
						rescue S3Gem::FileDeleteError => e
							puts e
							exit 1
						end

						begin
							self.utils.delete_file(path: marshal_path)
						rescue S3Gem::FileDeleteError => e
							puts e
							exit 1
						end
					end
				end
			end

			if !@dryrun
				# Regenerate the index
				generate_index(path: local)

				# Reverse the sync direction and sync back up to s3
				self.syncer.reverse
				self.syncer.sync
			end
		end

		def sync()
			self.syncer.sync
		end

		def diff()
			diff = {}
			self.syncer.s3diff.source_only.each do |fname, obj|
				diff[fname] = 'repo'
			end

			self.syncer.s3diff.destination_only.each do |fname, obj|
				diff[fname] = 'local'
			end
			
			if diff.keys.length > 0
				diff.each do |fname, location|
					prefix = location == 'repo' ? 'Only in s3' : 'Only in local'
					puts format('%s: %s', prefix, fname)
				end
			else
				puts('no differences.')
			end
		end

		def list(pkg_name=nil)
			gems = self.syncer.s3diff.source_list.select {|fname, obj| obj['dirname'] == format('%s/gems', self.syncer.s3diff.source_path)}
			if pkg_name
				pattern = "^#{pkg_name}-"
				gems = gems.select {|name, obj| obj['filename'] =~ /#{pattern}/}
			end

			if gems.keys.length > 0
				packages = {}
				gems.each do |fname, obj|
					if fname =~ /^(.*)-([0-9]+[\.0-9]+[0-9]+)\.gem$/
						package, version = File.basename($1), $2
						packages[package] = [] if not packages.key?(package)
						packages[package].push(version)
					end
				end
				packages.each do |pkg, versions|
					puts format('%s (%s)', pkg, version_sort(versions).join(', '))
				end
			else
				puts format('no gems found in %s.', self.repo)
			end
		end

		def push()
			self.syncer.reverse
			self.syncer.sync
		end
	end
end

def version_sort(list)
	return list.sort_by{|v| Gem::Version.new(v)}.reverse!
end

def extract_version(filename)
	version = 'unknown'
	if filename =~ /([0-9]+[\.0-9]+[0-9]+)/
		version = $1
	end
	return version
end

def package_info(gemfile)
	if gemfile =~ /^(.*)-([0-9]+[\.0-9]+[0-9]+)(\.gem)?$/
		return $1, $2
	end
	return nil
end


def generate_index(path: nil)
	return if @dryrun
	command = [
		self.gem_binary,
		'generate_index',
		'--modern',
		'-d',
		path
	]
	#index_files = [
	#	'latest_specs.4.8',
	#	'latest_specs.4.8.gz',
	#	'prerelease_specs.4.8',
	#	'prerelease_specs.4.8.gz',
	#	'specs.4.8',
	#	'specs.4.8.gz',
	#]

	#missing = []
	#index_files.each do |fname|
	#	fpath = format('%s/%s', path, fname)
	#	missing.push(fpath) if not File.exists?(fpath)
	#end
	#command.push('--update') if missing.length == 0

	command_str = command.join(' ')
	system(command_str)
end
