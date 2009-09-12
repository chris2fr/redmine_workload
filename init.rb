require 'redmine'
require 'workload_lib'

Redmine::Plugin.register :redmine_workload do
  name 'Redmine Workload plugin'
  author 'Christopher Mann <christopher@mann.fr>'
  description 'This plugin handles workload estimations for Redmine.'
  version '0.0.1'

  menu	:top_menu, :redmine_workload, { :controller => 'workload', :action => 'timetable' }, :caption => :workload_label

end
