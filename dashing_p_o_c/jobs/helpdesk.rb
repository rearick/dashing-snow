# Declare required modules
require 'csv'
require 'date'
require 'time'

# Set constants
INPUT_FILE = "/vagrant/dashing_p_o_c/assets/snowData/IFTTT/dashingFeed.1001.csv"
ASSIGNMENT_GROUP = "ITS Helpdesk"
EXCLUDE_STATE = "Closed"
ONE_DAY = 86400

# Define a CSV parser converter to change empty fields to nil
CSV::Converters[:blank_to_nil] = lambda do |field|
  field && field.empty? ? nil : field
end

# Define a CSV parser converter to cast time strings to time objects
CSV::Converters[:string_to_time] = lambda do |field|
  field && (field[-3..-1] == "EDT" || field[-3..-1] == "EST") ? Time.parse(field) : field
end

# Define a method for makeing integer arrays cummulative
def make_cummulative(array)
  for i in 1...array.length
    array[i] += array[i-1]
  end
  return array
end

# Convert seconds to human readable format y m w d h m s
def convert_seconds(seconds)
  elapsed_time = (seconds / (ONE_DAY * 365)).to_s + "y "
  seconds %= (ONE_DAY * 365)
  elapsed_time = elapsed_time + (seconds / (ONE_DAY * 30)).to_s + "m "
  seconds %= (ONE_DAY * 30)
  elapsed_time = elapsed_time + (seconds / (ONE_DAY * 7)).to_s + "w "
  seconds %= (ONE_DAY * 7)
  elapsed_time = elapsed_time + (seconds / ONE_DAY).to_s + "d "
  seconds %= ONE_DAY
  elapsed_time = elapsed_time + (seconds / (60 * 60)).to_s + "h "
  seconds %= (60 * 60)
  elapsed_time = elapsed_time + (seconds / 60).to_s + "m "
  seconds %= 60
  elapsed_time = elapsed_time + seconds.to_s + "s"
  return elapsed_time
end

# Convert time object to formated string
format_time = lambda do |time|
  time.strftime("%a, %m/%d")
end

# Identify ServiceNow incident urgency levels
urgency_levels = {
  critical: "1 - Critical",
  high:     "2 - High",
  medium:   "3 - Medium",
  low:      "4 - Low"
}

# Identify ServiceNow incident states
incident_states = {
  new:                "New",
  assigned:           "Assigned",
  work_in_progress:   "Work in Progress",
  pending:            "Pending",
  resolved:           "Resolved"
}

# Identify ServiceNow incident age groups
incident_age_groups = {
  one_day:          "<= 1 Day",
  over_one_day:     "> 1 Day",
  over_seven_days:  "> 7 Days",
  over_15_days:     "> 15 Days",
  over_30_days:     "> 30 Days"
}

