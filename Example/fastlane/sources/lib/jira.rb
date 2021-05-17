require_relative '../helper/credentials_helper.rb'

private_lane :rsb_move_jira_tickets do |options|
  project = ENV['JIRA_PROJECT']
  jira_website = ENV['JIRA_WEBSITE']
  next unless jira_website
  next unless project

  tickets = options[:tickets]  
  next unless !tickets.empty?

  transition_id = options[:transition][:id]
  client = rsb_jira_client

  tickets.each do |ticket|
    transition = ticket.transitions.build
    transition.save!('transition' => { 'id' => transition_id })
  end
end

private_lane :rsb_search_jira_tickets do |options|
  project_name = ENV['JIRA_PROJECT']
  jira_website = ENV['JIRA_WEBSITE']
  component = ENV['JIRA_COMPONENT']
  label = ENV['JIRA_TASK_LABEL']

  next unless jira_website
  next unless project_name

  client = rsb_jira_client

  statuses = options[:statuses]
  mine = options[:mine]
  task = options[:task]
  task = false if ffreezing?

  jql_string = "project = #{project_name.shellescape}"
  jql_string += " AND sprint in openSprints()"
  jql_string += " AND status in (#{statuses.map{ |status| status[:id] }.join(", ")})" if (statuses && statuses.count > 0)
  jql_string += " AND component = #{component}" if component
  jql_string += " AND labels = #{label}" if label
  if mine != nil
    mine ? jql_string += " AND assignee = currentuser()" : jql_string += " AND (assignee != currentuser() OR assignee is EMPTY)"
  end
  if task != nil
    task ? jql_string += " AND issuetype not in (bug, sub-bug)" : jql_string += " AND issuetype in (bug, sub-bug)"
  end

  tickets = client.Issue.jql(jql_string)  

  key = options[:key]
  if key
    ticket = rsb_select_jira_ticket_with_key(tickets, key)
    tickets = [ticket] if ticket
  end

  tickets
end

def rsb_select_jira_tickets_assigned_to_me(tickets)
  client = rsb_jira_client
  me = client.User.myself
  tickets.select { |ticket| !ticket.assignee.nil? }.select { |ticket| me.accountId == ticket.assignee.accountId }
end

def rsb_select_jira_tickets_not_assigned_to_me(tickets)
  client = rsb_jira_client
  me = client.User.myself
  tickets.select { |ticket| ticket.assignee.nil? || me.accountId != ticket.assignee.accountId }
end

def rsb_select_jira_tickets_with_statuses(tickets, statuses)
  status_names = statuses.map { |status| status[:name] }
  tickets.select { |ticket| status_names.include? ticket.status.attrs["name"] } 
end

def rsb_select_jira_ticket_with_key(tickets, key)
  key_parameters = key.split('-')
  if key_parameters.count > 1 
    ticket_key = key 
  else
    project_key = tickets.first.project.key  
    ticket_key = "#{project_key}-#{key}"
  end 
  tickets.select { |ticket| ticket_key == ticket.key }.first
end

def rsb_select_jira_tasks(tickets)
  tickets.select { |ticket| rsb_is_bug_jira(ticket) == false }
end

def rsb_select_jira_bugs(tickets)
  tickets.select { |ticket| rsb_is_bug_jira(ticket) }
end

def rsb_is_bug_jira(ticket)
  ticket.issuetype.name == 'Bug' || ticket.issuetype.name == 'Sub-bug'
end

def rsb_select_jira_ticket_with_dialog(tickets, dialog_title)
  if tickets.count > 1
    ticket_titles = tickets.map { |ticket| "#{ticket.status.attrs["name"]}: #{ticket.issuetype.name}, #{ticket.key}, #{rsb_ticket_name(ticket)}" }
    selected_ticket_title = UI.select(dialog_title, ticket_titles)
    tickets[ticket_titles.index(selected_ticket_title)]
  else
    tickets.first
  end
end

def rsb_ticket_description(ticket, for_git)
  separator = for_git ? "-" : " -> "
  name = ticket.summary
  if ticket.issuetype.subtask == true
    name = ticket.parent["fields"]["summary"] + separator + ticket.summary
  end
  name
end

def rsb_ticket_name(ticket)
  rsb_ticket_description(ticket, false)
end

def rsb_git_ticket_name(ticket)
  rsb_ticket_description(ticket, true)
end

def rsb_jira_tickets_description(tickets)
  description = ''

  features = []
  fixes = []

  tickets.to_a.each do |ticket|
    if rsb_is_bug_jira(ticket)
      fixes.push(ticket)
    else
      features.push(ticket)
    end
  end

  unless features.empty?
    description += "\nFeatures:"
    features.each do |ticket|
      description += "\n  #{rsb_ticket_name(ticket)} (#{ENV['JIRA_WEBSITE']}/browse/#{ticket.key})"
    end    
  end
  
  unless fixes.empty?
    description += "\n" unless description.empty?
    description += "\nFixes:"
    fixes.each do |ticket|
      description += "\n  #{rsb_ticket_name(ticket)} (#{ENV['JIRA_WEBSITE']}/browse/#{ticket.key})"
    end
  end

  description
end

def rsb_jira_client
  Actions.verify_gem!('jira-ruby')

  jira_website = ENV['JIRA_WEBSITE']
  credentials = rsb_credentials('JIRA', jira_website)
  options = {
    site: jira_website,
    context_path: '',
    auth_type: :basic,
    username: credentials[:email],
    password: credentials[:token]
  }

  JIRA::Client.new(options)
end

def rsb_jira_status
  { 
    :to_do        => { :name => "To Do",        :id => 10304 },
    :doing        => { :name => "Doing",        :id => 10303 },
    :code_review  => { :name => "Code Review",  :id => 10802 },
    :ready        => { :name => "Ready",        :id => 10803 },
    :test_build   => { :name => "Test Build",   :id => 10804 },
    :done         => { :name => "Done",         :id => 10302 }
  }
end

def rsb_jira_transition
  {
    :to_do        => { :name => "To Do",        :id => 11 },
    :doing        => { :name => "Doing",        :id => 21 },
    :code_review  => { :name => "Code Review",  :id => 41 },
    :ready        => { :name => "Ready",        :id => 51 },
    :test_build   => { :name => "Test Build",   :id => 61 },
    :done         => { :name => "Done",         :id => 81 },
    :wont_do      => { :name => "Won't Do",     :id => 71 },
    :reopen       => { :name => "Re-open",      :id => 91 }
  }
end