# load 'map_update.rb'
require 'json'
require 'nokogiri'
require 'sanitize'
require 'optparse'
require 'erb'
require 'yaml'
require 'carmen'
require 'geocoder'
require 'redis'
require 'google_places'
include Carmen

# how to use!
# cd emergencyindex.com/utilz
# GOOGLE_PLACES_API_KEY='someapikey' ruby map_update.rb -g ../_projects/2012 -c True
# -g flag indicates geocoding
# -c flag causes each project's coordinates to be cached locally
module MapUpdate

  @options = {}
  @project_template = File.read 'project_template.erb'
  @pinwheel = %w{ | \/ - \\ }

  def self.init

    @options[:out_dir] = Dir.pwd
    @options[:pageoffset] = 2

    # options to parse for script call
    optparse = OptionParser.new do |opts|
      opts.banner = "Usage: #{__FILE__} [options]"
      opts.on("-g", "--geocode DIRECTORY", "Generate Longitude and Latitude automatically") { |v| @options[:geocode_projects] = v }
      opts.on("-c", "--cache CACHE", "Write 'True' to activate Cache") { |v| @options[:cache_it] = v }
    end.parse!

    # depending on calls made, call the functions
    if @options[:geocode_projects]
      geocode_projects
    else
      p "nothing to do!"
      puts optparse
      exit
    end
  end

  def self.geocode_projects
    # ex:  ruby map_update.rb

    @options[:geocode_projects] = "#{@options[:geocode_projects]}/" unless @options[:geocode_projects][-1] == '/'
    p "Looking for MD files in #{@options[:geocode_projects]}"
    all_filez = Dir.glob("#{@options[:geocode_projects]}**/*.md").select{ |e| File.file? e }
    len = all_filez.length
    idx = 0
    all_filez.each do |file|
      status_update(len:len, idx:idx)
      project = read_md file: file

      # find the place tag
      if project[:yml]["place"] != ""
        theplace = project[:yml]["place"]
      else
        theplace = ""
      end

      pCrds = call_api(theplace)

      # find the home tag
      if project[:yml]["home"] != ""
        thehome = project[:yml]["home"]
      else
        thehome = ""
      end

      hCrds = call_api(thehome)

      # add mapping info
      project[:yml]["Pcrds"] = pCrds
      project[:yml]["Hcrds"] = hCrds

      File.open(file,"w"){|f| f.write("#{project[:yml].to_yaml}---\n\n#{project[:description]}")}
      idx += 1
    end

    p "done! #{len} filez"
  end

private
  def self.status_update(len:nil, idx:nil)
    print "\b" * 16, "Progress: #{(idx.to_f / len * 100).to_i}% ", @pinwheel.rotate!.first
  end

  def self.read_md file: ''
    f = File.read(file, encoding: 'UTF-8')
    contents = f.match(/^---(.*)---(.*)/m) #/m for multiline mode
    raise "ERROR in read_md, contents.length > 2! #{contents.length}" if contents.length > 3
    yml = YAML.load(contents[1])
    description = contents[2]
    {yml: yml, description: description}
  end

  def self.call_api(place_to_call)

    redis = Redis.new(host: "localhost")

    # rest for less than a second so the requests don't come too fast
    # for google, needs to be less than 50 requests per second
    sleep(0.25)

    @client = GooglePlaces::Client.new(ENV["GOOGLE_PLACES_API_KEY"])

    if redis.get(place_to_call) != nil
      p "cached"
      coords = redis.get(place_to_call).delete('[]').split
      location = coords
    else
      if place_to_call != ""
        api_call = @client.spots_by_query(place_to_call)
        location = nil
      else
        p "something wrong with: #{place_to_call}"
        p "try something else?"
        new_add = gets.chomp
        api_call = @client.spots_by_query(new_add)
        location = nil
      end
    end

    while location == nil
      # if there's an error in the look up
      while api_call == []
        p place_to_call
        p "ERROR - can't geocode this location, try another address?"
        new_add = gets.chomp
        api_call = @client.spots_by_query(new_add)
      end

      # if there is more than one location
      if api_call.count > 1
        p place_to_call
        p "choose from the following by entering 'y' or 'n' (or to enter another address, 'a'): "
        for n in api_call
          begin
            puts "is this it?: #{n.name.to_s} at #{n.formatted_address.to_s}"
          rescue
            puts "is this it?: #{n}"
          end
          choice = gets.chomp
          if choice == "y"
            location = n
            break
          end
          if choice == "a"
            api_call = []
            break
          end
        end
      else
        location = api_call[0]
      end
    end

    #p location
    if redis.get(place_to_call) != nil
      crds = coords
    else
      lat = location.lat
      long = location.lng
      crds = [lat, long]
    end

    if @options[:cache_it] and redis.get(place_to_call) == nil
      redis.set(place_to_call, crds)
      p "cached it!"
    end

    return crds

  end

end

MapUpdate.init
