# load 'geocode_test.rb'
require 'json'
require 'nokogiri'
require 'sanitize'
require 'optparse'
require 'erb'
require 'yaml'
require 'carmen'
require 'geocoder'
require 'redis'
include Carmen

# This class allows you to configure how Geocoder should treat errors that occur when
# the cache is not available.
# Configure it like this
# config/initializers/geocoder.rb
# Geocoder.configure(
#  :cache => Geocoder::CacheBypass.new(Redis.new)
# )
#
# Depending on the value of @bypass this will either
# raise the exception (true) or swallow it and pretend the cache did not return a hit (false)
#
class Geocoder::CacheBypass
  def initialize(target, bypass = true)
    @target = target
    @bypass = bypass
  end


  def [](key)
    with_bypass { @target[key] }
  end

  def []=(key, value)
    with_bypass(value) { @target[key] = value }
  end

  def keys
    with_bypass([]) { @target.keys }
  end

  def del(key)
    with_bypass { @target.del(key) }
  end

  private

  def with_bypass(return_value_if_exception = nil, &block)
    begin
      yield
    rescue
      if @bypass
        return_value_if_exception
      else
        raise # reraise original exception
      end
    end
  end
end

module GeocodeTester

  @options = {}
  #@project_template = File.read 'project_template.erb'
  @pinwheel = %w{ | \/ - \\ }

  def self.init

    #@options[:out_dir] = Dir.pwd
    #@options[:pageoffset] = 2

    Geocoder.configure(
      # geocoding service request timeout, in seconds (default 3):
      timeout: 15,
      # NOTE: there is a limit on geocoding requests, 2,500

      #lookup: :nominatim,
      #lookup: :location_iq,
      lookup: :google,

      # api for locationiq
      #api_key: "cc42d410fdedaf",
      api_key: 'AIzaSyCGucx-_XZJLn-Gd1cHme18vk6osePAE3w',

      # possible method for batch geocoding:
      # rake geocode:all CLASS=YourModel SLEEP=0.25 BATCH=100 LIMIT=1000

      #always_raise: [Timeout::Error],
      always_raise: :all,

      # caching (see https://github.com/alexreisner/geocoder)
      #cache: Redis.new
      cache: Geocoder::CacheBypass.new(Redis.new)
      #cache_prefix: "..."
    )

    # options to parse for script call
    optparse = OptionParser.new do |opts|
      opts.banner = "Usage: #{__FILE__} [options]"
      opts.on('-p', '--place PLACE', 'Input place name') { |v| @options[:place_name] = v }
      opts.on('-x', '--place_xml PLACE_XML', 'Input place name') { |v| @options[:place_name_xml] = v }
      opts.on('-u', '--unedited UNEDITED', 'Input unedited place name') { |v| @options[:unedited_name] = v }
      opts.on('-c', '--cache CACHE', 'Input place name with cache intention') { |v| @options[:cache_name] = v }
    end.parse!

    # error raisers
    #unless @options[:tidy] or @options[:geocode_projects]
    #  raise "ERROR! --place name not specified" if @options[:place_name].nil?
    #end

    # depending on calls made, call the functions
    if @options[:place_name]
      geocode_projects
    elsif @options[:unedited_name]
      geocode_unedited
    elsif @options[:cache_name]
      geocode_with_cache
    elsif @options[:place_name_xml]
      geocode_projects_xml
    else
      p "nothing to do!"
      puts optparse
      exit
    end
  end

  def self.geocode_projects

    theplace = @options[:place_name]

    # rest for a second so the requests don't come too fast
    # for location iq, needs to be less than 2 requests per second
    # for google, needs to be less than 50 requests per second
    sleep(0.25)
    api_call = Geocoder.search(theplace)
    location = nil

    #p api_call.to_s+" "+api_call.count.to_s
    #p api_call.count
    p api_call

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
          puts "is this it?: #{n.data["display_name"].to_s}"
          choice = gets.chomp
          if choice == "y"
            location = n
            break
          end
        end
        p "ERROR - can't geocode this location, try another address?"
        new_add = gets.chomp
        api_call = Geocoder.search(new_add)
      else
        location = api_call[0]
      end
    end

    p location

    lat = location.data["geometry"]["location"]["lat"]
    long = location.data["geometry"]["location"]["lng"]
    p lat.to_s+" "+long.to_s

  end

  def self.geocode_unedited

    theplace = @options[:unedited_name]

    # convert place tag to longitude and latitude
    p theplace

    begin
      location = Geocoder.search(theplace)
      raise "some kind of error"
    rescue Timeout::Error
      p "there was an error"
      p location
    rescue SocketError
      p "THERE WAS AN ERROR"
    rescue StandardError => e
      puts e.message
      puts e.backtrace.inspect
    end

    if location != []
      long = location[0].longitude
      lat = location[0].latitude
      p lat.to_s+" "+long.to_s
    else
      p "ERROR - location '"+theplace+"' doesn't exist"
    end
  end


  def self.geocode_with_cache

    theplace = @options[:cache_name]

    # convert place tag to longitude and latitude
    p theplace

    begin
      location = Geocoder.search(theplace)
    rescue Timeout::Error
      p "there was an error"
      p location
    end

    if location != []
      long = location[0].longitude
      lat = location[0].latitude
      p lat.to_s+" "+long.to_s
      #store#[]=(theplace, location)
      #@store.set(theplace, location)

    else
      p "ERROR - location '"+theplace+"' doesn't exist"
    end
  end

  def self.geocode_projects_xml
    # for locationIQ api calls

    theplace = @options[:place_name_xml]

    # convert place tag to longitude and latitude
    parts = theplace.split(/\s*,\s*/)

    p theplace
    api_call = Geocoder.search(theplace)
    #location = api_call
    #p location

    # if there's an error in the look up
    #p api_call[0].data["error"].to_s
    while api_call[0].data["error"].to_s == "Unable to geocode"
      p "ERROR - can't geocode this location, try another address?"
      new_add = gets.chomp
      api_call = Geocoder.search(new_add)
    end

    # if there is more than one location
    #p api_call.count
    if api_call.count > 1
      p "choose from the following by entering 'y' or 'n': "
      for n in api_call
        puts "is this it?: #{n.data["display_name"].to_s}"
        choice = gets.chomp
        if choice == "y"
          location = n
          break
        end
      end
    else
      location = api_call[0]
    end

    #p location
    lat = location.data["lat"]
    long = location.data["lon"]
    p lat.to_s+" "+long.to_s

  end

end

GeocodeTester.init
