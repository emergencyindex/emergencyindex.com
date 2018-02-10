# load 'scrape_indesign.rb'
require 'json'
require 'nokogiri'
require 'sanitize'
require 'optparse'
require 'erb'
require 'yaml'
require 'carmen'
include Carmen

#/Users/edward/Desktop/emergencyINDEX/indesign_dump_2_4_2018/2012/html

module ScrapeIndesign

  @pinwheel = %w{ | / - \\ }
  @options = {}
  @project_template = File.read 'project_template.erb'


  def self.init
    
    @options[:out_dir] = Dir.pwd
    @options[:pageoffset] = 2

    optparse = OptionParser.new do |opts|
      opts.banner = "Usage: #{__FILE__} [options]"

      opts.on('-i', '--infile FILE', 'Input file name') { |v| @options[:in_file] = v }
      opts.on('-o', '--outdir DIRECTORY', 'Output directory') { |v| @options[:out_dir] = v }
      opts.on('-v', '--volume VOLUME', 'Volume Name') { |v| @options[:vol] = v }
      opts.on('-p', '--pageoffset OFFSET', 'Page of first project') { |v| @options[:pageoffset] = v }
      # opts.on("-s", "--[no-]scrape", "Scrape HTML") { |v| @options[:scrape] = v }
      # opts.on("-v", "--[no-]verbose", "Run verbosely") { |v| @options[:verbose] = v }
    end

    begin
      optparse.parse!
      mandatory = [:in_file, :vol, :pageoffset]
      missing = mandatory.select{ |param| @options[param].nil? }        
      unless missing.empty?                                            
        raise OptionParser::MissingArgument.new(missing.join(', '))    
      end 
    rescue OptionParser::InvalidOption, OptionParser::MissingArgument
      puts $!.to_s 
      puts optparse 
      exit          
    end  

    raise "ERROR! --infile does not exist" unless File.exist?(@options[:in_file])
    raise "ERROR! --outdir is not a directory" unless File.directory?(@options[:out_dir])

    scrape_html
    # print "Enter your name. "
    # STDOUT.flush
    # name = gets.chomp
    # puts "Hello #{name.capitalize}"


  end

  def self.scrape_html

    p "reading #{@options[:in_file]}...\n"
    Dir.mkdir("#{@options[:out_dir]}/projects") unless Dir.exist?("#{@options[:out_dir]}/projects")
    Dir.mkdir("#{@options[:out_dir]}/projects/#{@options[:vol]}") unless Dir.exist?("#{@options[:out_dir]}/projects/#{@options[:vol]}")
    
    page = Nokogiri::HTML(open(@options[:in_file]))

    projects = []
    idx = 0
    len = page.xpath('/html/body/div').length
    pageoffset = @options[:pageoffset]

    raise "\nERROR! wrong number of div elementz!" if len % 4 != 0

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

      div.each do |d|
        if d.css('div img').first and d.css('div img').first['src']
          project['info']['image'] = d.css('div img').first['src'].gsub("#{@options[:vol]}-web-resources/image/",'').strip
          next
        end
        if d.css('.photo-credit').first and d.css('.photo-credit').first.text
          project['info']['photo_credit'] = d.css('.photo-credit').first.text.strip
          next 
        end
        info_description << d
      end

      # begin
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
        if i.include?('.') and !i.strip.match(/\s/)
           project['info']['links'] << i.strip
           next
        end
        if i.strip.match(/[[:upper:]]/) and i.strip.match(/\s/) and !i.include?('@')
          check_split = i.split('/').last.split(',').last.strip
          if Country.coded(check_split) or
            Country.named(check_split) or
            Country.coded('US').subregions.coded(check_split) or
            Carmen::Country.coded('US').subregions.named(check_split, :fuzzy => true) or
            check_split == 'UK'
            project['info']['home'] = i.strip
            next
          end
          
        end

        project['info']['collaborators'] = i.split(',').map!(&:strip)
      end

      project['info']['contact'] = project['info']['contact'].strip


      info_description[1].css("span[class*=Italic]").each do |i|
        i.name = 'em'
      end
      info_description[1].css("p[class*=INDENT]").each do |i|
        i.name = 'blockquote'
      end
      project['description'] = info_description[1].css('p, blockquote').collect do |i| 
        CGI.unescapeHTML( Sanitize.fragment(i.to_html, elements: ['em', 'br', 'blockquote'])
          .gsub('<em>','_')
          .gsub('</em>', '_')
          .gsub('<br>', "\n")
          .gsub('<br />', "\n")
          .gsub('<br/>', "\n")
          .strip
          .gsub('<blockquote>', "\t")
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

  end #scrape_html

  def read_md file: ''
    s   = File.read(file, encoding: 'UTF-8')
    contents = s.match(/---(.*)---(.*)/m) #/m for multiline mode
    yml = YAML.load(contents[1])
    description = contents[2]

    out = "#{yml.to_yaml}---#{description}"

  end

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

private
  def self.status_update(len:nil, idx:nil)
    print "\b" * 16, "Progress: #{(idx.to_f / len * 100).to_i}% ", @pinwheel.rotate!.first
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