# Calculate and send metrics to the helpdesk dashboard once every 10 minutes
SCHEDULER.every '30s' do# Declare Average Resolve Time hash

  # Declare Average Resolve Times hash
  average_resolve_time = Hash.new(0)
  urgency_levels.each { |key, value| average_resolve_time[value] = 0 }

  # Declare Average Resolve Times shipping container
  resolve_time_shipper = Hash.new({ value: "" })

  # Declare Incident State Counts hash
  incident_state_counts = Hash.new(0)
  incident_states.each { |key, value| incident_state_counts[value] = 0 }

  # Declare Incident State counts shipping container
  incident_states_shipper = Hash.new({ value: 0 })

  # Declare Incident Age Counts hash
  incident_age_counts = Hash.new(0)
  incident_age_groups.each { |key, value| incident_age_counts[value] = 0 }

  # Declare Resolved Incident Urgency Counts hash
  resolved_incident_urgency_counts = Hash.new(0)
  urgency_levels.each { |key, value| resolved_incident_urgency_counts[value] = 0 }

  # Declare Active Incident Urgency Counts hash
  active_incident_urgency_counts = Hash.new(0)
  urgency_levels.each { |key, value| active_incident_urgency_counts[value] = 0 }

  # Declare Created vs Resolved chart labels array
  created_vs_resolved_labels = Array.new
  count = 6
  while count > -1
    created_vs_resolved_labels << Time.parse(Date.parse(Time.now.to_s).to_s) - (ONE_DAY * count)
    count -= 1
  end

  # Declare Created vs Resolved chart created data array
  created_data = Array.new
  7.times { created_data << 0 }

  # Declare Created vs Resolved chart resolved data array
  resolved_data = Array.new
  7.times { resolved_data << 0 }

  # Read the csv file in with all appropriate read options selected to include the two previously defined CSV converters
  input_buffer = CSV.read(INPUT_FILE, encoding: "UTF-8", headers: true, header_converters: :symbol, converters: [:all, :blank_to_nil, :string_to_time])

  # Convert each row of the csv table into a hash to ensure the column order does not matter
  dashing_feed_data = input_buffer.map(&:to_hash)

  # Clear input_buffer to free up memory
  input_buffer = []

  # Calculate metrics
  dashing_feed_data.each do |row|
    # Average Resolve Times and Active Incidents by Urgency data collection
    urgency_levels.each do |key, urgency|
      # Average Resolve Times
      # Focus on records that are assigned to the ASSIGNMENT_GROUP, are resolved, and have current loop iteration urgency 
      if row[:assignment_group] == ASSIGNMENT_GROUP && row[:state] == incident_states[:resolved] && row[:urgency] == urgency

        # Accumulate resolved incident urgency totals
        resolved_incident_urgency_counts[urgency] += 1

        # Accumulate incident duration
        average_resolve_time[urgency] += row[:calendar_duration]

      end

      # Active Incidents by Urgency
      # Focus on records that are assigned to the ASSIGNMENT_GROUP, are NOT resolved, are NOT equal to EXCLUDE_STATE, and have current loop iteration urgency
      if row[:assignment_group] == ASSIGNMENT_GROUP && row[:state] != incident_states[:resolved] && row[:state] != EXCLUDE_STATE && row[:urgency] == urgency
        
        # Accumulate active incident urgency totals
        active_incident_urgency_counts[urgency] += 1

      end
    end

    # Incidents by State data collection
    incident_states.each do |key, state|
      
      # Focus on records that are assigned to the ASSIGNMENT_GROUP and have current loop iteration state
      if row[:assignment_group] == ASSIGNMENT_GROUP && row[:state] == state
        
        # Accumulate incident state totals
        incident_state_counts[state] += 1

      end
    end

    # Active Incidents by Age data collection
    # Focus on records that are assigned to the ASSIGNMENT_GROUP, are NOT resolved, and are NOT equal to EXCLUDE_STATE
    if row[:assignment_group] == ASSIGNMENT_GROUP && row[:state] != incident_states[:resolved] && row[:state] != EXCLUDE_STATE
      
      # Accumulate incidents a day old or less
      if (Time.now - row[:sys_created_on]) <= ONE_DAY
        incident_age_counts[incident_age_groups[:one_day]] += 1

      # Accumulate incidents older than a day and less than or equal to seven
      elsif (Time.now - row[:sys_created_on]) > ONE_DAY && (Time.now - row[:sys_created_on]) <= (ONE_DAY * 7)
        incident_age_counts[incident_age_groups[:over_one_day]] += 1

      # Accumulate incidents older than seven days and less than or equal to 15
      elsif (Time.now - row[:sys_created_on]) > (ONE_DAY * 7) && (Time.now - row[:sys_created_on]) <= (ONE_DAY * 15)
        incident_age_counts[incident_age_groups[:over_seven_days]] += 1

      # Accumulate incidents older than 15 days and less than or equal to 30
      elsif (Time.now - row[:sys_created_on]) > (ONE_DAY * 15) && (Time.now - row[:sys_created_on]) <= (ONE_DAY * 30)
        incident_age_counts[incident_age_groups[:over_15_days]] += 1

      # Accumulate incidetns older than 30 days
      else
        incident_age_counts[incident_age_groups[:over_30_days]] += 1

      end
    end

    # Created vs Resolved data collection
    # Focus on records that are assigned to the ASSIGNMENT_GROUP
    if row[:assignment_group] == ASSIGNMENT_GROUP

      # Collect created incidents over the past seven days
      if Time.parse(Date.parse(row[:sys_created_on].to_s).to_s) == created_vs_resolved_labels[0]
        created_data[0] += 1

      elsif Time.parse(Date.parse(row[:sys_created_on].to_s).to_s) == created_vs_resolved_labels[1]
        created_data[1] += 1

      elsif Time.parse(Date.parse(row[:sys_created_on].to_s).to_s) == created_vs_resolved_labels[2]
        created_data[2] += 1

      elsif Time.parse(Date.parse(row[:sys_created_on].to_s).to_s) == created_vs_resolved_labels[3]
        created_data[3] += 1

      elsif Time.parse(Date.parse(row[:sys_created_on].to_s).to_s) == created_vs_resolved_labels[4]
        created_data[4] += 1

      elsif Time.parse(Date.parse(row[:sys_created_on].to_s).to_s) == created_vs_resolved_labels[5]
        created_data[5] += 1

      elsif Time.parse(Date.parse(row[:sys_created_on].to_s).to_s) == created_vs_resolved_labels[6]
        created_data[6] += 1
      end

      # Collect resolved incidents over the past seven days
      if row[:resolved_at] && Time.parse(Date.parse(row[:resolved_at].to_s).to_s) == created_vs_resolved_labels[0]
        resolved_data[0] += 1

      elsif row[:resolved_at] && Time.parse(Date.parse(row[:resolved_at].to_s).to_s) == created_vs_resolved_labels[1]
        resolved_data[1] += 1

      elsif row[:resolved_at] && Time.parse(Date.parse(row[:resolved_at].to_s).to_s) == created_vs_resolved_labels[2]
        resolved_data[2] += 1

      elsif row[:resolved_at] && Time.parse(Date.parse(row[:resolved_at].to_s).to_s) == created_vs_resolved_labels[3]
        resolved_data[3] += 1

      elsif row[:resolved_at] && Time.parse(Date.parse(row[:resolved_at].to_s).to_s) == created_vs_resolved_labels[4]
        resolved_data[4] += 1

      elsif row[:resolved_at] && Time.parse(Date.parse(row[:resolved_at].to_s).to_s) == created_vs_resolved_labels[5]
        resolved_data[5] += 1

      elsif row[:resolved_at] && Time.parse(Date.parse(row[:resolved_at].to_s).to_s) == created_vs_resolved_labels[6]
        resolved_data[6] += 1
      end

    end
  end

  # Release dashing_feed_data memory
  dashing_feed_data = {}

  # Prepare metrics to ship
  # Average Resolve Times
  average_resolve_time.each do |key, value|
    # Prepare the averages
    if resolved_incident_urgency_counts[key] > 0
      average_resolve_time[key] /= resolved_incident_urgency_counts[key]
    end
  end

  average_resolve_time.each do |key, value|
    # Format the results
    average_resolve_time[key] = convert_seconds(value)
  end

  # Parse the data into the appropriate dashing format
  average_resolve_time.each do |key, value|
    resolve_time_shipper[key] = { label: key[4..-1], value: average_resolve_time[key] }
  end

  # Incidents by State
  # Parse the data into the appropriate dashing format
  incident_state_counts.each do |key, value|
    incident_states_shipper[key] = { label: key, value: incident_state_counts[key] }
  end

  # Active Incidents by Age
  # Parse the data into the appropriate dashing format
  incident_age_data = [
    {
      label: 'Age Distribution',
      data: incident_age_counts.values,
      backgroundColor: [ 'rgba(0, 40, 104, 0.3)' ] * incident_age_counts.keys.length,
      borderColor: [ 'rgba(0, 40, 104, 1)' ] * incident_age_counts.keys.length,
      borderWidth: 1,
    }
  ]

  # Active Incidents by Urgency
  # Parse the data into the appropriate dashing format
  incident_urgency_data = [
    {
      label: 'Urgency Distribution',
      data: active_incident_urgency_counts.values,
      backgroundColor: [ 'rgba(191, 145, 12, 0.3)' ] * active_incident_urgency_counts.keys.length,
      borderColor: [ 'rgba(191, 145, 12, 1)' ] * active_incident_urgency_counts.keys.length,
      borderWidth: 1,
    }
  ]

  # Created vs Resolved
  # Make the created data cummulative
  created_data = make_cummulative(created_data)

  # Make the resolved data cummulative
  resolved_data = make_cummulative(resolved_data)

  # Format the labels nicely
  created_vs_resolved_labels.map!(&format_time)

  created_vsresolved_data = [
    {
      label: 'Created',
      data: created_data,
      backgroundColor: [ 'rgba(191, 145, 12, 0.3)' ] * created_vs_resolved_labels.length,
      borderColor: [ 'rgba(191, 145, 12, 1)' ] * created_vs_resolved_labels.length,
      borderWidth: 1,
    }, {
      label: 'Resolved',
      data: resolved_data,
      backgroundColor: [ 'rgba(0, 40, 104, 0.3)' ] * created_vs_resolved_labels.length,
      borderColor: [ 'rgba(0, 40, 104, 1)' ] * created_vs_resolved_labels.length,
      borderWidth: 1,
    }
  ]

=begin
  # Debug statements
  puts resolved_incident_urgency_counts.inspect
  puts average_resolve_time.inspect
  puts active_incident_urgency_counts.inspect
  puts incident_state_counts.inspect
  puts incident_age_counts.inspect
  puts created_vs_resolved_labels.inspect
  puts created_data.inspect
  puts resolved_data.inspect
=end

  # Send metrics
  send_event('7day_avg_res_time_by_urg', { items: resolve_time_shipper.values })
  send_event('7day_incs_by_state', { items: incident_states_shipper.values })
  send_event('active_incs_by_age', { labels: incident_age_counts.keys, datasets: incident_age_data })
  send_event('active_incs_by_urg', { labels: active_incident_urgency_counts.keys, datasets: incident_urgency_data })
  send_event('7day_crtd_vs_res', { labels: created_vs_resolved_labels, datasets: created_vsresolved_data })

end