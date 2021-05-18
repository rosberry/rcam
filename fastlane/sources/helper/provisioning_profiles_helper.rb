require 'nokogiri'

# Updating provisioning profiles.
private_lane :rsb_update_provisioning_profiles do |options|
  rsb_update_provisioning_profiles_for_app_identifier(
    app_identifier: ENV['BUNDLE_ID'],
    type: options[:type],
    skip_validation: options[:skip_match_validation]
  )

  bundle_id_extensions = ENV['BUNDLE_ID_EXTENSIONS']
  next unless bundle_id_extensions

  bundle_id_extensions.split(', ').each do |bundle_id_extension|
    rsb_update_provisioning_profiles_for_app_identifier(
      app_identifier: bundle_id_extension,
      type: options[:type],
      skip_validation: options[:skip_validation]
    )
  end
end

# Update provisioning profile for concrete bundle id.
def rsb_update_provisioning_profiles_for_app_identifier(options)
  app_identifier = options[:app_identifier]
  type = options[:type]
  match_type = type == :adhoc ? 'adhoc' : 'appstore'
  skip_validation = !!options[:skip_validation]

  rsb_match_for_type(
    app_identifier: app_identifier,
    type: match_type,
    force: true,
    readonly: false,
    clone_directly: true,
    skip_validation: skip_validation 
  )
end

# Get type of the provisioning profile
def rsb_get_provisioning_profile_type(file)
    contents = File.open(file).read
    profile_data = contents.slice(contents.index('<?'), contents.length)
    document = Nokogiri.XML(profile_data)
    if document.xpath('//key[text()="ProvisionedDevices"]')[0]
      certificate = document.xpath('//key[text()="DeveloperCertificates"]')[0].next_element.text
      decoded_certificate = Base64.decode64(certificate)
      if decoded_certificate.include? "Distribution"
        return :adhoc
      else
        return :development
      end
    end

    return :appstore
end

def rsb_get_provisioning_profile_bundle_id(file)
    contents = File.open(file).read
    profile_data = contents.slice(contents.index('<?'), contents.length)
    document = Nokogiri.XML(profile_data)
    return document.xpath('//key[text()="application-identifier"]')[0].next_element.text.partition('.').last
end

# Copy provisioning profile to a match storage
def rsb_copy_profile(file, bundle_id, storage, type)
  destination = "#{storage}/profiles/#{type.downcase}/#{type}_#{bundle_id}.mobileprovision"
  FileUtils.mkdir_p(File.dirname(destination))
  FileUtils.cp(file, destination)
end
