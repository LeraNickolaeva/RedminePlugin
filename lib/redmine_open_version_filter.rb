require 'redmine_open_version_filter/issue_query_patch'
require 'redmine_open_version_filter/time_entry_query_patch'

Rails.configuration.to_prepare do
  IssueQuery.send(:include, IssueQueryPatch)
  TimeEntryQuery.send(:include, TimeEntryQueryPatch)
end
