require 'chronic'

date = Chronic.parse ARGV[0]

unless date
  puts "Unable to parse `#{ARGV[0]}`"
  exit
end

now = Time.now.to_i

puts date.to_i
puts now


list = Dir.glob("jpg/*")

puts list
