require 'mechanize'
require 'logger'
require 'zip/zip'

class GetScary
  attr_accessor :agent, :first_page, :chapter_markers, :range

  def initialize(range)
    @agent = Mechanize.new
    @agent.log = Logger.new "mech.log"
    @agent.user_agent_alias = 'Mac Safari'
    @range = range
  end

  def prep_chapters
    # Prep Chapter Markers
    page = agent.get("http://scarygoround.com/sgr/")
    @chapter_markers = {}
    i = 1
    @first_page = 0
    load_chapter = 1
    if @range && @range.is_a?(Array)
      load_chapter = @range.first
    end
    page.search("//a[contains(@href,'ar.php?date=')]").each{ |anchor|
      marker = anchor.attributes["href"].to_s.split('ar.php?date=')[-1].to_s
      @first_page = marker if i == load_chapter
      @chapter_markers[marker] = {chapter_id: i, chapter_name: "Chapter #{i}"}
      i = i + 1
    }

  end

  def start_download
    # Start with first page of first Chapter
    page = @agent.get("http://scarygoround.com/sgr/ar.php?date=#{@first_page}")
    puts @agent.current_page().uri()

    keep_going = true
    current_chapter = {}
    while keep_going
      page = @agent.current_page()
      current_page_id = page.uri().to_s.split("http://scarygoround.com/sgr/ar.php?date=")[-1]
      chapter_start = @chapter_markers[current_page_id]
      if chapter_start
        zip_previous_chapter(current_chapter[:chapter_id]) if current_chapter[:chapter_id]
        current_chapter = chapter_start
        puts "Chapter switched to -> " + current_chapter[:chapter_id].to_s
        if @range && @range.is_a?(Array)
          if current_chapter[:chapter_id] > @range.last
            keep_going = false
            exit
          end
        end
      end
      comic_image = page.search("//img[contains(@src,'strip')]").first.attributes["src"].to_s
      comic_url = "http://scarygoround.com/sgr/#{comic_image}"
      image_name = comic_image.split('/')[-1]

      @agent.get(comic_url).save("#{chapter_directory(current_chapter[:chapter_id])}/#{image_name}")
      puts "Currently Downloading: #{current_chapter[:chapter_name]}"
      puts "Downloading comic address: #{comic_url}"

      next_link = page.link_with(:text => "Next")
      if next_link
        next_page = @agent.click(next_link)
        puts @agent.current_page().uri()
      else
        zip_previous_chapter(current_chapter[:chapter_id])
        keep_going = false
      end
    end
  end

  def chapter_directory(chapter_id)
    "sgr_comics/chapter_#{chapter_id}"
  end

  def zip_file_path(chapter_id)
    directory_name = "saved_comics"
    unless File.directory?(directory_name)
      FileUtils.mkdir_p(directory_name)
    end
    "#{directory_name}/chapter_#{chapter_id}.cbz"
  end

  def zip_previous_chapter(chapter_id)
    directory = chapter_directory(chapter_id)
    zipfile_name = zip_file_path(chapter_id)
    if File.exist?(zipfile_name)
      File.delete(zipfile_name)
    end
    Zip::ZipFile.open(zipfile_name, 'w') do |zipfile|
      Dir["#{directory}/**/**"].reject{|f|f==zipfile_name}.each do |file|
        zipfile.add(file.sub(directory+'/',''),file)
      end
    end
  end

  class << self
    def new_download(range = nil)
      scary_downloader = self.new(range)
      scary_downloader.prep_chapters
      scary_downloader.start_download
    end
  end

end

puts "What chapter range of Scary Go Round would you like to download?"
puts "(enter hyphenated range) e.g. chapter 1-3 like this: '1-3'"
puts "For all comics press Enter."
$stdout.flush
chapter_range = gets.chomp
if chapter_range.include? "-"
  chapter_range_array = chapter_range.split("-").map(&:to_i)
  puts "You would like Chapter #{chapter_range_array.first} through #{chapter_range_array.last}?"
else
  puts "You would like all Chapters?"
end
puts "Enter Yes or No"
response = gets.chomp
if ['yes','Yes','y','Y'].any?{ |word| response.include?(word) }
  GetScary.new_download(chapter_range_array)
else
  puts "Exiting..."
end

exit
