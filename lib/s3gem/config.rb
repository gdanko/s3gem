module S3Gem
	class Config
		attr_accessor :config
		attr_accessor :create_config
		attr_accessor :common_config
		def initialize(*args)
			self.config = {
				'repo' => {:name => :repo, :banner => '<string>', :desc => 'The name of the repo as defined in ~/.s3gem.yml.', :required => false},
				'debug' => {:name => :debug, :banner => '<boolean>', :desc => 'Enable debugging output.', :required => false, :type => :boolean, :aliases => '-d'},
				'dryrun' => {:name => :dryrun, :banner => '<boolean>', :desc => 'Show what would be done, but do nothing.', :required => false, :type => :boolean, :aliases => '-n'},
				'profile' => {:name => :profile, :banner => '<string>', :desc => 'The AWS profile from ~/.aws/credentials. See http://amzn.to/1smowsW for more information.', :required => true},
				'region' => {:name => :region, :banner => '<string>', :desc => 'The AWS region.', :required => true},
				'bucket' => {:name => :bucket, :banner => '<string>', :desc => 'The name of the AWS bucket.', :required => true},
				'path' => {:name => :path, :banner => '<string>', :desc => 'The path relative to the bucket name.', :required => true},
				'num' => {:name => :num, :banner => '<integer>', :desc => 'Prune all the <num> oldest versions of <gem>.', :required => true, :type => :numeric},
			}

			self.common_config = [
				 self.config['repo'],
				 self.config['debug'],
			]

			self.create_config = [
				self.config['profile'],
				self.config['region'],
				self.config['bucket'],
				self.config['path'],
			]

		end

		def add()
			return self.common_config + [self.config['dryrun']]
		end

		def delete()
			return self.common_config + [self.config['dryrun']]
		end

		def sync()
			return self.common_config + [self.config['dryrun']]
		end

		def diff()
			return self.common_config
		end

		def list()
			return self.common_config
		end

		def push()
			return self.common_config + [self.config['dryrun']]
		end

		def prune()
			return self.common_config + [self.config['dryrun']] + [self.config['num']]
		end

		def create()
			return self.create_config
		end
	end
end
