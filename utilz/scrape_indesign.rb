# load 'scrape_indesign.rb'
require 'json'
require 'nokogiri'
require 'sanitize'
require 'optparse'
require 'erb'
require 'yaml'
require 'carmen'
include Carmen

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
      opts.on("-t", "--terms", "Scrape Terms") { |v| @options[:terms] = v }
      opts.on("-u", "--termstxt", "Scrape Terms Text") { |v| @options[:terms_txt] = v }
      opts.on("-T", "--writeterms", "Write Terms to MD") { |v| @options[:writeterms] = v }
      opts.on("-I", "--termsindex", "Build Terms Index MD") { |v| @options[:termsindex] = v }
      opts.on("-x", "--tidy DIRECTORY", "Tidy project YAML") { |v| @options[:tidy] = v }
      opts.on("-X", "--drytidy", "DRY RUN Tidy project YAML (no files modified)") { |v| @options[:drytidy] = v }
      opts.on("-V", "--validateimages DIRECTORY", "Validate project image files. Specify project dir with .md files.") { |v| @options[:validate_images] = v }
      opts.on("-I", "--validateimagesdir DIRECTORY", "Validate project images. Specify directory with project images.") { |v| @options[:validate_images_dir] = v }
    end.parse!


    unless @options[:tidy] or @options[:validate_images]
      raise "ERROR! --input file not specified" if @options[:in_file].nil?
      raise "ERROR! --infile does not exist" unless File.exist?(@options[:in_file])
      raise "ERROR! --outdir is not a directory" unless File.directory?(@options[:out_dir])
    end

    if @options[:projects]
      scrape_projects_html
    elsif @options[:terms]
      scrape_terms_html
    elsif @options[:terms_txt]
      scrape_terms_txt
    elsif @options[:writeterms]
      write_terms_to_md
    elsif @options[:termsindex]
      build_terms_index
    elsif @options[:tidy]
      tidy_project_yml
    elsif @options[:validate_images]
      validate_images
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

    raise "\nERROR! wrong number of div elementz! (#{len}) (see empty divz?)" if len % 4 != 0

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
      project['info']['photo_credit'] = info_description[1].css('p').first.text.strip

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
    # ex: ruby scrape_indesign.rb --infile /Users/edwardsharp/Desktop/index8/terms.html --out /Users/edwardsharp/Desktop/index8/out --volume 2018 --terms
    p "reading #{@options[:in_file]}..."
    Dir.mkdir("#{@options[:out_dir]}/projects") unless Dir.exist?("#{@options[:out_dir]}/projects")
    Dir.mkdir("#{@options[:out_dir]}/projects/#{@options[:vol]}") unless Dir.exist?("#{@options[:out_dir]}/projects/#{@options[:vol]}")

    page = Nokogiri::HTML(open(@options[:in_file]))

    terms = {}
    page.css('p').each do |_p|

      _terms = _p.text.split(';')

      _baseTerm = _terms[0].match(/^[^\d]*/)[0].strip
      _pages = _terms[0].gsub(/[^0-9,\ ]/, '').split(/,| /).reject(&:nil?)

      if _baseTerm.include?('also ')
        _also = _baseTerm.match(/also [^\d]*/)[0].gsub('also','').strip
        # p "ALSO!! #{_also}"
        terms[_also] ||= []
        terms[_also] << _pages
        terms[_also].flatten!
      end

      _baseTerm.gsub!(/also (.*)/,'')
      _baseTerm.gsub!(')','') if _baseTerm.include?(')') and !_baseTerm.include?('(')
      _baseTerm.gsub!('(','') if _baseTerm.include?('(') and !_baseTerm.include?(')')
      _baseTerm.strip!

      terms[_baseTerm] ||= []
      terms[_baseTerm] << _pages
      terms[_baseTerm].flatten!


      _terms[1..-1].each do |_t|
        _subTerm = _t.match(/^[^\d]*/)[0]
        _pages = _t.gsub(/[^0-9, ]/, '').split(/,| /).reject(&:nil?)
        if _t.include?('also ')
          _also = _t.match(/also [^\d]*/)[0].gsub('also','').strip
          _also.gsub!(')','') if _also.include?(')') and !_also.include?('(')
          # p "SUB ALSO: #{_also}"
          terms[_also] ||= []
          terms[_also] <<  _pages
          terms[_also].flatten!
        end
        terms[_baseTerm] ||= []
        terms[_baseTerm] << _pages
        terms[_baseTerm].flatten!
        _subKey = "#{_baseTerm} #{_subTerm.gsub(/\(also (.*)\)/,'').strip}"
        terms[_subKey] ||= []
        terms[_subKey] << _pages
        terms[_subKey].flatten!
      end
    end

    p "writing #{terms.length} items to terms.json"
    outfile = "#{@options[:out_dir]}/projects/#{@options[:vol]}/terms.json"
    File.open(outfile,"w"){|f| f.write(terms.to_json)}


    pages_hash = {}
    terms.each do |term, pages|

      pages.each do |page|
        if page.to_i.even?
          _next = (page.to_i + 1).to_s
          _pages = "#{page.rjust(3, '0')}-#{_next.rjust(3, '0')}"
        else
          _prev = (page.to_i - 1).to_s
          _pages = "#{_prev.rjust(3, '0')}-#{page.rjust(3, '0')}"
        end

        pages_hash[_pages] ||= []
        pages_hash[_pages] << term unless pages_hash[_pages].include?(term) or term.nil?
      end

    end

    p "Done!"
    outfile = "#{@options[:out_dir]}/projects/#{@options[:vol]}/pages.json"
    File.open(outfile,"w"){|f| f.write(pages_hash.to_json)}
    p "wrote #{pages_hash.length} items to #{outfile}"

  end #scrape_terms_html

  def self.scrape_terms_txt
    # read txt files like:
    # TERM [...pages]
    # example:  body 007, 023, 033, 119
    p "reading #{@options[:in_file]}..."
    Dir.mkdir("#{@options[:out_dir]}/projects") unless Dir.exist?("#{@options[:out_dir]}/projects")
    Dir.mkdir("#{@options[:out_dir]}/projects/#{@options[:vol]}") unless Dir.exist?("#{@options[:out_dir]}/projects/#{@options[:vol]}")

    terms = {}
    file = open(@options[:in_file])

    file.each do |line|
      term = line.match(/^[^\d]*/)[0].strip
      terms[term] = line.gsub(/[^0-9, ]/, '').split(/,| /).reject(&:empty?)
    end

    pages_hash = {}
    terms.each do |term, pages|

      pages.each do |page|
        if page.to_i.even?
          _next = (page.to_i + 1).to_s
          _pages = "#{page.rjust(3, '0')}-#{_next.rjust(3, '0')}"
        else
          _prev = (page.to_i - 1).to_s
          _pages = "#{_prev.rjust(3, '0')}-#{page.rjust(3, '0')}"
        end

        pages_hash[_pages] ||= []
        pages_hash[_pages] << term unless pages_hash[_pages].include?(term) or term.nil?
      end

    end

    p "Done!"
    outfile = "#{@options[:out_dir]}/projects/#{@options[:vol]}/terms_by_page.json"
    File.open(outfile,"w"){|f| f.write(pages_hash.to_json)}
    p "wrote #{pages_hash.length} items to #{outfile}"
  end

  def self.write_terms_to_md
    # ex: ruby scrape_indesign.rb --infile /Users/edwardsharp/Desktop/index8/out/projects/2018/pages.json --out /Users/edwardsharp/Desktop/index8/out/projects/2018/ --writeterms
    p "reading #{@options[:in_file]}..."
    j = JSON.parse( File.read(@options[:in_file]) )
    len = j.length
    idx = 0
    j.each do |item|
      status_update(len:len, idx:idx)
      project_file = "#{@options[:out_dir]}/#{item[0]}.md"
      unless File.exist?(project_file)
        p "WARN: #{project_file} doesnot exist!"
        next
      end
      project = read_md(file:project_file)
      project[:yml]["tags"] = item[1].sort_by(&:downcase).uniq
      File.open(project_file,"w"){|f| f.write("#{project[:yml].to_yaml}---#{project[:description]}")}
    end
  end

  def self.build_terms_index
     # ex: ruby scrape_indesign.rb --infile /Users/edwardsharp/src/github/emergencyindex/emergencyindex.com/utilz/projects/2017/terms.json --termsindex
     p "reading #{@options[:in_file]}..."
     j = JSON.parse( File.read(@options[:in_file]) )
     len = j.length
     idx = 0
     md_out = ''
     j.each do |item|
       status_update(len:len, idx:idx)

       if item[0].length === 1
         # this must be a letter section heading
         md_out += "{: ##{item[0]} .index .sticky-nav }\n"
         md_out += "## #{item[0]}\n\n"
       elsif item[1].length === 0
          if item[0] =~ /see also/
            splt = item[0].split('see also')
            md_out += "**#{splt[0].strip}** _see also_ "
            md_out += splt[1].split(',').map{ |t| "<span class=\"see-also\">#{t.strip}</span>"}.join(' ')
            md_out += "\n\n"
          elsif item[0] =~ /see/
            splt = item[0].split('see')
            md_out += "**#{splt[0].strip}** _see_ "
            md_out += splt[1].split(',').map{ |t| "<span class=\"see-also\">#{t.strip}</span>"}.join(' ')
            md_out += "\n\n"
          else 
            p "expected empty array to be see also ref, got: #{item[0]}"
          end
       else
         md_out += "**#{item[0]}** "
         md_out += item[1].map{ |pp| "[#{pp}]"}.join(', ')
         md_out += "\n\n"
       end
       
     end

     File.open('terms.md',"w"){|f| f.write(md_out)}

  end

  def self.tidy_project_yml
    # ex: ruby scrape_indesign.rb --tidy  /Users/edwardsharp/Desktop/index8/out/projects/2018/
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

      project[:yml]["tags"] = project[:yml]["tags"].map(&:to_s).sort_by(&:downcase).uniq
      
      # try to remove HTML entities
      project[:yml]["title"] = Nokogiri::HTML.parse(project[:yml]["title"]).text
      project[:yml]["contributor"] = Nokogiri::HTML.parse(project[:yml]["contributor"]).text
      project[:yml]["photo_credit"] = Nokogiri::HTML.parse(project[:yml]["photo_credit"]).text
      project[:yml]["collaborators"].each{ |collaborator| collaborator = Nokogiri::HTML.parse(collaborator).text } rescue nil
      project[:description] = Nokogiri::HTML.parse(project[:description]).text

      project[:yml]["title"].upcase!
      project[:yml]["contributor"].upcase!

      File.open(file,"w"){|f| f.write("#{project[:yml].to_yaml}---\n\n#{project[:description]}")} unless @options[:drytidy]
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
        File.open(file,"w"){|f| f.write("#{project[:yml].to_yaml}---\n\n#{project[:description]}")}
      end

      unless hasimg
        p "onoz! no image for: '#{img}'"
      end

      idx += 1
    end

    p "done! checked #{len} md filez"

  end

