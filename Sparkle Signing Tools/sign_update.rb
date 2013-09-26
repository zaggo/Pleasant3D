#!/usr/bin/ruby
if ARGV.length < 2
  puts "Usage: ruby sign_update.rb update_archive private_key"
  exit
end

puts `openssl dgst -sha1 -binary < "#{ARGV[0]}" | openssl dgst -dss1 -sign "#{ARGV[1]}" | openssl enc -base64`

puts "File size : " << File.stat("#{ARGV[0]}").size.to_s