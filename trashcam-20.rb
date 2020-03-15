require 'rest-client'
require 'yaml'

class Trashcam
  @user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.132 Safari/537.36"
  @base_path
  @token
  @segment_uri
  @seg_file
  @timestamp
  @config

  attr_reader :token, :config

  def initialize
    @base_path = __dir__
    begin
      @config = YAML.load(File.read("#{@base_path}/config.yml"))
    rescue StandardError => e
      puts "Error reading config file. #{e}"
      exit
    end

    puts @config.inspect

    begin
      @token = File.read("#{@base_path}/token.txt")
    rescue StandardError
      @token = ''
    end

    puts "Starting with token #{@token}"
  end

  def get_token
    puts 'Grabbing token'
    resp = RestClient.get @config['page_url'], user_agent:  @user_agent

    # Read the iframe source
    x = resp.match /source: '(.*)'/
    m3u8 = x[1]

    url_match = m3u8.match /(.*)\/playlist/
    puts "url_match: #{url_match[1]}"
    @segment_uri = url_match[1]

    token_match = m3u8.match /token=(.*)/
    @token = token_match[1]
    puts "Returning token: #{@token}"
    File.open("#{@base_path}/token.txt", 'w') { |f| f.write(@token) }
  end

  def get_segment_from_m3u8
    unless @segment_uri
      get_token
    end

    @timestamp = time = Time.now.to_i

    m3u8 = "#{@segment_uri}/playlist.m3u8?token=#{@token}"

    puts "Grabbing #{m3u8}"
    resp = RestClient.get m3u8, user_agent: @user_agent
    segment = ''

    resp.split(/\n/).each do |l|
      segment = l  if l.match /segment/
    end

    @segment = segment
    puts "Segment file: #{@segment}"
  end

  def get_segment_file
    segfile_uri = "#{@segment_uri}/#{@segment}"
    puts "Grabbing #{segfile_uri}"

    resp = RestClient.get segfile_uri, user_agent: @user_agent

    seg_mp4 = @segment.sub /.ts/, '.mp4'

    @seg_file = "#{@base_path}/mp4/#{@timestamp}-#{seg_mp4}"
    puts "Writing: #{@seg_file}"
    File.open(@seg_file, 'wb') {|file|  file.write resp.body}
  end

  def write_image
    frame_count_cmd = `ffmpeg -i #{@seg_file} -map 0:v:0 -c copy -f null - 2>&1 | grep 'frame='`
    frame_count_md = frame_count_cmd.match /frame=\s+(\d+)/
    frame_count = frame_count_md[1].to_i

    first = 1
    middle = frame_count / 2
    last = frame_count

    ext = '.jpg'

    puts "Frame count: #{frame_count}"
    puts "b/m/e: #{first}/#{middle}/#{last}"

    img_file_base = "#{@base_path}/jpg/#{@timestamp}"
    puts "Writing #{img_file_base}-#{first}#{ext}"

    system("ffmpeg -nostats -loglevel 0 -i #{@seg_file} -frames:v #{first} #{img_file_base}-#{first}#{ext}")
    system("ffmpeg -nostats -loglevel 0 -i #{@seg_file} -frames:v #{middle} #{img_file_base}-#{middle}#{ext}")
    system("ffmpeg -nostats -loglevel 0 -i #{@seg_file} -frames:v #{last} #{img_file_base}-#{last}#{ext}")

    file_size = File.size("#{img_file_base}-#{first}#{ext}")

    puts "jpg file size: #{file_size}"
  end
end


tcam = Trashcam.new

# if tcam.token == ''
#   tcam.get_token
# end

while true
  begin
    tcam.get_segment_from_m3u8
  rescue RestClient::Unauthorized
    puts "Bad token found"
    tcam.get_token
    next
  end

  tcam.get_segment_file
  tcam.write_image
  puts "Sleeping for #{tcam.config['delay']} seconds..."
  sleep(tcam.config['delay'])
end
