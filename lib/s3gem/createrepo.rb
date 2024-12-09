require 'aws-sdk-s3'
require 'json'
require 'pp'
require 's3gem/exception'
require 'yaml'

#require_relative 'exception.rb'

module S3Gem
	class CreateRepo
		attr_accessor :bucket
		attr_accessor :name
		attr_accessor :path
		attr_accessor :profile
		attr_accessor :region
		attr_accessor :response
		attr_accessor :s3
		attr_accessor :success
		def initialize(*args)
			args = args[0] || {}
			self.response = {'status' => 'success', 'message' => 'Empty message'}
			self.success = true

			valid_regions = %w(ap-northeast-1 ap-northeast-2 ap-south-1 ap-southeast-1 ap-southeast-2 eu-central-1 eu-west-1 sa-east-1 us-east-1 us-east-2 us-west-1 us-west-2)

			if args[:name]
				self.name = args[:name]
			else
				raise S3Gem::MissingConstructorParameter.new(parameter: 'name')
			end

			if args[:profile]
				self.profile = args[:profile]
			else
				raise S3Gem::MissingConstructorParameter.new(parameter: 'profile')
			end

			if args[:region]
				if valid_regions.include?(args[:region])
					self.region = args[:region]
				else
					raise S3Gem::InvalidRegion.new(region: args[:region], valid_regions: valid_regions)
				end
			else
				raise S3Gem::MissingConstructorParameter.new(parameter: 'region')
			end

			if args[:bucket]
				self.bucket = args[:bucket]
			else
				raise S3Gem::MissingConstructorParameter.new(parameter: 'bucket')
			end

			if args[:path]
				self.path = args[:path]
			else
				raise S3Gem::MissingConstructorParameter.new(parameter: 'path')
			end

			begin
				self.s3 = Aws::S3::Client.new(
					profile: self.profile,
					region: self.region
				)
			rescue Aws::Sigv4::Errors::MissingCredentialsError => e
				puts 'Missing or invalid AWS credential.'
				exit 1
			end
		end

		def create()
			if self.bucket_exists()
				if self.path_exists()
					raise S3Gem::RepoPathExists.new(bucket: self.bucket, path: self.path)
				else
					self.apply_bucket_policy()
					self.enable_bucket_versioning()
					config_path = sprintf('%s/.s3gem.yml', Dir.home)
					repo_def = {'repos' => {self.name => {'bucket' => self.bucket, 'path' => self.path, 'profile' => self.profile, 'region' => self.region}}}
					repo_url = sprintf('https://s3-%s.amazonaws.com/%s/%s/', self.region, self.bucket, self.path)
					puts 'Success!'
					puts format('Please add the following repository definition to %s:', config_path)
					puts repo_def.to_yaml
					puts ''
					puts 'If you want to install gems from this repository, you need to add it to your sources list like this:'
					puts format('gem sources --add %s', repo_url)
				end
			else
				puts 'Bucket does not exist. Creating.'
				self.create_bucket()
			end
		end

		def create_bucket()
			begin
				resp = self.s3.create_bucket(
					bucket: self.bucket,
				)
				self.create()
			rescue Exception => e
				puts format('Failed to create the bucket: %s', e)
				exit 1
			end
		end

		def apply_bucket_policy()
			begin
				policy = get_policy(bucket: self.bucket)
				self.s3.put_bucket_policy(
					bucket: self.bucket,
					policy: policy
				)
			rescue Exception => e
				puts format('Failed to apply the bucket policy: %s', e)
				exit 1
			end
		end

		def enable_bucket_versioning()
			begin
				self.s3.put_bucket_versioning(
					bucket: self.bucket,
					versioning_configuration: {
						mfa_delete: 'Disabled',
						status: 'Enabled',
					}
				)
			rescue Exception => e
				puts format('Failed to enabled versioning: %s', e)
				exit 1
			end
		end

		def bucket_exists()
			bucket_exists = false
			begin
				self.s3.head_bucket(
					bucket: self.bucket,
					use_accelerate_endpoint: false
				)
				bucket_exists = true
			rescue
			end
			return bucket_exists
		end

		def path_exists()
			path_exists = false
			begin
				resp = self.s3.list_objects_v2(
					bucket: bucket,
					prefix: sprintf('%s/', self.path)
				)
				if resp['key_count'] > 0
					path_exists = true
				end
			rescue
			end
			return path_exists
		end
	end
end

def get_policy(bucket: nil)
	return {
		'Version' => '2012-10-17',
		'Id' => 'automation-patterns-repo',
		'Statement' => [
			{
				'Sid' => 'IPAllow',
				'Effect' => 'Allow',
				'Principal' => '*',
				'Action' => 's3:*',
				'Resource' => sprintf('arn:aws:s3:::%s/*', bucket),
				'Condition' => {
					'IpAddress' => {
						'aws:SourceIp' => [
							'12.148.72.0/23',
							'12.149.172.0/22',
							'12.179.132.0/22',
							'64.34.20.0/24',
							'65.39.148.88/29',
							'65.162.137.0/24',
							'108.63.22.80/28',
							'173.240.160.0/21',
							'173.240.168.0/22',
							'173.240.172.0/23',
							'198.31.208.0/23',
							'199.16.136.0/21',
							'199.187.152.0/23',
							'199.187.156.0/24',
							'199.187.157.0/24',
							'206.108.40.0/21',
							'216.254.197.0/24',
							'8.28.123.0/24',
							'8.41.0.0/24',
							'12.25.160.128/25',
							'12.41.88.64/27',
							'12.69.229.128/27',
							'12.147.20.224/27',
							'12.151.249.128/27',
							'12.161.60.224/27',
							'12.164.135.96/27',
							'12.172.112.0/27',
							'12.187.184.0/24',
							'12.216.231.0/24',
							'32.60.119.128/27',
							'65.204.229.0/24',
							'80.81.74.0/26',
							'80.81.74.64/27',
							'80.81.74.128/26',
							'103.15.250.0/24',
							'179.184.227.149/32',
							'203.43.54.0/27',
							'212.179.202.0/28',
							'12.47.158.224/27',
							'32.60.64.192/27',
						]
					}
				}
			}
		]
	}.to_json
end