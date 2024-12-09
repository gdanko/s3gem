module S3Gem
	class MissingConstructorParameter < StandardError
		def initialize(parameter: nil)
			@parameter = parameter
			@error = format('The required "%s" parameter is missing from the constructor.', @parameter)
			super(@error)
		end
	end

	class InvalidRegion < StandardError
		def initialize(region: nil, valid_regions: nil)
			@region = region
			@valid_regions = valid_regions
			@error = format('The region "%s" is an invalid region. Valid regions are: %s.', @region, @valid_regions.join(', '))
			super(@error)
		end
	end

	class NotAGem < StandardError
		def initialize(path: nil)
			@path = path
			@error = format('The specified file "%s" is not a Ruby gem.', path)
			super(@error)
		end
	end

	class InvalidGem < StandardError
		def initialize(path: nil)
			@path = path
			@error = format('The specified file "%s" is an invalid Ruby gem.', path)
			super(@error)
		end
	end

	class FileReadError < StandardError
		def initialize(path: nil, message: nil)
			@message = message
			@path = path
			@error = format('An error occurred while reading the specified file "%s": %s', @path, @message)
			super(@error)
		end
	end

	class FileWriteError < StandardError
		def initialize(path: nil, message: nil)
			@message = message
			@path = path
			@error = format('An error occurred while writing the file "%s": %s', @path, @message)
			super(@error)
		end
	end

	class FileCopyError < StandardError
		def initialize(src: nil, dest: nil, message: nil)
			@src = src
			@dest = dest
			@message = message
			@error = format('An error occurred while copying the file "%s" to "%s": %s', @src, @dest, @message)
			super(@error)
		end
	end

	class FileDeleteError < StandardError
		def initialize(path: nil, message: nil)
			@path = path
			@message = message
			@error = format('An error occurred while deleting the file "%s": %s', @path, @message)
			super(@error)
		end
	end

	class MkdirError < StandardError
		def initialize(path: nil, message: nil)
			@path = path
			@message = message
			@error = format('An error occurred while creating the directory "%s": %s', @path, @message)
			super(@error)
		end
	end

	class InvalidConfigFile < StandardError
		def initialize(path: nil, message: 'nil')
			@message = message
			@path = path
			@error = format('The specified config file %s is invalid: %s.', @path, @message)
			super(@error)
		end
	end

	class InvalidRepo < StandardError
		def initialize(repo: nil, message: 'nil')
			@message = message
			@repo = profile
			@error = format('The specified is repo is invalid: %s.', @repo, @message)
			super(@error)
		end
	end

	class RepoNotFound < StandardError
		def initialize(repo: nil)
			@repo = repo
			@error = format('The specified repo "%s" does not exist.', @repo)
			super(@error)
		end
	end


	class NoDefaultRepo < StandardError
		def initialize()
			@error = 'You did not specify a repo name and no default repo was found.'
			super(@error)
		end
	end

	class RepoPathExists < StandardError
		def initialize(bucket: nil, path: nil)
			@bucket = bucket
			@path = path
			@error = format('The specified repository path "s3://%s/%s" already exists. Cannot create a new repository here.', @bucket, @path)
			super(@error)
		end
	end
end
