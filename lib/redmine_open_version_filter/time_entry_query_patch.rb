module TimeEntryQueryPatch
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
 
      versions = project.shared_versions.all

      add_available_filter "fixed_version_id",
        :name => l('field_fixed_version'),
        :type => :list_optional,
        :values => versions.sort.collect{|s| ["#{s.project.name} - #{s.name}", s.id.to_s] }
        
    end

    def sql_for_from_versions_open_version_filter_field(field, operator, value)
      scope = Version
      projects = project && project.self_and_descendants
      if projects
        all_shared_version_ids = projects.map(&:shared_versions).flatten.map(&:id).uniq
        scope = scope.where(id: all_shared_version_ids)
      end
      if value == ["in_opened_versions"]
        version_ids = scope.open.where(project_id: project.id).visible.all(:conditions => 'effective_date IS NOT NULL').collect(&:id)
        if version_ids.present?
          issue_ids = Issue.where(fixed_version_id: version_ids).pluck(:id)
          "(#{TimeEntry.table_name}.issue_id IN (#{issue_ids.join(',')}))"   
        else
          '1 = 0'
        end
      elsif value == ['out_of_opened_versions']
        version_ids = scope.open.visible.all(:conditions => 'effective_date IS NULL').collect(&:id)
        if version_ids.present?
          issue_ids = (Issue.where('fixed_version_id IS NULL OR fixed_version_id=?', version_ids)).pluck(:id)
          "(#{TimeEntry.table_name}.issue_id IN (#{issue_ids.join(',')}))" 
        else
          '1 = 0'
        end
      end
    end

    def sql_for_fixed_version_id_field(field, operator, value)
      if Issue.where(fixed_version_id: value[0].to_i).present?
        issue_ids = Issue.where(fixed_version_id: value[0].to_i).pluck(:id)
        "(#{TimeEntry.table_name}.issue_id IN (#{issue_ids.join(',')}))" 
      else
        '1 = 0'
      end
    end
  end
end
