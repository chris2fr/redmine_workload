require 'redmine'

# Patches to the Redmine core.
require 'dispatcher'
require 'issue_patch'
require 'user_patch'
Dispatcher.to_prepare do
  Issue.send(:include, IssuePatch)
  Query.send(:include, UserPatch)
end


Redmine::Plugin.register :redmine_workload do
  name 'Redmine Workload plugin'
  author 'Christopher Mann <christopher@mann.fr>'
  description 'This plugin handles workload estimations for Redmine.'
  version '0.0.1'
end
