require 'base64'
require 'openssl'
require 'spaceship'

# Get type of the certificate
def rsb_get_certificate_type(file, passphrase)
  contents = File.open(file).read
  p12 = OpenSSL::PKCS12.new(contents, passphrase)
  if p12.certificate.subject.to_s().include? "Distribution"
    return :distribution
  else
    return :development
  end
end

# Get subject value of the certificate
def rsb_get_certificate_subject_value(file, passphrase, key)
  contents = File.open(file).read
  p12 = OpenSSL::PKCS12.new(contents, passphrase)
  values = p12.certificate.subject.to_a
  return values.select { |tuple| tuple[0] == key}.first[1]
end

# Get expiration time of the certificate
def rsb_get_certificate_expiration_time(file, passphrase)
  contents = File.open(file).read
  p12 = OpenSSL::PKCS12.new(contents, passphrase)
  return p12.certificate.not_after
end

# Get cer data form p12
def rsb_get_x509_data(file, passphrase)
    contents = File.open(file).read
    p12 = OpenSSL::PKCS12.new(contents, passphrase)
    return p12.certificate.to_pem
end

# Get remote id of the certificate
def rsb_get_certificate_remote_identifier(expiration, team)
  Spaceship.login
  Spaceship.client.team_id = team
  return Spaceship.certificate.all.select { |object| object.expires == expiration }.first.id
end

# Copy p12 / cer pair to a match storage
def rsb_copy_certificate(file, passphrase, storage, type)
  expiration = rsb_get_certificate_expiration_time(file, passphrase)
  team = rsb_get_certificate_subject_value(file, passphrase, "OU")
  remote_id = rsb_get_certificate_remote_identifier(expiration, team)
  pem_data = rsb_get_x509_data(file, passphrase)

  destination = "#{storage}/certs/#{type}/#{remote_id}.p12"
  FileUtils.mkdir_p(File.dirname(destination))
  FileUtils.cp(file, destination)
  
  File.open("#{storage}/certs/#{type}/#{remote_id}.cer", "wb") { |file| 
    file.print pem_data
  }
end