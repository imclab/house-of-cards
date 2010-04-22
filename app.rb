require 'rubygems'
require 'haml'
require 'sinatra'
require 'broadway'
require 'open-uri'

enable :sessions
set :public, "public"
set :views, "views"

VALID_TAGS = %w(p a img input cite h1 h2 h3 h4 h5 h6 li hr code span div label legend ul ol)
DEFAULT_TAGS = %w(p a img input h1 h2 h3 h4 h5 h6 li code label legend)

def pretty_print_html(xml)
  pretty_printer = IO.read(File.join(File.dirname(__FILE__), "pretty_print.xsl"))
  Nokogiri::XSLT(pretty_printer).transform(xml).children.to_html.gsub(/\t/, "")
end

def capture_url
  session[:house_of_cards_url]
end

def capture_url_base
  uri = URI.parse(capture_url)
  "#{uri.scheme}://#{uri.host}"
end

def valid_tag?(tag)
  VALID_TAGS.include?(tag)
end

def valid_tags(tags)
  tags ? tags.select {|tag| valid_tag?(tag)} : DEFAULT_TAGS
end

def correct_path(path)
  path ||= ""
  path.gsub!(/^\/*/, "")
  path = File.join(capture_url_base, path) unless path =~ /^http/
  path
end

def add_class(node, name)
  clazz = node["class"]
  clazz ||= ""
  clazz << " #{name}"
  node["class"] = clazz.squeeze(" ").strip
  node
end

get "/" do
  haml :index
end

get "/house-of-cards" do
  url = params["url"]
  perfect = params["perfect"] ? true : false
  return unless url =~ /^http/
  tags = valid_tags(params["tags"] ? params["tags"].split(",") : nil)
  return unless url
  url.gsub(/\/$/, "")
  session[:house_of_cards_url] = url
  begin
    page = open(capture_url)
    html = Nokogiri::HTML(page)
    
    # add box2d classes
    # to get the maximum effect, it should only add the box2d class
    # to leaf nodes, or what are the most visually pleasing leaf nodes:
    # DEFAULT_TAGS
    # li > a = li
    # li > a > img = li
    # li > ul > li > a = second li
    # li > h = li
    # p
    # p > a = p
    # * > span = *
    # input
    nesting_li = tags.include?("li") and (tags.include?("img") || tags.include?("a"))
    nesting_a = tags.include?("a") and tags.include?("img")
    
    if perfect
      paths = []
      html.xpath("//*").each do |node|
        paths << node.path
      end
      paths.sort.uniq!
    
      # remove unnecessary paths
      paths.delete_if do |path|
        deletable = true
        DEFAULT_TAGS.each do |tag|
          if path =~ /\/#{tag}/
            deletable = false
          end
        end
        deletable
      end
    
      # now cut the paths down to leafs (li, a, img, p, h)
    
      # do lists first
      lists_paths = []
      paths.delete_if do |path|
        deletable = false
        if path =~ /link/
          deletable = true
        elsif path =~ /\/li(\[\d*\])?/
          length = $1 ? $1.to_s.length : 1
          index = (path.rindex("/li") + length + 2).to_i
          path = path[0..index]
          lists_paths << path
          deletable = true
        end
        deletable
      end
    
      lists_paths.uniq!
        
      # then headers
      header_paths = []
      paths.delete_if do |path|
        deletable = false
        puts "PATH: #{path}"
        if path =~ /\/h(\d)(\[\d*\])?/
          puts "MATCHED HEADER!"
          length = $2 ? $2.to_s.length : 0
          index = (path.rindex("/h#{$1}") + length + 2).to_i
          path = path[0..index]
          header_paths << path
          deletable = true
        end
        deletable
      end
    
      # then links
      link_paths = []
      paths.delete_if do |path|
        deletable = false
        if path =~ /\/a(\[\d*\])?/
          length = $1 ? $1.to_s.length : 0
          index = (path.rindex("/a") + length + 2).to_i
          path = path[0..index]
          lists_paths << path
          deletable = true
        end
        deletable
      end
    
      # then basic ones
      other_paths = []
      paths.delete_if do |path|
        deletable = false
        if path =~ /\/(p|input|img)(\[\d*\])?/
          length = $2 ? $2.to_s.length : 0
          index = (path.rindex("/#{$1}") + length + 2).to_i
          path = path[0..index]
          other_paths << path
          deletable = true
        end
        deletable
      end
    
      total_paths = lists_paths + header_paths + link_paths + other_paths
    
      total_paths.each do |path|
        begin
          node = html.xpath(path).first
          puts "GOOD: #{path.to_s}"
          add_class(node, "box2d")
        rescue Exception => e
          puts "ERR: #{e.inspect}"
        end
      end
    else
    
      tags.each do |tag|
        html.xpath("//#{tag}").each do |node|
          if nesting_li and tag =~ /^(img|a)$/
            matches = node.path.to_s.split("/").select {|part| part =~ /^(li|h1|h2|h3|h4|h5|h6|a)$/ }
            if matches and !matches.empty?
              next
            end
          end
          add_class(node, "box2d")
        end
      end
    end
    
    # duplicate
#    html.xpath("//*[@class='box2d']").each do |box2d|
#      duplicate = box2d.clone
#      clazz = duplicate["class"] + " hidden_box2d_element"
#      box2d.add_next_sibling(duplicate)
#      duplicate["class"] = clazz
#    end
    
    # make all links absolute
    html.xpath("//img").each do |image|
      image["src"] = correct_path(image["src"])
    end
    html.xpath("//image").each do |image|
      image["src"] = correct_path(image["src"])
    end
    html.xpath("//a").each do |link|
      link["href"] = correct_path(link["href"])
    end
    html.xpath("//form").each do |form|
      form["action"] = correct_path(form["action"])
    end
    html.xpath("//script").each do |script|
      script["src"] = correct_path(script["src"]) if script.has_attribute?("src")
    end
    html.xpath("//link").each do |style|
      style["href"] = correct_path(style["href"])
    end
    
    # change the title so they know this isn't the actual site
    title = html.xpath("//title").first
    title.content = "As a House of Cards | #{title.text}"
    
    head = html.xpath("//head").first
    first_head_node = head.children.first
    body = html.xpath("//body").first
    
    # create a canvas
    canvas = html.create_element("div")
    canvas["id"] = "canvas"
    body.add_child(canvas)
    
    # add the code!
    %w(house-of-cards).each do |stylesheet|
      style = html.create_element('link')
      style["href"] = "/stylesheets/#{stylesheet}.css"
      style["rel"] = "stylesheet"
      style["type"] = "text/css"
      head.add_child(style)
    end
    
    %w(application protoclass box2d house-of-cards).each do |javascript|
      script = html.create_element('script')
      script["src"] = "/javascripts/#{javascript}.js"
      script["type"] = "text/javascript"
      body.add_child(script)
    end

    pretty_print_html(html)#.to_html
  rescue Exception => e
    haml :index
  end
end

# catch all route
%w(/:page /*/:page).each do |route|
  get route do
    path = params[:splat].nil? ? '' : "#{params[:splat].first}/"
    path << params[:page]
    path = correct_path(path)
    ext = File.extname(path).downcase.split(".").last
    case ext
      when "jpg", "jpeg"
        content_type "image/jpeg"
      when "png"
        content_type "image/png"
      when "gif"
        content_type "image/gif"
      when "css"
        content_type "text/css"
      when "js"
        puts "JAV"
        content_type "text/javascript"
      end
    begin
      open(path)
    rescue Errno::ENOENT
      puts "ERROR"
      ""
    end
  end
end