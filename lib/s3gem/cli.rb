require 's3gem/config'
require 's3gem/createrepo'
require 's3gem/repo'
require 's3gem/utils'
require 's3sync'
require 'thor'

#require_relative 'config.rb'
#require_relative 'createrepo.rb'
#require_relative 'repo.rb'
#require_relative 'utils.rb'

trap('SIGINT') {
	puts("\nControl-C received.")
	exit(0)
}

@utils = S3Gem::Utils.new()
@utils.validate_prereqs

def configure_options(thor, opt_type, opts)
	opts = opts.sort_by { |k| k[:name].to_s }
	opts.each do |opt|
		required = opt.has_key?(:required) ? opt[:required] : false
		if opt_type == 'class'
			thor.class_option(opt[:name], :banner => opt[:banner], :desc => opt[:desc], :required => required, :type => opt[:type])
		elsif opt_type == 'method'
			thor.method_option(opt[:name], :banner => opt[:banner], :desc => opt[:desc], :required => required, :type => opt[:type], :aliases => opt[:aliases])
		end
	end
end

def configure_repo(options: nil)
	begin
		repo = S3Gem::Repo.new(
			repo: options['repo'] || nil,
			debug: options['debug'] == true ? true : false,
			dryrun: options['dryrun'] == true ? true : false,
		)
		return repo
	rescue Exception => e
		puts e
		exit 1
	end
end

class CLI < Thor
	@config = S3Gem::Config.new()
	desc 'add <gem>', 'Add a new gem to the repository'
	configure_options(self, 'method', @config.add)
	def add(path)
		repo = configure_repo(options: options)
		repo.add(path: path)
	end

	desc 'delete <gem>', 'Delete an existing gem from the repository'
	configure_options(self, 'method', @config.delete)
	def delete(gemfile)
		repo = configure_repo(options: options)
		repo.delete(gemfile: gemfile)
	end

	desc 'sync', 'Sync your local repo from S3'
	configure_options(self, 'method', @config.sync)
	def sync()
		repo = configure_repo(options: options)
		repo.sync
	end

	desc 'diff', 'Display a diff of the specified repo against your local filesystem'
	configure_options(self, 'method', @config.diff)
	def diff()
		repo = configure_repo(options: options)
		repo.diff
	end

	desc 'list', 'List all gems in the specified repo'
	configure_options(self, 'method', @config.list)
	def list(pkg_name=nil)
		repo = configure_repo(options: options)
		repo.list(pkg_name=pkg_name)
	end

	desc 'push', 'Forcibly push the contents of the local copy to s3. You should never need to do this'
	configure_options(self, 'method', @config.push)
	def push()
		repo = configure_repo(options: options)
		repo.push
	end

	desc 'prune <gem>', 'Prune previous versions of <gem>.'
	configure_options(self, 'method', @config.prune)
	def prune(package)
		repo = configure_repo(options: options)
		repo.prune(
			package: package,
			num: options['num'],
		)
	end

	desc 'create <name>', 'Create a new Ruby Gem repository in s3.'
	configure_options(self, 'method', @config.create)
	def create(name)
		creator = S3Gem::CreateRepo.new(
			name: name,
			profile: options['profile'],
			region: options['region'],
			bucket: options['bucket'],
			path: options['path'],
		)
		creator.create()
	end
end
