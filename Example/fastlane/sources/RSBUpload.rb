require_relative 'helper/changelog_helper.rb'
require_relative 'helper/plist_helper.rb'

default_platform :ios

platform :ios do

  before_all do |lane, options|
    Actions.lane_context[SharedValues::FFREEZING] = options[:ffreezing]
    skip_docs
  end

  after_all do |lane|
    clean_build_artifacts
  end

  error do |lane, exception|
    clean_build_artifacts
    if $git_flow & $release_branch_name
      rsb_remove_release_branch(
        name: $release_branch_name
      )
    end
  end

  ### LANES

  lane :rsb_fabric do |options|
    rsb_upload(
      configurations: [:fabric],
      git_flow: options[:git_flow],
      git_build_branch: options[:git_build_branch],
      ci: options[:ci],
      is_release: false,
      skip_match_validation: options[:skip_match_validation],
      skip_match: options[:skip_match]
    )
  end

  lane :rsb_fabric_testflight do |options|
    rsb_upload(
      configurations: [:testflight, :fabric],
      git_flow: options[:git_flow],
      git_build_branch: options[:git_build_branch],
      ci: options[:ci],
      is_release: true,
      skip_match_validation: options[:skip_match_validation],
      skip_match: options[:skip_match]
    )
  end

  lane :rsb_testflight do |options|
    rsb_upload(
      configurations: [:testflight],
      git_flow: options[:git_flow],
      git_build_branch: options[:git_build_branch],
      ci: options[:ci],
      is_release: true,
      skip_match_validation: options[:skip_match_validation],
      skip_match: options[:skip_match]
    )
  end

  lane :rsb_firebase_testflight do |options|
    rsb_upload(
      configurations: [:testflight, :firebase],
      git_flow: options[:git_flow],
      git_build_branch: options[:git_build_branch],
      ci: options[:ci],
      is_release: true,
      skip_match_validation: options[:skip_match_validation],
      skip_match: options[:skip_match]
    )
  end

  lane :rsb_firebase do |options|
    rsb_upload(
      configurations: [:firebase],
      git_flow: options[:git_flow],
      git_build_branch: options[:git_build_branch],
      ci: options[:ci],
      is_release: false,
      skip_match_validation: options[:skip_match_validation],
      skip_match: options[:skip_match]
    )
  end

  lane :rsb_upload do |options|
    upload_via_ci = !!options[:ci]
    $git_flow = options[:git_flow] == nil ? true : options[:git_flow]
    git_build_branch = options[:git_build_branch] == nil ? rsb_current_git_branch : options[:git_build_branch]
    configurations = options[:configurations].kind_of?(Array) ? 
      options[:configurations] : 
      options[:configurations].split(",").map { |configuration| configuration.to_sym }
    is_release = options[:is_release]

    if upload_via_ci
      if rsb_possible_to_trigger_ci_build?
        rsb_trigger_ci_fastlane(
          configurations: configurations,
          git_flow: $git_flow,
          git_build_branch: git_build_branch
        )
        next
      else
        UI.user_error!('You need to configure CI environments: CI_APP_TOKEN, CI_APP_NAME, CI_JENKINS_USER, CI_JENKINS_USER_TOKEN')
      end
    end
  
    if is_ci?
      setup_jenkins
    end

    ensure_git_status_clean
    $release_branch_name = rsb_release_branch_name(options[:is_release])

    ready_tickets = rsb_search_jira_tickets(
      statuses: [rsb_jira_status[:ready]]
    )

    if $git_flow
      rsb_git_checkout('develop')
      rsb_git_pull
      rsb_start_release_branch(
        name: $release_branch_name
      )
    else
      rsb_git_checkout(git_build_branch)
      rsb_git_pull
    end

    if is_release
      precheck_if_needed
      check_no_debug_code_if_needed
    end

    rsb_run_tests_if_needed
    rsb_stash_save_tests_output
    rsb_stash_pop_tests_output
    rsb_commit_tests_output

    slack_release_notes = rsb_slack_release_notes(ready_tickets)
    raw_release_notes = rsb_jira_tickets_description(ready_tickets)
    
    should_move_jira_tickets = true
    configurations.each do |configuration_name|
      configuration = upload_configurations[configuration_name]

      if !options[:skip_match] && ENV['MATCH_ENABLED'] != 'false'
        rsb_update_provisioning_profiles(
          type: configuration[:profile_type],
          skip_match_validation: options[:skip_match_validation]
        )
      end

      rsb_build_and_archive(
        configuration: configuration[:build_configuration],
        type: configuration[:export_type]
      )

      configuration[:lane].call(
        notes: raw_release_notes
      )

      if should_move_jira_tickets
        rsb_move_jira_tickets(
          tickets: ready_tickets,
          transition: rsb_jira_transition[:test_build]
        )
        should_move_jira_tickets = false
      end

      rsb_post_to_slack_channel(
        configuration: configuration[:build_configuration],
        release_notes: slack_release_notes,
        destination: configuration[:name]
      )
    end

    if is_ci?
      reset_git_repo(
        force: true, 
        exclude: ['Carthage/Build', 'Carthage/Checkouts']
      )
    end

    changelog_release_notes = rsb_changelog_release_notes(ready_tickets)
    rsb_update_changelog(
      release_notes: changelog_release_notes, 
      commit_changes: true
    )

    rsb_update_build_number
    rsb_commit_build_number_changes

    if $git_flow
      rsb_end_release_branch(
        name: $release_branch_name
      )
    end

    rsb_add_git_tag($release_branch_name)
    rsb_git_push(tags: true)
  end

  lane :rsb_add_devices do
    file_path = prompt(
      text: 'Enter the file path: '
    )

    register_devices(
      devices_file: file_path
    )
  end

  lane :rsb_changelog do |options|
    ready_tickets = rsb_search_jira_tickets(
      statuses: [rsb_jira_status[:ready]]
    )
    changelog_release_notes = rsb_changelog_release_notes(ready_tickets)
    rsb_update_changelog(
      release_notes: changelog_release_notes, 
      commit_changes: false
    )
  end

  ### PRIVATE LANES

  private_lane :rsb_build_and_archive do |options|
    configuration = options[:configuration]
    type = options[:type]
    rsb_update_extensions_build_and_version_numbers_according_to_main_app

    if configuration == ENV['CONFIGURATION_ADHOC']
      gym(    
        configuration: configuration,
        include_bitcode: false,
        export_options: {
            uploadBitcode: false,
            uploadSymbols: true,
            compileBitcode: false,
            method: type
        }
      )
    else
      gym(configuration: configuration, export_options: {
        method: type
      })
    end
  end

  private_lane :rsb_send_to_crashlytics do |options|
    groups = [ENV['CRASHLYTICS_GROUP']]
    crashlytics(
      groups: groups,
      notes: options[:notes]
    )
  end

  private_lane :rsb_send_to_firebase do |options|
    groups = ENV['FIREBASE_GROUP']
    firebase_cli_path = ENV['FIREBASE_CLI_PATH']
    firebase_app_distribution(
      ipa_path: Actions.lane_context[SharedValues::IPA_OUTPUT_PATH],
      app: firebase_app_id,
      groups: groups,
      release_notes: options[:notes],
      firebase_cli_path: firebase_cli_path
    )
  end

  private_lane :rsb_send_to_testflight do |options|
    pilot(
      ipa: Actions.lane_context[SharedValues::IPA_OUTPUT_PATH],
      skip_submission: true,
      skip_waiting_for_build_processing: true
    )
  end

  private_lane :rsb_dummy_upload do |options|
    # dummy
  end

