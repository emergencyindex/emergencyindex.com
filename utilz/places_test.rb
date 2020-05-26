# load 'geocode_test.rb'
require 'json'
require 'nokogiri'
require 'sanitize'
require 'optparse'
require 'erb'
require 'yaml'
require 'carmen'
require 'redis'
require 'google_places'
include Carmen

module PlaceTester

  @options = {}
  #@project_template = File.read 'project_template.erb'
  @pinwheel = %w{ | \/ - \\ }

  def self.init
    #@options[:out_dir] = Dir.pwd
    #@options[:pageoffset] = 2

    # options to parse for script call
    optparse = OptionParser.new do |opts|
      opts.banner = "Usage: #{__FILE__} [options]"
      opts.on('-p', '--place PLACE', 'Input place name') { |v| @options[:place_name] = v }
      opts.on('-c', '--place_cache PLACE_CACHE', 'Input place name, it will be cached') { |v| @options[:cache_it] = v }
    end.parse!

    # error raisers
    #unless @options[:tidy] or @options[:geocode_projects]
    #  raise "ERROR! --place name not specified" if @options[:place_name].nil?
    #end

    # depending on calls made, call the functions
    if @options[:place_name]
      find_place
    else
      p "nothing to do!"
      puts optparse
      exit
    end
  end

  def self.find_place

    redis = Redis.new(host: "localhost")

    theplace = @options[:place_name]

    # rest for a second so the requests don't come too fast
    # for location iq, needs to be less than 2 requests per second
    # for google, needs to be less than 50 requests per second
    sleep(0.25)

    @client = GooglePlaces::Client.new("AIzaSyCGucx-_XZJLn-Gd1cHme18vk6osePAE3w")

    if redis.get(theplace) != nil
      p "cached"
      coords = redis.get(theplace).delete('[]').split
      location = coords
    else
      api_call = @client.spots_by_query(theplace)
      location = nil
    end

    #p api_call.to_s+" "+api_call.count.to_s
    #p api_call.count
    #p api_call


    while location == nil
      # if there's an error in the look up
      #p api_call[0].data["error"].to_s
      while api_call == []
        p "ERROR - can't geocode this location, try another address?"
        new_add = gets.chomp
        api_call = Geocoder.search(new_add)
      end

      # if there is more than one location
      #p api_call.count
      if api_call.count > 1
        p "choose from the following by entering 'y' or 'n': "
        for n in api_call
          puts "is this it?: #{n.name.to_s} at #{n.formatted_address.to_s}"
          choice = gets.chomp
          if choice == "y"
            location = n
            break
          end
        end
      else
        location = api_call[0]
      end
    end

    #p location
    if redis.get(theplace) != nil
      lat = coords[0]
      long = coords[1]
    else
      lat = location.lat
      long = location.lng
    end
    if @options[:cache_it] and redis.get(theplace) == nil
      redis.set(theplace, [lat, long])
      p "cached it!"
    end
    p lat.to_s+" "+long.to_s

  end

end

PlaceTester.init
