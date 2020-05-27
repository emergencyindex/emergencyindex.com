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
# API_KEY='someapikey' ruby map_update.rb -g ../_projects/2012 -c True
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

    # error raisers
    unless @options[:tidy] or @options[:geocode_projects]
      raise "ERROR! --input file not specified" if @options[:in_file].nil?
      raise "ERROR! --infile does not exist" unless File.exist?(@options[:in_file])
      raise "ERROR! --outdir is not a directory" unless File.directory?(@options[:out_dir])
    end

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

      redis = Redis.new(host: "localhost")

      # rest for less than a second so the requests don't come too fast
      # for google, needs to be less than 50 requests per second
      sleep(0.25)

      @client = GooglePlaces::Client.new(ENV["API_KEY"])

      if redis.get(theplace) != nil
        p "cached"
        coords = redis.get(theplace).delete('[]').split
        location = coords
      else
        if theplace != ""
          api_call = @client.spots_by_query(theplace)
          location = nil
        else
          p "something wrong with: #{theplace}"
          p "try something else?"
          new_add = gets.chomp
          api_call = @client.spots_by_query(new_add)
        end
      end

      while location == nil
        # if there's an error in the look up
        while api_call == []
          p theplace
          p "ERROR - can't geocode this location, try another address?"
          new_add = gets.chomp
          api_call = @client.spots_by_query(new_add)
        end

        # if there is more than one location
        if api_call.count > 1
          p theplace
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
      p "#{lat} #{long}"

      title = project[:yml]["title"]
      year = project[:yml]["volume"].to_s
      pagenums = project[:yml]["pages"].to_s
      link = "/volume/#{year}##{year}-#{pagenums}"

      # project[:yml]["mapping"]["link"] = "/volume/"+year+"#"+year+"-"+project[:yml]["pages"]
      # project[:yml]["mapping"]["longitude"] = location[0].longitude
      # project[:yml]["mapping"]["latitude"] = location[0].latitude

      # add mapping info
      new_map = {"title"=>title, "link"=>link, "place-name"=>theplace, "longitude"=>long, "latitude"=>lat}
      project[:yml]["mapping"] = new_map

      p project[:yml]["mapping"].inspect

      File.open(file,"w"){|f| f.write("#{project[:yml].to_yaml}---\n\n#{project[:description]}")} unless @options[:drygeo]
      idx += 1
    end

    p "done! #{len} filez"
  end

end

MapUpdate.init