private
  def self.status_update(len:nil, idx:nil)
    print "\b" * 16, "Progress: #{(idx.to_f / len * 100).to_i}% ", @pinwheel.rotate!.first
  end

  def fix_2012_termz
    f = "/Users/edward/src/tower/github/alveol.us/utilz/projects/2012/pages_edited.json"
    j = JSON.parse( File.read(f) )

    j.each do |i|
      terms = i[1]
      terms.each do |t|
        m = t.match(/(.*)\(([a-z, ]*)\)/)
        if m and m[2]
          j[i[0]] -= [t]
          j[i[0]] << m[2].split(',').collect{|s| "#{m[1].strip} #{s.strip}" }
          j[i[0]].flatten!
          j[i[0]].sort!
        end
      end
    end

    File.open("/Users/edward/src/tower/github/alveol.us/utilz/projects/2012/pages_edited_fixed_subtermz.json","w"){|f| f.write(j.to_json)}

  end

  def self.read_md file: ''
    f = File.read(file, encoding: 'UTF-8')
    contents = f.match(/^---(.*)---(.*)/m) #/m for multiline mode
    raise "ERROR in read_md, contents.length > 2! #{contents.length}" if contents.length > 3
    yml = YAML.load(contents[1])
    description = contents[2]
    {yml: yml, description: description}
  end

  # misc shit
  def dump_from_rails
    project_template = File.read Rails.root.join('app/views/projects/jekyll.html.erb')
    Project.where(volume: Volume.where(year: 2011)).each do |project|
      @project = project
      outfile = "/Users/edward/src/tower/github/alveol.us/utilz/projects/2011/#{project.pages}.md"
      File.open(outfile,"w") do |f|
        f.write(ERB.new(project_template).result(binding))
        p "wrote #{outfile}"
      end
    end
  end

  def rename_imgz(dir: "/Users/edward/src/tower/github/alveol.us/assets/img/2011/")
    Dir["#{dir}*.jpg"].each do |img|
      File.rename(File.basename(img), File.basename(img).gsub(/[&$+,\/:;=?@<>\[\]\{\}\|\\\^~%# ]/,'_'))
    end
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
