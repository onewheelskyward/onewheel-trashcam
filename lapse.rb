require 'chronic'

date = Chronic.parse ARGV[0]

unless date
  puts "Unable to parse `#{ARGV[0]}`"
  exit
end

puts date
puts date.to_i
puts Time.now.to_i
