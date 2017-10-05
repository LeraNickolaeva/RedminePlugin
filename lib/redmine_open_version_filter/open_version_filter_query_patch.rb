module OpenVersionFilterQueryPatch
  def self.included(base)
    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable

      alias_method_chain :available_filters, :open_version_filter
    end
  end

  module InstanceMethods

    # add filters
    def available_filters_with_open_version_filter
      filters = available_filters_without_open_version_filter

      filters.merge!('from_versions_open_version_filter' =>
        {
          :name => l('field_in_opened_versions'),
          :order => 1,
          :values => [[l(:in_opened_versions), :in_opened_versions], [l(:out_of_opened_versions), :out_of_opened_versions]],
        })

      if self.type != "IssueQuery"
        project_name = Project.where(id: self.project_id).first.name
        version_name = Version.where(project_id: self.project_id).pluck(:name)
        name_for_select = version_name.map! { |version_name| version_name = "#{project_name} - " + version_name }
        filters.merge!('fixed_version_id' =>
          {
            :name => l('field_version'),
            :order => 1,
            :type => :list_optional,
            :values => name_for_select,
          })
      else
        filters
      end
    end

    def sql_for_from_versions_open_version_filter_field(field, operator, value)
      scope = Version
      projects = project && project.self_and_descendants
      if projects
        all_shared_version_ids = projects.map(&:shared_versions).flatten.map(&:id).uniq
        scope = scope.where(id: all_shared_version_ids)
      end
      if value == ["in_opened_versions"]
        version_ids = scope.open.visible.all(:conditions => 'effective_date IS NOT NULL').collect(&:id).push(0)
        # do not care about operator and value - just add a condition if filter "in_open_versions" is enabled
        if self.type == "IssueQuery"
          "(#{Issue.table_name}.fixed_version_id IN (#{version_ids.join(',')}))"
        else
        #   # Issue.where(id: TimeEntry.pluck(:issue_id)).where(fixed_version_id: [version_ids])
          "(#{Issue.table_name}.where(id: #{TimeEntry.table_name}.pluck(issue_id)).fixed_version_id IN (#{version_ids.join(',')}))"
        end
      elsif value == ['out_of_opened_versions']
        version_ids = scope.open.visible.all(:conditions => 'effective_date IS NULL').collect(&:id).push(0)
        # do not care about operator and value - just add a condition if filter "in_open_versions" is enabled
        if self.type == "IssueQuery"
          "(#{Issue.table_name}.fixed_version_id IN (#{version_ids.join(',')}) OR #{Issue.table_name}.fixed_version_id IS NULL)"
        else
          "(#{Issue.table_name}.where(id: #{TimeEntry.table_name}.pluck(issue_id)).fixed_version_id IN (#{version_ids.join(',')}) OR #{Issue.table_name}.where(id: #{TimeEntry.table_name}.pluck(issue_id)).fixed_version_id IS NULL)"
        end
      end

    end

  end

end