end

module SharedValues
  FFREEZING = :FFREEZING  
end

def ffreezing? 
  Actions.lane_context[SharedValues::FFREEZING] == true
end

def precheck_if_needed
  precheck(app_identifier: ENV['BUNDLE_ID']) if ENV['NEED_PRECHECK'] == 'true'
end

def check_no_debug_code_if_needed    
  ensure_no_debug_code(text: 'TODO|FIXME', path: 'Classes/', extension: '.swift') if ENV['CHECK_DEBUG_CODE'] == 'true'
end

def upload_configurations
  { 
    :fabric => { 
      name: "Fabric",
      build_configuration: ENV['CONFIGURATION_ADHOC'],
      profile_type: :adhoc,
      lane: runner.lanes[:ios][:rsb_send_to_crashlytics],
      export_type: 'ad-hoc'
    },
    :firebase => {
      name: "Firebase",
      build_configuration: ENV['CONFIGURATION_ADHOC'],
      profile_type: :adhoc,
      lane: runner.lanes[:ios][:rsb_send_to_firebase],
      export_type: 'ad-hoc'
    },
    :testflight => {
      name: "Testflight",
      build_configuration: ENV['CONFIGURATION_APPSTORE'],
      profile_type: :appstore,
      lane: runner.lanes[:ios][:rsb_send_to_testflight],
      export_type: 'app-store'
    },
    :dummy => {
      name: "Dummy",
      build_configuration: ENV['CONFIGURATION_APPSTORE'],
      profile_type: :appstore,
      lane: runner.lanes[:ios][:rsb_dummy_upload],
      export_type: 'app-store'
    }
  }
end
