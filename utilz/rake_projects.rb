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

module GeocodeRaker

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

      # possible method for batch geocoding:
      # rake geocode:all CLASS=YourModel SLEEP=0.25 BATCH=100 LIMIT=1000

      # caching (see https://github.com/alexreisner/geocoder)
      # this didn't work... but it would be nice to use a Cache instead of constantly querying the API
      cache: Redis.new
      # cache_prefix: "..."
    )

    # options to parse for script call
    optparse = OptionParser.new do |opts|
      opts.banner = "Usage: #{__FILE__} [options]"
      opts.on('-p', '--place PLACE', 'Input place name') { |v| @options[:place_name] = v }
      opts.on('-u', '--unedited UNEDITED', 'Input unedited place name') { |v| @options[:unedited_name] = v }
      opts.on('-r', '--rake RAKE', 'Input directory to rake') { |v| @options[:in_rake_dir] = v }
    #  opts.on('-i', '--infile FILE', 'Input file name') { |v| @options[:in_file] = v }
    #  opts.on('-d', '--out DIRECTORY', 'Output directory') { |v| @options[:out_dir] = v }
    #  opts.on('-v', '--volume VOLUME', 'Volume Name') { |v| @options[:vol] = v }
    #  opts.on('-o', '--pageoffset OFFSET', 'Page of first project') { |v| @options[:pageoffset] = v }
    #  opts.on("-p", "--projects", "Scrape Projects") { |v| @options[:projects] = v }
    #  opts.on("-t", "--terms", "Scrape Terms") { |v| @options[:terms] = v }
    #  opts.on("-u", "--termstxt", "Scrape Terms Text") { |v| @options[:terms_txt] = v }
    #  opts.on("-T", "--writeterms", "Write Terms to MD") { |v| @options[:writeterms] = v }
    #  opts.on("-I", "--termsindex", "Build Terms Index MD") { |v| @options[:termsindex] = v }
    #  opts.on("-x", "--tidy DIRECTORY", "Tidy project YAML") { |v| @options[:tidy] = v }
    #  opts.on("-X", "--drytidy", "DRY RUN Tidy project YAML (no files modified)") { |v| @options[:drytidy] = v }
    #  opts.on("-g", "--geocode DIRECTORY", "Generate Longitude and Latitude automatically") { |v| @options[:geocode_projects] = v }
    #  opts.on("-G", "--drygeo", "DRY RUN Generate Longitude and Latitude automatically") { |v| @options[:drygeo] = v }
    end.parse!

    # error raisers
    #unless @options[:tidy] or @options[:geocode_projects]
    #  raise "ERROR! --place name not specified" if @options[:place_name].nil?
    #  raise "ERROR! --input file not specified" if @options[:in_file].nil?
    #  raise "ERROR! --infile does not exist" unless File.exist?(@options[:in_file])
    #  raise "ERROR! --outdir is not a directory" unless File.directory?(@options[:out_dir])
    #end

    # depending on calls made, call the functions
    #if @options[:projects]
    #  scrape_projects_html
    #elsif @options[:terms]
    #  scrape_terms_html
    #elsif @options[:terms_txt]
    #  scrape_terms_txt
    #elsif @options[:writeterms]
    #  write_terms_to_md
    #elsif @options[:termsindex]
    #  build_terms_index
    #elsif @options[:tidy]
    #  tidy_project_yml
    #elsif @options[:geocode_projects]
    #  geocode_projects
    if @options[:place_name]
      geocode_projects
    elsif @options[:unedited_name]
      geocode_unedited
    elsif @options[:in_rake_dir]
      rake_dir
    else
      p "nothing to do!"
      puts optparse
      exit
    end
  end

  def self.geocode_projects

    theplace = @options[:place_name]

    # convert place tag to longitude and latitude
    parts = theplace.split(/\s*,\s*/)

    p theplace
    location = Geocoder.search(theplace)

    if location == []
      theplace = parts.last(2).join(', ')
      p "nil, changed to: "+theplace
      location = Geocoder.search(theplace)
    end

    if location == []
      theplace = parts.last(1).join(', ')
      p "guessing it's here: "+theplace
      location = Geocoder.search(theplace)
    end

    if location != []
      long = location[0].longitude
      lat = location[0].latitude
      p long.to_s+" "+lat.to_s
    else
      p "ERROR - location '"+theplace+"' doesn't exist"
    end

    #p "long: "+location[0].longitude.to_s
    #p "lat: "+location[0].latitude.to_s

  end

  def self.geocode_unedited

    theplace = @options[:unedited_name]

    # convert place tag to longitude and latitude
    #parts = theplace.split(/\s*,\s*/)
    #if parts.length() > 2
    #  p theplace
    #else
    #  theplace = parts.last(2).join(', ')
    p theplace

    location = Geocoder.search(theplace)
    if location != []
      long = location[0].longitude
      lat = location[0].latitude
      p long.to_s+" "+lat.to_s
    end

    #p "long: "+location[0].longitude.to_s
    #p "lat: "+location[0].latitude.to_s

  end


  def self.rake_dir

    dir_to_rake = @options[:in_rake_dir]
    #theplace = @options[:place_name]

    # convert place tag to longitude and latitude
    parts = theplace.split(/\s*,\s*/)

    p theplace
    location = Geocoder.search(theplace)

    if location == []
      theplace = parts.last(2).join(', ')
      p "nil, changed to: "+theplace
      location = Geocoder.search(theplace)
    end

    if location == []
      theplace = parts.last(1).join(', ')
      p "guessing it's here: "+theplace
      location = Geocoder.search(theplace)
    end

    if location != []
      long = location[0].longitude
      lat = location[0].latitude
      p long.to_s+" "+lat.to_s
    else
      p "ERROR - location '"+theplace+"' doesn't exist"
    end

    #p "long: "+location[0].longitude.to_s
    #p "lat: "+location[0].latitude.to_s

  end

end

GeocodeRaker.init
