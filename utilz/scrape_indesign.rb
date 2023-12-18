# load 'scrape_indesign.rb'
require 'json'
require 'nokogiri'
require 'sanitize'
require 'optparse'
require 'erb'
require 'yaml'
require 'carmen'
require 'CSV'
require 'fileutils'
include Carmen

# gem install nokogiri sanitize carmen

module ScrapeIndesign

  dir_prefix = Dir.pwd.end_with?('/utilz') ? '' : './utilz/'
  @options = {}
  @project_template = File.read "#{dir_prefix}project_template.erb"
  @pinwheel = %w{ | \/ - \\ }

  def self.init

    @options[:out_dir] = Dir.pwd
    @options[:pageoffset] = 2

    optparse = OptionParser.new do |opts|
      opts.banner = "Usage: #{__FILE__} [options]"
      opts.on('-i', '--infile FILE', 'Input file name') { |v| @options[:in_file] = v }
      opts.on('-d', '--out DIRECTORY', 'Output directory') { |v| @options[:out_dir] = v }
      opts.on('-v', '--volume VOLUME', 'Volume Name') { |v| @options[:vol] = v }
      opts.on('-o', '--pageoffset OFFSET', 'Page of first project') { |v| @options[:pageoffset] = v }
      opts.on("-p", "--projects", "Scrape Projects") { |v| @options[:projects] = v }
      opts.on("-t", "--terms", "Scrape Terms (use --dryrun first)") { |v| @options[:terms] = v }
      opts.on("-I", "--termsindex", "Build Terms Index MD") { |v| @options[:termsindex] = v }
      opts.on("-x", "--tidy DIRECTORY", "Tidy project YAML") { |v| @options[:tidy] = v }
      opts.on("-X", "--drytidy", "DRY RUN Tidy project YAML (no files modified)") { |v| @options[:drytidy] = v }
      opts.on("-Z", "--dryrun", "DRY RUN (no files modified)") { |v| @options[:dryrun] = v }
      opts.on("-V", "--validateimages DIRECTORY", "Validate project image files. Specify project dir with .md files.") { |v| @options[:validate_images] = v }
      opts.on("-I", "--validateimagesdir DIRECTORY", "Validate project images. Specify directory with project images.") { |v| @options[:validate_images_dir] = v }
      opts.on("-P", "--validatemeta", "Validate metadata fields; copies problem .md files to /needs_review/ dir.") { |v| @options[:validate_meta] = v }
      opts.on("-c", "--crossref", "Update projects metadata with submission .csv data.") { |v| @options[:cross_ref] = v }
      opts.on("-r", "--rawjson", "Scrape raw submission json files.") { |v| @options[:raw_json] = v }
      opts.on("-f", "--fixpages", "Fix project pages (and filenames) for md projects") { |v| @options[:fix_project_pages] = v }
      opts.on("-g", "--gentags", "Try to generate project tags metadata") { |v| @options[:gen_tags] = v }
    end.parse!


    unless @options[:tidy] or @options[:validate_images] or @options[:cross_ref] or @options[:validate_meta] or @options[:raw_json] or @options[:fix_project_pages] or @options[:gen_tags]
      raise "ERROR! --input file not specified" if @options[:in_file].nil?
      raise "ERROR! --infile does not exist" unless File.exist?(@options[:in_file])
      raise "ERROR! --outdir is not a directory" unless File.directory?(@options[:out_dir])
    end

    if @options[:projects]
      scrape_projects_html
    elsif @options[:terms]
      scrape_terms_html
    elsif @options[:termsindex]
      build_terms_index
    elsif @options[:tidy]
      tidy_project_yml
    elsif @options[:validate_images]
      validate_images
    elsif @options[:validate_meta]
      validate_meta
    elsif @options[:cross_ref]
      cross_ref
    elsif @options[:raw_json]
      raw_json
    elsif @options[:fix_project_pages]
      fix_project_pages
    elsif @options[:gen_tags]
      gen_tags
    else
      p "nothing to do!"
      puts optparse
      exit
    end
  end

  def self.scrape_projects_html
    # ex: ruby scrape_indesign.rb -i /Users/edwardsharp/Desktop/index8/index8.html -d /Users/edwardsharp/Desktop/index8/out -v 2018 -p

    p "reading #{@options[:in_file]}..."
    Dir.mkdir("#{@options[:out_dir]}/projects") unless Dir.exist?("#{@options[:out_dir]}/projects")
    Dir.mkdir("#{@options[:out_dir]}/projects/#{@options[:vol]}") unless Dir.exist?("#{@options[:out_dir]}/projects/#{@options[:vol]}")

    page = Nokogiri::HTML(open(@options[:in_file]))

    len = page.xpath('/html/body/div').length
    empty_divz_ref = []

    page.xpath('/html/body/div/div').each_with_index do |div, idx|
      empty_divz_ref << [div.line] if (div.content.strip.empty? and div.css('img').length == 0)
    end

    unless empty_divz_ref.empty?
      p "#{empty_divz_ref.length} EMPTY DIVZ AT LINEZ: #{empty_divz_ref.join(", ")}"
    end
    unless len % 4 == 0
      p "found #{page.css('img').length} images. expect #{page.xpath('/html/body/div').length / 4}"
      page.xpath('/html/body/div').each_slice(4) do |div|
        d = div.first
        blockhasimg = d.css('div img') and d.css('div img').length > 0 
        if blockhasimg.empty?
          p "4block does not have an img tag. line: #{div.first.line}"  
        end
      end
    end

    projects = []
    idx = 0
    pageoffset = @options[:pageoffset]

    # raise "\nERROR! wrong number of div elementz! (#{len}) (see empty divz?)" if len % 4 != 0

    page.xpath('/html/body/div').each_slice(4) do |div|
      status_update(len:len, idx:idx)
      project = {}
      project['info'] = {}
      project['info']['layout'] = 'project'
      project['info']['volume'] = @options[:vol]
      project['info']['image'] = ''
      project['info']['photo_credit'] = ''
      project['info']['title'] = ''
      project['info']['first_performed'] = ''
      project['info']['place'] = ''
      project['info']['times_performed'] = ''
      project['info']['contributor'] = ''
      project['info']['collaborators'] = []
      project['info']['home'] = ''
      project['info']['links'] = []
      project['info']['contact'] = ''
      project['info']['footnote'] = ''
      project['info']['tags'] = []
      project['info']['pages'] = ''

      info_description = []

      # for each div, check if there's an image
      div.each do |d|
        if d.css('div img').first and d.css('div img').first['src']
          project['info']['image'] = d.css('div img').first['src'].gsub(/.*\/image\//,'').strip
          next
        end
        #if d.css('.photo-credit').first and d.css('.photo-credit').first.text
        #  project['info']['photo_credit'] = d.css('.photo-credit').first.text.strip
        #  next
        #end
        info_description << d
      end

      # begin to get the tags
      info = info_description[0].css('p').collect do |i|
        i.to_html.gsub('</span>','').gsub(/<span[^>]*/,'<br').split('<br>').collect do |h|
          CGI.unescapeHTML(Sanitize.fragment(h).strip)
        end
      end.flatten.reject(&:empty?)

      project['info']['title']           =  info.shift
      project['info']['first_performed'] =  info.shift

      project['info']['place']           =  info.shift
      project['info']['times_performed'] =  info.shift
      project['info']['contributor']     =  info.shift


      if project['info']['place'] and project['info']['place'].include?('performed ')
        project['info']['contributor'] = project['info']['times_performed']
        project['info']['times_performed'] = project['info']['place']
        project['info']['place'] = ''
      end

      info.reverse_each do |i|
        if i.include?('@') and i.include?('.')
          project['info']['contact'] = "#{project['info']['contact']} #{i.strip}"
          next
        end
        if i.include?('.') #and !i.strip.match(/\s/)
           project['info']['links'] << i.strip
           next
        end
        if i.strip.match(/[[:upper:]]/) and i.strip.match(/\s/) and !i.include?('@')
          check_split = i.split('/').last.split(',').last.strip.gsub(/\(|\)/,'')
          if Country.coded(check_split) or
            Country.named(check_split) or
            Country.coded('US').subregions.coded(check_split) or
            Carmen::Country.coded('US').subregions.named(check_split, :fuzzy => true) or
            check_split.include?('UK') or
            check_split.include?('D.C.')

            project['info']['home'] = i.strip
            next
          end

        end

        project['info']['collaborators'] = i.split(',').map!(&:strip)
      end

      project['info']['contact'] = project['info']['contact'].strip

      # now get the photo credit div

      # helpful to debug finding blank divz use this puts:
      # puts info_description 

      project['info']['photo_credit'] = info_description[1].css('p').first.text.strip rescue 'TODO_PHOTO_CREDIT'

      # now get the description div
      info_description[2].css("span[class*=ITALIC--description-paragraphs-]").each do |i|
        i.name = 'em'
      end
      info_description[2].css("p[class*=inset-text--plain]").each do |i|
        i.name = 'blockquote'
      end
      project['description'] = info_description[2].css('p, blockquote').collect do |i|
        CGI.unescapeHTML( Sanitize.fragment(i.to_html, elements: ['em', 'br', 'blockquote'])
          .gsub('<em>','_')
          .gsub('</em>', '_')
          .gsub('<br>', "\n")
          .gsub('<br />', "\n")
          .gsub('<br/>', "\n")
          .strip
          .gsub('<blockquote>', "> ")
          .gsub('</blockquote>', '') )
      end

      title_sub = false
      c_sub = false
      project['description'].each do |description|
        if description.include? project['info']['title'].strip.upcase and !title_sub
          description.sub!(project['info']['title'].strip.upcase, '')
          title_sub = true
        end
        if description.include? project['info']['contributor'].strip.upcase and !c_sub
          description.sub!(project['info']['contributor'].strip.upcase, '')
          c_sub = true
        end
        break if title_sub and c_sub
      end

      project['description'] = project['description'].reject(&:nil?).reject(&:empty?)
      # rescue
      #   raise "PARSE ERROR! warning: could not parse info_description for current div: #{div.collect{|d| d.text}}"
      # end

      raise "\nERROR! no photo-credit, current div: \n#{div.collect{|d| d.text}}" if project['info']['photo_credit'].nil?

      idx += 4

      idx_str = "#{pageoffset.to_s.rjust(3, '0')}-#{(pageoffset + 1).to_s.rjust(3, '0')}"
      project['info']['pages'] = idx_str

      pageoffset += 2
      outfile = "#{@options[:out_dir]}/projects/#{@options[:vol]}/#{idx_str}.md"
      File.open(outfile,"w") do |f|
        f.write(ERBWithBinding::render_from_hash(@project_template, project))
      end

      projects << project

    end

    outjson = "#{@options[:out_dir]}/projects/#{@options[:vol]}/projects.json"
    File.open(outjson,"w") do |f|
      f.write(projects.to_json)
    end

    p ""
    p "Done!"
    p "wrote #{projects.length} projects to: #{outjson}"

    projects

  end #scrape_projects_html

  def self.scrape_terms_html
    # ex: ruby scrape_indesign.rb --infile /Users/edwardsharp/Desktop/index8/terms.html --out /Users/edwardsharp/Desktop/index8/out --volume 2018 --terms --dryrun
    # ex: ruby scrape_indesign.rb --infile /Users/edwardsharp/Desktop/index8/terms.html --out /Users/edwardsharp/src/github/emergencyindex/projects-2018 --volume 2018 --terms
    p "reading #{@options[:in_file]}..."

    page = Nokogiri::HTML(open(@options[:in_file]))

    terms = {}
    
    page.css('p').each do |_p|
      term_entry = _p.text.strip

      # gsub to try and fix commas that do not have space after them so split(' ') workz better!
      term_parts = term_entry.gsub(/,([^ ])/, ', \1').split(' ')
      next if term_parts.length < 2
      # puts "term_entry: #{term_entry}"

      base = ''
      see = false
      see_also = false
      term_pages = []
      for part in term_parts do
        # yank common delinatorz used in page lists
        no_delinatorz = part.gsub(',','').gsub(';','')
        # try to determine if this is all numbers and thus a list of pages.
        # if there are more than 0 numbers and nothing else, it must be a list of pages. neat.
        isNumeric = no_delinatorz.scan(/\d/).length > 0 and no_delinatorz.scan(/\D/).empty?
        if part === 'see'
          # p "zomg see! #{part}"
          see = true
        elsif part === 'also'
          # p "zomg also! #{part}"
          see_also = true
        elsif !isNumeric and !see and !see_also
          if base.length === 0
            base += part
          else
            base += " #{part}"
          end
        elsif isNumeric and !see and !see_also 
          term_pages << page_to_pages(part)
        else 
          # puts "zomg something else:#{part}"
        end

      end #end for

      base = base.delete_suffix(',').strip

      if terms[base]
        terms[base] = terms[base].concat term_pages
      else
        terms[base] = term_pages
      end

    end

    pages_data = {}

    terms.each do |term, pages|
      pages.each do |page|
        if pages_data[page].nil? 
          pages_data[page] = [term]
        else
          pages_data[page] << term
        end
      end
    end

    # pp terms

    if @options[:dryrun]
      p "...writing terms.json"
      Dir.mkdir("#{@options[:out_dir]}/projects") unless Dir.exist?("#{@options[:out_dir]}/projects")
      Dir.mkdir("#{@options[:out_dir]}/projects/#{@options[:vol]}") unless Dir.exist?("#{@options[:out_dir]}/projects/#{@options[:vol]}")
      outdir = "#{@options[:out_dir]}/projects/#{@options[:vol]}"
      File.open("#{outdir}/terms.json","w"){|f| f.write(JSON.pretty_generate(terms))}
      p "...writing pages.json"
      File.open("#{outdir}/pages.json","w"){|f| f.write(JSON.pretty_generate(pages_data))}
    else
      p "...writing project .md files (#{outdir})"
      outdir = @options[:out_dir] = "#{@options[:out_dir]}/" unless @options[:out_dir][-1] == '/'
      pages_data.each do |pages, terms|
        project_file = "#{outdir}#{pages}.md"
        unless File.exist?(project_file)
          p "WARN: #{project_file} doesnot exist!"
          p "terms: #{terms}"
          next
        end
        project = read_md(file:project_file)
        project[:yml]["tags"] = terms.sort_by(&:downcase).uniq
        File.open(project_file,"w"){|f| f.write("#{project[:yml].to_yaml}---#{project[:description]}")}
      end
    end

    p "Done!"

  end #scrape_terms_html

  def self.build_terms_index
    # ex: ruby scrape_indesign.rb --infile /Users/edwardsharp/Desktop/index8/terms.html --volume 2018 --termsindex
    p "reading #{@options[:in_file]}..."

    page = Nokogiri::HTML(open(@options[:in_file]))

    # note: this volume may or not have tags before "A"
    
    md_out = terms_index_md

    page.css('p').each do |_p|

      _spans = _p.css('span')
      p "zomg no spans?? #{(_p.inspect)}" unless _spans[0] 
      next unless _spans[0]
      base_term = _spans[0].text.strip
      if _spans.length == 1
        # this must be a letter section heading
        md_out += "{: ##{base_term} .index .sticky-nav }\n"
        md_out += "## #{base_term}\n\n"
        next
      end

      md_out += "**#{base_term}** "

      contentz = _p.text.split(' ')
      p "zomg contentz: #{contentz}"
      # _spans.each_with_index do |_span, i|
      contentz.each_with_index do |text, i|
        # text = _span.text.strip
        p "text blank?" if text.blank? or i == 0
        next if text.blank? or i == 0

        # yank common delinatorz used in page lists
        no_delinatorz = text.gsub(',','').gsub(' ','').gsub(';','')
        # try to determine if this is all numbers and thus a list of pages.
        # if there are more than 0 numbers and nothing else, it must be a list of pages. neat.
        isNumeric = no_delinatorz.scan(/\d/).length > 0 and no_delinatorz.scan(/\D/).empty?
        if isNumeric
          md_out += text.gsub(';','').split(',').map{ |s| "[#{s.strip.rjust(3, '0')}]"}.join(', ')
          md_out += ' '
          next
        end

        if text == 'see' or text == 'see also' or text == 'as in'
          md_out += "_#{text}_ "
          next
        end

        md_out += text.split(',').map{ |t| "<span class=\"see-also\">#{t.strip}</span>" }.join(',')
        md_out += ' '

      end

      md_out += "\n\n"
    end
    
    p "wrote to ./terms.md"
    File.open('terms.md',"w"){|f| f.write(md_out)}

  end

  def self.tidy_project_yml
    # ex: ruby scrape_indesign.rb --tidy /Users/edwardsharp/src/github/emergencyindex/projects-2019
    p "DRY RUNNING TIDY PROCESS (good job!)" if @options[:drytidy]
    #/Users/edward/src/tower/github/alveol.us/_projects/
    @options[:tidy] = "#{@options[:tidy]}/" unless @options[:tidy][-1] == '/'
    p "Looking for MD files in #{@options[:tidy]}"
    all_filez = Dir.glob("#{@options[:tidy]}**/*.md").select{ |e| File.file? e }
    len = all_filez.length
    idx = 0
    all_filez.each do |file|
      status_update(len:len, idx:idx)
      project = read_md file: file

      # alphabetize and remove duplicate tags 
      # project[:yml]["tags"] = project[:yml]["tags"].map(&:to_s).sort_by(&:downcase).uniq
      
      # try to remove HTML entities
      # project[:yml]["title"] = Nokogiri::HTML.parse(project[:yml]["title"]).text
      # project[:yml]["contributor"] = Nokogiri::HTML.parse(project[:yml]["contributor"]).text
      # project[:yml]["photo_credit"] = Nokogiri::HTML.parse(project[:yml]["photo_credit"]).text
      # project[:yml]["collaborators"].each{ |collaborator| collaborator = Nokogiri::HTML.parse(collaborator).text } rescue nil
      # project[:description] = Nokogiri::HTML.parse(project[:description]).text

      project[:yml]["title"].upcase!
      project[:yml]["contributor"].upcase!

      File.open(file,"w"){|f| f.write("#{project[:yml].to_yaml}---\n#{project[:description]}")} unless @options[:drytidy]
      idx += 1
    end

    p "done! #{len} filez"
  end

  def self.validate_images
    # ex: ruby utilz/scrape_indesign.rb --validateimages /Users/edwardsharp/Desktop/index8/out/projects/2018 --validateimagesdir /Users/edwardsharp/src/github/emergencyindex/projects-2018
    # useful stuff todo before this:
    # mogrify -format jpg *.png
    #   convert png files to jpeg
    # detox -rvn /Users/edwardsharp/src/github/emergencyindex/projects-2018
    #   note: -n for dry-run. detox removes bad files name chars.
    # use hash keys with original filename and value of detox'd filename, like:
    detoxd = {
      'N_49.39\'7.92__W_124.4\'11.397_.jpg': 'N_49.39_7.92_W_124.4_11.397_.jpg',
    }

    # make sure dirz ends with a slash.
    @options[:validate_images] = "#{@options[:validate_images]}/" unless @options[:validate_images][-1] == '/'
    @options[:validate_images_dir] = "#{@options[:validate_images_dir]}/" unless @options[:validate_images_dir][-1] == '/'

    raise "--validateimages '#{@options[:validate_images]}' directory does not exist?'" unless File.directory? @options[:validate_images]
    raise "--validateimagesdir '#{@options[:validate_images_dir]}' directory does not exist?'" unless File.directory? @options[:validate_images_dir]

    p "Looking for MD files in #{@options[:validate_images]}..."

    all_filez = Dir.glob("#{@options[:validate_images]}**/*.md").select{ |e| File.file? e }
    len = all_filez.length
    raise "no .md files found here: #{@options[:validate_images]}?" if len == 0
    idx = 0
    all_filez.each do |file|
      needToReWrite = false
      project = read_md file: file

      img = project[:yml]["image"]
      
      if detoxd.has_key? img.to_sym
        # p "need to re-write detoxd file!"
        img = detoxd[img.to_sym]
        needToReWrite = true
      end

      if img.match /.*\.png/
        # p "need to re-write png -> jpg"
        img.gsub!('.png', '.jpg')
        needToReWrite = true
      end

      hasimg = File.exist?("#{@options[:validate_images_dir]}#{img}")

      if hasimg and needToReWrite
        p "re-writing image #{project[:yml]["image"]} to #{img} for #{file}."
        project[:yml]["image"] = img
        File.open(file,"w"){|f| f.write("#{project[:yml].to_yaml}---\n#{project[:description]}")}
      end

      unless hasimg
        p "onoz! '#{img}' does not seem to exist? probably need to manually fix #{file}?"
      end

      idx += 1
    end

    p "done! checked #{len} md filez"

  end

  def self.validate_meta
    # NOTE: update this_volume
    this_volume = '2019'
    # validate each project first_performed & times_performed. copies problem .md files to /needs_review/ dir
    # ex: ruby ./utilz/scrape_indesign.rb -P
    # first_performed: first performed on December 4, 2018
    # times_performed: performed once in 2018
    
    project_dir_default = '/Users/edwardsharp/src/github/emergencyindex/emergencyindex.com/_projects/2019'
    p "enter path to projects .md files: [#{project_dir_default}]"
    projects_dir = gets.chomp
    projects_dir = project_dir_default if projects_dir.empty?
    projects_dir = "#{projects_dir}/" unless projects_dir[-1] == '/'
    raise "ERROR: unable to find projects in: #{projects_dir}" unless File.directory?(projects_dir)
    all_filez = Dir.glob("#{projects_dir}**/*.md").select{ |e| File.file? e }
    len = all_filez.length
    raise "no .md files found here: #{projects_dir}?" if len == 0

    md_needs_manual_review = []
    all_filez.each do |file|
      project = read_md file: file
  
      next if project[:yml]["pages"] == "000-001"

      first_performed = project[:yml]["first_performed"].split(' ')
      if first_performed[0] != 'first' or first_performed[1] != 'performed' or first_performed[2] != 'on' or first_performed[first_performed.length - 1] != this_volume
        p "#{project[:yml]["pages"]} first_performed wrong."
        md_needs_manual_review << project[:yml]["pages"]
      end
    
      times_performed = project[:yml]["times_performed"].split(' ')
      if times_performed[0] != 'performed' or times_performed[times_performed.length - 1] != this_volume
        p "#{project[:yml]["pages"]} times_performed wrong"
        md_needs_manual_review << project[:yml]["pages"]
      end

      if project[:yml]["title"].strip.empty? or project[:yml]["contributor"].strip.empty? or project[:yml]["place"].strip.empty?
        p "#{project[:yml]["pages"]} title, contributor, or place wrong."
        md_needs_manual_review << project[:yml]["pages"]
      end

    end

    if md_needs_manual_review.length > 0
      needs_review_dir = "#{projects_dir}/needs_review"
      p "#{md_needs_manual_review.length} md files need manual review. type 'y' to copy files to #{needs_review_dir}, 'v' to view, or type anying else to cancel and quit."
      copy_filez = gets.chomp
      if copy_filez == 'y'
        Dir.mkdir("#{needs_review_dir}") unless Dir.exist?("#{needs_review_dir}")
        md_needs_manual_review.each do |pages|
          FileUtils.cp("#{projects_dir}#{pages}.md", "#{needs_review_dir}/#{pages}.md")
        end
        
        p "copied files to: #{projects_dir}needs_review/"
      elsif copy_filez == 'v'
        md_needs_manual_review.each do |pages|
          p "pages: #{pages}"
        end
      end
    end

  end

  def self.cross_ref
    # attempt to update projects metadata with submission data.
    # ex: ruby ./utilz/scrape_indesign.rb -c
    csvfile_default = '/Users/edwardsharp/Desktop/TRASH BOAT/index9/vol9subz.csv'
    p "enter path to projects .csv file: [#{csvfile_default}]"
    csvfile = gets.chomp
    csvfile = csvfile_default if csvfile.empty?
    raise "ERROR: unable to find file: #{csvfile}" unless File.exist?(csvfile)

    project_dir_default = '/Users/edwardsharp/src/github/emergencyindex/emergencyindex.com/_projects/2019'
    p "enter path to projects .md files: [#{project_dir_default}]"
    projects_dir = gets.chomp
    projects_dir = project_dir_default if projects_dir.empty?
    projects_dir = "#{projects_dir}/" unless projects_dir[-1] == '/'
    raise "ERROR: unable to find projects in: #{projects_dir}" unless File.directory?(projects_dir)
    all_filez = Dir.glob("#{projects_dir}**/*.md").select{ |e| File.file? e }
    len = all_filez.length
    raise "no .md files found here: #{projects_dir}?" if len == 0

    # go thru each csv row and collect hash of projects 
    projects = {}
    projects_arr = [] # this is sorta lazy, stuffing into array so later if unable to find this by key then will use .filter
    CSV.foreach(csvfile, headers: true) do |row|
      # use title--contributor key so we can find this again
      begin
        # key = "#{row['title'].upcase}--#{row['contributor'].upcase}"
        key = row['contributor'].upcase
        proj = {
          photo_credit: row['photo_credit'],
          title: row['title'].upcase,
          first_performed: row['first_performed'],
          place: row['place'],
          contributor: row['contributor'].upcase,
          collaborators: row['collaborators'],
          home: row['home'],
          links: row['links'],
          contact: row['contact'],
        }
        projects[key] = proj
        projects_arr << proj
      rescue 
        p "ohnoz! caught error! row['title']#{row['title']} row['contributor']:#{row['contributor']} row: #{row}"
      end


    end

    # okay, iterate thru all the project .md files and try to find the row in CSV to compare...

    md_needs_manual_review = []
    md_files_updated = 0
    all_filez.each do |file|
      project = read_md file: file
  
      next if project[:yml]["pages"] == "000-001"
      key = project[:yml]["contributor"].upcase
      csv_project = projects[key]

      if csv_project.nil?
        ['title', 'contact', 'photo_credit'].each do |lookup|
          next if project[:yml][lookup].empty? # bail if value is empty.
          csv_project = projects_arr.find do |a|
            p "trying extra hard to lookup: #{lookup} project[:yml][lookup]:#{project[:yml][lookup]}"
            # p "FOUND ONE!! #{lookup}: #{project[:yml][lookup]}" if a[lookup.to_sym] == project[:yml][lookup]
            a[lookup.to_sym] == project[:yml][lookup]
          end
          break unless csv_project.nil?
        end
      end

      # check if the md file needs to be updated
      unless csv_project.nil?
        needs_update = false
        csv_project.keys.each do |k|
          # home field is often reformated, so skip if current value is blank.
          next if k.to_s == 'home' and !project[:yml][k.to_s].blank?
          # check if this is an array field
          if project[:yml][k.to_s].kind_of?(Array)
            if k.to_s == 'links'
              v = [csv_project[k].gsub('http://','').gsub('https://','').gsub('www.','').gsub(/\/$/, '').strip.downcase] rescue []
            elsif k.to_s == 'collaborators'
              v = csv_project[k].split(',').map(&:strip) rescue []
            else
              v = [csv_project[k]]
            end
          else
            v = csv_project[k].strip rescue nil
          end

          next if v.nil? or v.empty?
          if project[:yml][k.to_s] != v
            project[:yml][k.to_s] = v if needs_update
            # p "ZOMG NEED MD UPDATE #{k}. diff: #{project[:yml][k.to_s]}>>>#{v}"
            needs_update = true
          end
          
        end

        if needs_update
          File.open(file,"w"){|f| f.write("#{project[:yml].to_yaml}---\n\n#{project[:description].strip}\n")}
          md_files_updated += 1
        end

      end

      # p "cant find project for key: #{key} pages:#{project[:yml]["pages"]}" if csv_project.nil?
      md_needs_manual_review << project[:yml]["pages"] if csv_project.nil?

    end

    p "#{md_files_updated} .md files updated!"

    if md_needs_manual_review.length > 0
      needs_review_dir = "#{projects_dir}/needs_review"
      p "#{md_needs_manual_review.length} md files need manual review. type 'y' to copy files to #{needs_review_dir} (or type anying else to cancel and quit)."
      copy_filez = gets.chomp
      if copy_filez == 'y'
        Dir.mkdir("#{needs_review_dir}") unless Dir.exist?("#{needs_review_dir}")
        md_needs_manual_review.each do |pages|
          FileUtils.cp("#{projects_dir}#{pages}.md", "#{needs_review_dir}/#{pages}.md")
        end
        
        p "copied files to: #{projects_dir}needs_review/"
      end
    end

  end

  def self.raw_json
    # attempt to scrape raw submissions json data
    # ex: ruby ./utilz/scrape_indesign.rb -r
    pageoffset = @options[:pageoffset]

    project_dir_default = '/Users/edwardsharp/Desktop/TRASH BOAT/emergencyINDEX/ten_plus/vol10'
    p "enter path to projects .json files: [#{project_dir_default}]"
    projects_dir = gets.chomp
    projects_dir = project_dir_default if projects_dir.empty?
    projects_dir = "#{projects_dir}/" unless projects_dir[-1] == '/'
    raise "ERROR: unable to find projects in: #{projects_dir}" unless File.directory?(projects_dir)
    all_filez = Dir.glob("#{projects_dir}**/*.json").select{ |e| File.file? e }
    len = all_filez.length
    raise "no .json files found here: #{projects_dir}?" if len == 0

    all_projects = []

    all_filez.each do |file|
      # p "file: #{file}"
      f = File.read(file, encoding: 'UTF-8')
      project_json = JSON.parse(f)
      # p "project_json: #{project_json}"
      # p "keyz: #{project_json.keys}"

      project_hash = {}
      project_json['project_form']['items'].each do |item|
        project_hash[item['id']] = item['value']
      end

      unless is_first_performed_valid_year project_hash['date_first_performed']
        p "SKIPPING #{project_hash['title']} not valid year #{project_hash['date_first_performed']}"
        next
      end
      # transform project_hash into project (key map)
      project = default_project

      # try to find the correct image
      # note: photoUrl has double __
      photoUrl = File.basename(project_json['photoUrl']).split('__',2)[1].gsub('JPG','jpg').gsub('JPEG','jpg')
      # origPhoto is just the original photoName, but there is some string mangle :/ and only one _
      origPhoto = File.basename(project_json['origPhoto']).split('_',2)[1].gsub('JPG','jpg').gsub('JPEG','jpg')
      if File.exists? "#{projects_dir}images_named/#{photoUrl}"
        project['info']['image'] = photoUrl
      elsif File.exists? "#{projects_dir}images/#{origPhoto}"
        project['info']['image'] = origPhoto
      else 
        p "PROJECT IMAGE NOT FOUND! :( looked for #{photoUrl} and #{origPhoto}"
      end

      project['info']['photo_credit'] = project_hash['photo_credit'].strip
      project['info']['title'] = project_hash['title'].strip.upcase
      # note: will format this date later, leaving so we can sort by date
      project['info']['first_performed'] = project_hash['date_first_performed']
      # p " date_first_performed: #{project['info']['first_performed']}"
      # note: make sure dates are good, here, before starting to writing filez...
      parse_first_performed_date project['info']['first_performed']
      project['info']['place'] = project_hash['venue'].strip
      project['info']['times_performed'] = "performed #{times_performed(project_hash['times_performed'])} in 2020"
      project['info']['contributor'] = project_hash['contributor'].strip.upcase
      project['info']['collaborators'] = project_hash['collaborators'].split(',').map!(&:strip)
      project['info']['home'] = project_hash['home'].strip
      project['info']['links'] = project_hash['links'].split(',').map!(&:strip)
      project['info']['contact'] = project_hash['published_contact'].strip
      # project['info']['footnote'] = project_hash['']
      # project['info']['tags'] = []
      # project['info']['pages'] = project_hash['']
      project['description'] = project_hash['description'].split('\n').map!(&:strip)

      # p "zomg project['description']: #{project['description']}"
      all_projects << project

      # note: break if u just want to try one.
      # break
    end #all_filez each

    all_projects.sort_by! { |proj| proj['info']['first_performed'] }

    all_projects.each do |project|
      # reformat first_performed
      project['info']['first_performed'] = first_performed project['info']['first_performed']

      idx_str = "#{pageoffset.to_s.rjust(3, '0')}-#{(pageoffset + 1).to_s.rjust(3, '0')}"
      project['info']['pages'] = idx_str

      #note remove n-number of underscores _ at the beginning of image image filename: .sub(/^_+/,'')
      tidyimage = project['info']['image'].gsub('jpeg','jpg').sub(/^_+/,'').sub(/\.png$/,'.jpg').sub(/\.tiff$/,'.jpg').sub(/\.tif$/,'.jpg')
      project['info']['image'] = tidyimage
      # imgfile = "#{projects_dir}images_named/#{project['info']['image']}"
      # imgfile2 = "#{projects_dir}images/#{project['info']['image']}"
      # if File.exists? imgfile
      #    # copy image
      #    project['info']['image'] = tidyimage
      #    FileUtils.cp(imgfile, "#{projects_dir}out/img/2020/#{tidyimage}")
      #    p "wrote image #{projects_dir}out/img/2020/#{tidyimage}"
      # elsif File.exists? imgfile2
      #    # copy image
      #    project['info']['image'] = tidyimage
      #    FileUtils.cp(imgfile2, "#{projects_dir}out/img/2020/#{tidyimage}")
      #    p "wrote image #{projects_dir}out/img/2020/#{tidyimage}"
      # else
      #   p "ERROR! project image #{imgfile} not found!"
      # end

      pageoffset += 2
      outfile = "#{projects_dir}out/projects/2020/#{idx_str}.md"

      # write entire file:
      File.open(outfile,"w") do |f|
        f.write(ERBWithBinding::render_from_hash(@project_template, project))
      end
      p "wrote project file: #{outfile}"

      # MERGE SECTION
      # # try to read existing file and merge 
      # existing_project = read_md file: outfile
      # # update times_performed
      # existing_project[:yml]["times_performed"] = project['info']['times_performed']
      # # File.open(outfile,"w"){|f| f.write("#{existing_project[:yml].to_yaml}---\n#{existing_project[:description]}")}
      # # p "merged #{outfile}!"
      # END MERGE SECTION

    end #all_projects.each

  end #def self.raw_json

  def self.fix_project_pages
    # attempt to fix project pages metadata and filenames
    pageoffset = @options[:pageoffset]

    project_dir_default = '/Users/edwardsharp/src/github/emergencyindex/projects-2020/projects/2020'
    p "enter path to projects .md files: [#{project_dir_default}]"
    projects_dir = gets.chomp
    projects_dir = project_dir_default if projects_dir.empty?
    projects_dir = "#{projects_dir}/" unless projects_dir[-1] == '/'
    raise "ERROR: unable to find projects in: #{projects_dir}" unless File.directory?(projects_dir)
    all_filez = Dir.glob("#{projects_dir}**/*.md").select{ |e| File.file? e }
    len = all_filez.length
    raise "no .md files found here: #{projects_dir}?" if len == 0

    all_filez.each do |file|

      project = read_md file: file
      idx_str = "#{pageoffset.to_s.rjust(3, '0')}-#{(pageoffset + 1).to_s.rjust(3, '0')}"
      pageoffset += 2
      
      if project[:yml]["pages"] != idx_str
        outfile = "#{projects_dir}#{idx_str}.md"
        project[:yml]["pages"] = idx_str
        File.open(outfile,"w"){|f| f.write("#{project[:yml].to_yaml}---\n#{project[:description]}")}
        p "DIFF fromfile: #{project[:yml]["pages"]} calc:#{idx_str} ...updated #{outfile}!" 
      end

    end

  end #self.fix_project_pages

  def self.gen_tags
    # ruby ./utilz/scrape_indesign.rb -g
    # attempt to generate tags for projects by comparing description words to existing tag set

    # load all the friggen tags!
    all_projects_dir_default = '/Users/edwardsharp/src/github/emergencyindex/emergencyindex.com/_projects'
    p "enter path to all the projects .md files: [#{all_projects_dir_default}]"
    all_projects_dir = gets.chomp
    all_projects_dir = all_projects_dir_default if all_projects_dir.empty?
    all_projects_dir = "#{all_projects_dir}/" unless all_projects_dir[-1] == '/'
    raise "ERROR: unable to find projects in: #{all_projects_dir}" unless File.directory?(all_projects_dir)
    all_projects_files = Dir.glob("#{all_projects_dir}**/*.md").select{ |e| File.file? e }
    len = all_projects_files.length
    raise "no .md files found here: #{all_projects_dir}?" if len == 0

    # get single volue project files dir
    project_dir_default = '/Users/edwardsharp/src/github/emergencyindex/projects-2020/projects/2020'
    p "enter path to projects .md files: [#{project_dir_default}]"
    projects_dir = gets.chomp
    projects_dir = project_dir_default if projects_dir.empty?
    projects_dir = "#{projects_dir}/" unless projects_dir[-1] == '/'
    raise "ERROR: unable to find projects in: #{projects_dir}" unless File.directory?(projects_dir)
    all_filez = Dir.glob("#{projects_dir}**/*.md").select{ |e| File.file? e }
    len = all_filez.length
    raise "no .md files found here: #{projects_dir}?" if len == 0

    p "...hold please :)"

    # gather all the existing projects tags.
    all_project_tags = []
    all_projects_files.each do |file|
      project = read_md file: file
      all_project_tags << project[:yml]["tags"]
      all_project_tags.flatten!
      all_project_tags.uniq!
    end

    p "all_project_tags.length: #{all_project_tags.length}"

    all_filez.each do |file|

      project = read_md file: file
      project_tags = []
      begin 
        project_words = project[:description].split(' ').map!(&:strip).filter!{ |s| s.length > 1}
        p "so this project has #{project_words.length} words"
        # so look for tags
        project_tags = project_words.filter{ |word| all_project_tags.any?{ |tag| tag.casecmp(word) == 0 }}
        project_tags.sort_by!(&:downcase).uniq!(&:downcase)
        p "project_tags: #{project_tags.length}"
        project[:yml]["tags"] = project_tags
    
        outfile = "#{projects_dir}#{project[:yml]["pages"]}.md"
        File.open(outfile,"w"){|f| f.write("#{project[:yml].to_yaml}---#{project[:description]}")}
        p "tags generated for: #{outfile}!" 
      rescue 
        p "ohnoz! file:#{file}"
      end

    end


  end #def self.gen_tags

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

  def self.page_to_pages(page_string = '')
    page = page_string.gsub(',','').gsub(';','').strip
    if page.to_i.even?
      _next = (page.to_i + 1).to_s
      return "#{page.rjust(3, '0')}-#{_next.rjust(3, '0')}"
    else
      _prev = (page.to_i - 1).to_s
      return "#{_prev.rjust(3, '0')}-#{page.rjust(3, '0')}"
    end
  end

  def self.default_project 
    project = {}
    project['info'] = {}
    project['info']['layout'] = 'project'
    project['info']['volume'] = @options[:vol] || 2020
    project['info']['image'] = ''
    project['info']['photo_credit'] = ''
    project['info']['title'] = ''
    project['info']['first_performed'] = ''
    project['info']['place'] = ''
    project['info']['times_performed'] = ''
    project['info']['contributor'] = ''
    project['info']['collaborators'] = []
    project['info']['home'] = ''
    project['info']['links'] = []
    project['info']['contact'] = ''
    project['info']['footnote'] = ''
    project['info']['tags'] = []
    project['info']['pages'] = ''
    project['description'] = ''
    project
  end

  def self.times_performed(times)
    t = times.to_i
    case t
    when 1
      "once"
    when 2
      "twice"
    when 3
      "three times"
    when 4
      "four times"
    when 5
      "five times"
    when 6
      "six times"
    when 7
      "seven times"
    when 8
      "eight times"
    when 9
      "nine times"
    else 
      "#{t} times"
    end
  end

  def self.is_first_performed_valid_year(date)
    parse_first_performed_date(date).strftime('%Y') == "2020"
  end

  def self.parse_first_performed_date(date)
    begin
      Time::strptime(date,"%Y-%m-%d")
    rescue 
      p "unable to parse date: #{date}"
      raise 
    end
  end

  def self.first_performed(date)
    # date like: 
    # 2020-11-18
    # format like:
    # first_performed: first performed on November 18, 2020
    begin
      "first performed on #{parse_first_performed_date(date).strftime('%B %d, %Y')}"
    rescue 
      p "unable to parse date: #{date}"
      raise 
    end
  end

  def self.terms_index_md
    %{---
layout: page
name: Terms
volume: '#{@options[:vol]}'
title: 'Index #{@options[:vol]}: Terms'
wrapperclass: 'index-terms'
toc: #{@options[:vol]} Terms
---

\{: #0-9 .index .sticky-nav \}
## 0-9

}
  end
end

class ERBWithBinding < OpenStruct
  def self.render_from_hash(t, h)
    ERBWithBinding.new(h).render(t)
  end

  def render(template)
    ERB.new(template).result(binding)
  end
end

ScrapeIndesign.init
