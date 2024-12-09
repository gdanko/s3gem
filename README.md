# s3Gem
s3gem provides a way to maintain Amazon s3-based Ruby Gem repositories.

# Requirements
* ruby 2.2.3 or greater
* s3Sync 0.2.0 or greater
* Thor

# Features
s3Gem allows you to maintain an s3-based Ruby Gem repository. You can add or delete gems to your repository and everything will be kept in sync. s3Gem uses my s3Sync gem which functions kind of like rsync. I implemented this on my own dince the AWS S3 SDK for Ruby does not support the sync function that is built into the CLI and using the CLI in a library or module is always bad.

# Installation
* Clone the [repository](https://github.com/gdanko/s3gem)
* Switch to the local respository directory.
* Build the gem package with: `gem build s3gem.gemspec`
* Install the resulting package with: `gem install s3gem-x.x.x.gem`

# Classes
### S3Gem::CLI
This class handles the CLI logic for S3Gem.
### S3Gem::Config
This class maintains CLI options for the Thor CLI framework.
### S3Gem::Repo
This class represents a repo instance. It contains all of the diffing functions.
### S3Gem::Utils
This class contains a series of re-usable/common functions.
# Using the Module
To use the module in a script you simply import it and create an instance of it. But using the CLI is a lot easier.

# Sync Logic
While sync logic is actually part of S3Sync, I feel it's a good idea to explain it here. When a diff is requested, the source and destination directories are parsed and a hash is created for each. Within each hash is a list of every file with some metadata, including the file's md5sum. Several lists are created from these two hashes:
* Common (files are in both source and destination and are identical)
* Source all
* Destination all
* Source only
* Destination only
* Source MD5 mismatch
* Destination MD5 mismatch

From there the sync logic works as such. If a file exists in the destination but not in the source, it is deleted ONLY if the delete flag is set to true. Files that exist only in the source are copied to the destination. If the same FILENAME exists in both locations, but their md5sums are different, the source takes precedence.

# The s3gem Configuration File
Your repos are all stored in a file named ~/.s3gem.yml. The file format is pretty simple.
```
repos:
  ap:
    region: "us-west-2"
    bucket: "myrepo"
    path: "gem-repo"
    profile: "default"
default: ap
```
In this example, the s3 repo would look like this `s3://myrepo/gem-repo/` and you would specify `--repo ap` on the command line when using this repo.

If you do not wish to specify --repo on the command line, you can set the default repo name in your config file.

# The s3gem Local Repository
~/.s3gem/s3-us-west-2.amazonaws.com/myrepo/gem-repo/
s3gem stores a local copy of each maintained repository under `~/.s3gem`. The format for a repository's local copy is as follows: `~/.s3gem/s3-<region>.amazonaws.com/<bucket>/<path>/`. This is the directory that is used for diff, sync, add, and delete commands.

# CLI Help
The CLI has very few commands. This section will provide a reference for each.
### List
This command will list every gem that resides in the specified repository. Its output looks like this.
```
[gdanko@SDGL141bb265b ~]$ s3gem list --repo ap
building file list ... done
foo-0.3.2.gem
bar-0.2.1.gem
baz-0.0.7.gem
```
### Diff
This command will show you the difference between each your repo and your local copy. Its output looks like this.
```
[gdanko@SDGL141bb265b ~]$ s3gem diff --repo ap
building file list ... done
Only in s3: gems/foo-0.3.2.gem
Only in s3: gems/bar-0.2.1.gem
Only in s3: gems/baz-0.0.7.gem
Only in s3: latest_specs.4.8
Only in s3: latest_specs.4.8.gz
Only in s3: prerelease_specs.4.8
Only in s3: prerelease_specs.4.8.gz
Only in s3: quick/Marshal.4.8/foo-0.3.2.gemspec.rz
Only in s3: quick/Marshal.4.8/bar-0.2.1.gemspec.rz
Only in s3: quick/Marshal.4.8/baz-0.0.7.gemspec.rz
Only in s3: specs.4.8
Only in s3: specs.4.8.gz
```
### Sync
This command forces a sync from the repo to the local copy.

## Add
This command adds a new gem to your existing repo. It warrants a bit of detail because it does a little bit more. The add command performs the following steps.
* Sync the repo from S3.
* Verify that the specified gem file exists.
* Verify that the specified file is a real Ruby gem.
* Copy the new gem to the local repository copy.
* Rebuild the gem index in the local repository copy.
* Sync the local repository copy to S3.

Its output looks like this
```
[gdanko@SDGL141bb265b ~]$ s3gem add /Users/gdanko/git/ruby-baz/baz-0.0.7.gem --repo ap
building file list ... done
Generating Marshal quick index gemspecs for 4 gems
....
Complete
Generated Marshal quick index gemspecs: 0.002s
Generating specs index
Generated specs index: 0.000s
Generating latest specs index
Generated latest specs index: 0.000s
Generating prerelease specs index
Generated prerelease specs index: 0.000s
Compressing indicies
Compressed indicies: 0.001s
building file list ... done
upload: /Users/gdanko/.s3gem/s3-us-west-2.amazonaws.com/myrepo/gem-repo/gems/baz-0.0.7.gem to s3://myrepo/gem-repo/gems/baz-0.0.7.gem
upload: /Users/gdanko/.s3gem/s3-us-west-2.amazonaws.com/myrepo/gem-repo/quick/Marshal.4.8/baz-0.0.7.gemspec.rz to s3://myrepo/gem-repo/quick/Marshal.4.8/baz-0.0.7.gemspec.rz
upload: /Users/gdanko/.s3gem/s3-us-west-2.amazonaws.com/myrepo/gem-repo/latest_specs.4.8 to s3://myrepo/gem-repo/latest_specs.4.8
upload: /Users/gdanko/.s3gem/s3-us-west-2.amazonaws.com/myrepo/gem-repo/latest_specs.4.8.gz to s3://myrepo/gem-repo/latest_specs.4.8.gz
upload: /Users/gdanko/.s3gem/s3-us-west-2.amazonaws.com/myrepo/gem-repo/prerelease_specs.4.8.gz to s3://myrepo/gem-repo/prerelease_specs.4.8.gz
upload: /Users/gdanko/.s3gem/s3-us-west-2.amazonaws.com/myrepo/gem-repo/specs.4.8 to s3://myrepo/gem-repo/specs.4.8
upload: /Users/gdanko/.s3gem/s3-us-west-2.amazonaws.com/myrepo/gem-repo/specs.4.8.gz to s3://myrepo/gem-repo/specs.4.8.gz
```
## Delete
This command deletes an existing gem from your existing repo. It warrants a bit of detail because it does a little bit more. The add command performs the following steps.
* Sync the repo from S3.
* Verify that the specified gem file exists in the local repository copy.
* Deletes the file from the local repository copy.
* Rebuild the gem index in the local repository copy.
* Sync the local repository copy to S3.

Its output looks like this
```
[gdanko@SDGL141bb265b ~]$ s3gem delete baz-0.0.7.gem --repo ap
building file list ... done
Generating Marshal quick index gemspecs for 3 gems
...
Complete
Generated Marshal quick index gemspecs: 0.002s
Generating specs index
Generated specs index: 0.000s
Generating latest specs index
Generated latest specs index: 0.000s
Generating prerelease specs index
Generated prerelease specs index: 0.000s
Compressing indicies
Compressed indicies: 0.001s
building file list ... done
upload: /Users/gdanko/.s3gem/s3-us-west-2.amazonaws.com/myrepo/gem-repo/latest_specs.4.8 to s3://myrepo/gem-repo/latest_specs.4.8
upload: /Users/gdanko/.s3gem/s3-us-west-2.amazonaws.com/myrepo/gem-repo/latest_specs.4.8.gz to s3://myrepo/gem-repo/latest_specs.4.8.gz
upload: /Users/gdanko/.s3gem/s3-us-west-2.amazonaws.com/myrepo/gem-repo/prerelease_specs.4.8.gz to s3://myrepo/gem-repo/prerelease_specs.4.8.gz
upload: /Users/gdanko/.s3gem/s3-us-west-2.amazonaws.com/myrepo/gem-repo/specs.4.8 to s3://myrepo/gem-repo/specs.4.8
upload: /Users/gdanko/.s3gem/s3-us-west-2.amazonaws.com/myrepo/gem-repo/specs.4.8.gz to s3://myrepo/gem-repo/specs.4.8.gz
delete: s3://myrepo/gem-repo/gems/baz-0.0.7.gem
delete: s3://myrepo/gem-repo/quick/Marshal.4.8/baz-0.0.7.gemspec.rz
```
