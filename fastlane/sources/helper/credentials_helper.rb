require 'security'

def rsb_credentials(account_name, server)
  credentials = Security::InternetPassword.find(server: server)
  if credentials
    email = credentials.attributes['acct']
    token = credentials.password
  else
    puts '-------------------------------------------------------------------------------------'.green
    puts "Please provide your #{account_name} account credentials".green
    puts 'The login information you enter will be stored in your macOS Keychain'.green
    puts '-------------------------------------------------------------------------------------'.green

    email = ask('Email: ') while email == nil or email.empty?
    token = ask("Token for #{email} (available at https://id.atlassian.com/manage/api-tokens): ") { |q| q.echo = '*' } while token == nil or token.empty?

    Security::InternetPassword.add(server, email, token)
  end
  {
    email: email,
    token: token
  }
end