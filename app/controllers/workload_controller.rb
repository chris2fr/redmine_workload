class WorkloadController < ApplicationController


  def timetable_summary
  end

  def timetable_update
	@flag = "non"
	act_id = Enumeration.find(:first,:conditions => {:opt => "ACTI"} ).id
	params[:time_entry].each do |issue_id, hours|
		@spent_hours = get_spent_hours(issue_id,params[:user_id].to_i(),params[:date])
		#unless @spent_hours == hours.to_f()
			if (@spent_hours == 0.0 and hours != "0")  # Ajouter TimeEntry
				@te = TimeEntry.create()
				@te.hours = hours.to_i()
				@te.activity_id = act_id
				issue = Issue.find(:first,:conditions => {:id => issue_id})
				@te.project_id = issue.project_id
				@te.issue_id = issue_id.to_i()
				@te.user_id = params[:user_id]
				@te.spent_on = params[:date]
				@te.save()
			elsif @spent_hours != 0 and hours == "0"#  and hours == "0" # Supprimer
				TimeEntry.delete(TimeEntry.find(:first, :conditions => {:user_id => params[:user_id].to_i(),:issue_id => issue_id, :spent_on => params[:date]}).id)
				@flag = "oui"
			elsif @spent_hours != hours.to_f()
				@te = TimeEntry.find(:first, :conditions => {:user_id => params[:user_id].to_i(),:issue_id => issue_id, :spent_on => params[:date]})
				@te.hours = hours
				@te.save()
			end
		#end
	end
	@date = Date::parse(params[:date])
	@conditions = 'user_id = '+params[:user_id] + ' AND spent_on > "' + (@date - 30).to_s() + '" AND spent_on < "' + (@date + 30).to_s() + '"'
	@logged_te = TimeEntry.find(:all,:conditions => [@conditions], :order => ['issue_id,spent_on'] )
	@logged_issues = {}
	@logged_days = {}
	@total_days = {}
	@projcat = {}
	@projects = Project.find(:all, :conditions => {:status => 1}, :order => ['parent_id,name'])
	@projects.each do |projet|
		@projcat[projet.id] = {}
		@projcat[projet.id]["total"] = 0.0
		issue_categories = projet.issue_categories
		projet.issue_categories.each do |cat|
			@projcat[projet.id][cat.id] = {}
		end
	end
	@logged_te.each do |te|
		unless @logged_issues.has_key?(te.issue_id)
			@logged_issues[te.issue_id] = Issue.find(:first, :conditions => {:id => te.issue_id})
			@logged_days[te.issue_id] = {}
			#(-29..29).each do |delta|
			#	@logged_days[te.issue_id][(@date + delta).to_s()] = 0
			#end
		end
		if te.spent_on
			@logged_days[te.issue_id][te.spent_on.to_s()] = te.hours.to_f() / 8
			####### @projcat[te.project_id][te.project.category_id][te.spent_on.to_s()] = te.hours.to_f() / 8
			@projcat = add_to_projcat(@projcat, te.issue.project, te.issue.category, te) 
			unless @total_days.has_key?(te.spent_on.to_s())
				@total_days[te.spent_on.to_s()] = te.hours.to_f() / 8
			else
				@total_days[te.spent_on.to_s()] += te.hours.to_f() / 8
			end
		end
	end
  end

  def timetable
	if params[:user_id]
		@current_user_id = params[:user_id].to_i()
	else
		@current_user_id = User.current.id.to_i()
	end
	if params[:date]
		@current_date = params[:date]
	else
		now = DateTime::now()
		date = Date::civil(now.year,now.month,now.mday)
		@current_date = date.to_s()
	end
	@users = User.find(:all,:order => ['firstname'])
	projects = Project.find(:all, :conditions => {:status => 1}, :order => ['parent_id,name'])
	@project_list = {}
	@category_list = {}
	@status_list = {}
	@tracker_list = {}
	trackers = Tracker.find(:all)
	trackers.each do |tracker|
		@tracker_list[tracker.id] = tracker
	end
	statuses = IssueStatus.find(:all)
	statuses.each do |status|
		@status_list[status.id] = status
	end
	projects.each do |project|
		@project_list[project.id] = project
		cats = IssueCategory.find(:all,:conditions => {:project_id => project.id},:order => ['name'])
		cats.each do |cat|
			@category_list[cat.id] = cat
		end
	end
	#projet
	@hours_total = 0
	@time_entries_hours = {}
	# Time-logged issues
	@logged_issues = {}
	time_entries = TimeEntry.find(:all,:conditions => {:user_id => @current_user_id, :spent_on => @current_date})
	if time_entries
		seen_te = {}
		time_entries.each do |time_entry|
				if time_entry.hours > 8
					time_entry.hours = 8
					time_entry.save()
				end
				# Fuse all multiple te for a same date
				if seen_te.has_key?(time_entry.issue_id)
					seen_te[time_entry.issue_id].hours += time_entry.hours
					if time_entry.comments
						seen_te[time_entry.issue_id].comments += " + " + time_entry.comments
					end
					@hours_total += time_entry.hours
					seen_te[time_entry.issue_id].save()
					TimeEntry.delete(time_entry.id)
					@logged_issues[time_entry.issue_id] = get_spent_hours(time_entry.issue_id, @current_user_id,@current_date)
				else
					seen_te[time_entry.issue_id] = time_entry
					@logged_issues[time_entry.issue_id] = Issue.find(:first,:conditions => {:id => time_entry.issue_id})
					@time_entries_hours[time_entry.issue_id] = get_spent_hours(time_entry.issue_id, @current_user_id,@current_date)
					@hours_total += time_entry.hours
				end
		end
	end
	# Assigned issues
	@assigned_issues = {}
	issues = Issue.find(:all, :conditions => ["assigned_to_id = " + @current_user_id.to_s()], :order => ["project_id, category_id, id"] )
	issues.each do |issue|
		unless (@logged_issues and @logged_issues[issue.id])
			#@time_entries_hours[issue.id] = get_spent_hours(issue.id, params[:user_id],params[:date])
			@assigned_issues[issue.id] = issue
		end
	end
	# Watched issues
	watched = Watcher.find(:all, :conditions => {:user_id => @current_user_id, :watchable_type => "issue"})
	@watched_issues = {}
	watched.each do |watched_issue|
		unless (@logged_issues and @logged_issues[watched_issue.watchable_id]) or (@assigned_issues and @assigned_issues[watched_issue.watchable_id])
			@watched_issues[watched_issue.watchable_id] = Issue.find(:first, :conditions => {:id => watched_issue.watchable_id})
		end
	end
	@user = User.find(:first, :conditions => ["id = " + @current_user_id.to_s()])
	#@time_entries = TimeEntry
  end

  	def add_to_projcat (projcat, proj, cat, te)
		unless projcat.has_key?(proj.id)
			projcat[proj.id] = {}
			projcat[proj.id]["total"] = 0.0
		end
		#unless projcat[proj.id].has_key?("total")
		#	projcat[proj.id]["total"] = 0.0
		#end
		unless cat
			cat_id = "other"
		end
		unless projcat[proj.id].has_key?(cat_id)
			projcat[proj.id][cat_id] = {}
			projcat[proj.id][cat_id]["total"] = 0.0
		end
		projcat[proj.id][cat_id][te.spent_on.to_s()] = te.hours.to_f() / 8.0
		projcat[proj.id][cat_id]["total"] += te.hours.to_f() / 8.0
		#projcat[proj.id]["total"] += te.hours.to_f() / 8.0
		return projcat
	end

  def index
  end

  def summary
  end
end
