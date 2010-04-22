require 'rubygems'
require 'haml'
require 'sinatra'
require 'broadway'
require 'open-uri'

enable :sessions
set :public, "public"
set :views, "views"

VALID_TAGS = %w(p a img input cite h1 h2 h3 h4 h5 h6 li hr code span div)
DEFAULT_TAGS = %w(p a img input h1 h2 h3 h4 h5 h6 li code)

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

get "/" do
  haml :index
end

get "/house-of-cards" do
  url = params["url"]
  return unless url =~ /^http/
  tags = valid_tags(params["tags"] ? params["tags"].split(",") : nil)
  return unless url
  url.gsub(/\/$/, "")
  session[:house_of_cards_url] = url
  begin
    page = open(capture_url)
    html = Nokogiri::HTML(page)
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
    
    # add box2d classes
    nesting = tags.include?("li") and (tags.include?("img") || tags.include?("a"))
    
    tags.each do |tag|
      html.xpath("//#{tag}").each do |node|
        if nesting and tag =~ /^(img|a)$/
          matches = node.path.to_s.split("/").select {|part| part =~ /^li/ }
          if matches and !matches.empty?
            next
          end
        end
        clazz = node["class"] || ""
        clazz << " box2d"
        node["class"] = clazz.squeeze(" ").strip
      end
    end
    
    # change the title so they know this isn't the actual site
    title = html.xpath("//title").first
    title.content = title.text + "As a House of Cards | "
    
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
    
    html.to_html
  rescue Exception => e
    puts "ERROR: #{e.backtrace.join("\n")}"
    haml :index
  end
end

# catch all route
%w(/:page /*/:page).each do |route|
  get route do
    path = params[:splat].nil? ? '' : "#{params[:splat].first}/"
    path << params[:page]
    path = correct_path(path)
    puts "RESULT: #{path}"
    ext = File.extname(path).downcase.split(".").last
    puts "EXT: #{ext}"
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