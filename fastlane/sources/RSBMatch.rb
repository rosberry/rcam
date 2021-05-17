require 'match'

desc 'Create all certificates and profiles via match'
lane :rsb_match_init do |options|
  types = %w[appstore development adhoc]
  types.each do |type|
    rsb_match_for_type(
      app_identifier: ENV['BUNDLE_ID'],
      type: type,
      clone_directly: false
    )

    bundle_id_extensions = ENV['BUNDLE_ID_EXTENSIONS']
    next unless bundle_id_extensions
    bundle_id_extensions.split(', ').each do |bundle_id_extension|
      rsb_match_for_type(
        app_identifier: bundle_id_extension,
        type: type,
        clone_directly: false
      )
    end
  end
end

desc 'Download all certificates and profiles via match'
lane :rsb_match do |options|
  types = %w[appstore development adhoc]
  types.each do |type|
    rsb_match_for_type(
      app_identifier: ENV['BUNDLE_ID'],
      type: type,
      force: false,
      readonly: true,
      clone_directly: true,
      skip_match_validation: options[:skip_match_validation]
    )

    bundle_id_extensions = ENV['BUNDLE_ID_EXTENSIONS']
    next unless bundle_id_extensions
    bundle_id_extensions.split(', ').each do |bundle_id_extension|
      rsb_match_for_type(
        app_identifier: bundle_id_extension,
        type: type,
        force: false,
        readonly: true,
        clone_directly: true
      )
    end
  end
end

desc 'Remove all certificates and profiles'
lane :rsb_match_nuke do
  url = ENV['MATCH_GIT_URL']
  branch = ENV['MATCH_GIT_BRANCH']
  delete_remote_branch(url, branch)
end

desc 'Use existing certificates or profiles'
lane :rsb_match_use do |options|
  Actions.verify_gem!('nokogiri')
  Actions.verify_gem!('openssl')

  glob = options[:glob].blank? ? "*" : options[:glob]
  profiles = {
    :development => {},
    :adhoc => {},
    :appstore => {}
  }
  certificates = {}

  full_path = File.expand_path(glob)
  Dir.glob(full_path) { |file|
    if File.directory?(file)
      next
    end

    if File.extname(file) == ".mobileprovision"
      bundle = rsb_get_provisioning_profile_bundle_id(file)
      type = rsb_get_provisioning_profile_type(file)
      profiles[type][bundle] = file
    end

    if File.extname(file) == ".p12"
      type = rsb_get_certificate_type(file, options[:passphrase])
      certificates[type] = file
    end
  }

  print "Using:\n#{certificates}\n#{profiles}\n"

  url = ENV['MATCH_GIT_URL']
  branch = ENV['MATCH_GIT_BRANCH']

  storage = Match::Storage.for_mode("git", { git_url: url, shallow_clone: false, git_branch: branch, clone_branch_directly: false})
  storage.download

  encryption = Match::Encryption.for_storage_mode("git", { git_url: url, working_directory: storage.working_directory})
  encryption.decrypt_files

  target_directory = storage.working_directory

  development_certificate = certificates[:development]
  if development_certificate
    rsb_copy_certificate(development_certificate, options[:passphrase], target_directory, "development")
  end

  distribution_certificate = certificates[:distribution]
  if distribution_certificate
    rsb_copy_certificate(distribution_certificate, options[:passphrase], target_directory, "distribution")
  end

  for pair in profiles[:development]
    rsb_copy_profile(pair[1], pair[0], target_directory, "Development")
  end

  for pair in profiles[:adhoc]
    rsb_copy_profile(pair[1], pair[0], target_directory, "AdHoc")
  end

  for pair in profiles[:appstore]
    rsb_copy_profile(pair[1], pair[0], target_directory, "AppStore")
  end

  print "Saved to: #{target_directory}\n"

  encryption.encrypt_files
  files_to_commit = Dir[File.join(storage.working_directory, "**", "*.{cer,p12,mobileprovision}")]
  storage.save_changes!(files_to_commit: files_to_commit)
end
