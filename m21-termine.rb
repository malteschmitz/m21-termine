# encoding: utf-8

require 'csv'
require 'bundler/setup'
require 'vpim'

OUTPUT = "m21-termine.ics"
SEQUENCE = 0


info_field = [
  Vpim::DirectoryInfo::Field.create('X-WR-CALNAME', "M21-Termine"),
  Vpim::DirectoryInfo::Field.create('X-WR-CALDESC', "Terminkalender des Ortsverabands Uetersen (M21) des Deutschen Amateur Radio Clubs (DARC)"),
  Vpim::DirectoryInfo::Field.create('METHOD', 'PUBLISH')
]

$cal = Vpim::Icalendar.create(info_field)

def createDateTime(year, month, day, hour = nil, minute = 0)
  if year and month and day
    if hour and minute
      return Time.local(year, month, day, hour, minute)
    else
      return Date.new(year, month, day)
    end
  else
    return nil
  end
end

def parseDateTime(date, time, year)
  month = nil
  day1 = nil
  day2 = nil
  hour = nil
  minute = 0
  months = ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember']
  if match = /^(\d\d?)\. ([A-ZÄÖÜ][a-zäöü]+)/.match(date)
    day1 = match[1].to_i
    raise "Monat #{match[2]} nicht gefunden" unless months.index(match[2])
    month = months.index(match[2]) + 1
  elsif match = /^(\d\d?)\. bis (\d\d?)\. ([A-ZÄÖÜ][a-zäöü]+)/.match(date)
    day1 = match[1].to_i
    day2 = match[2].to_i
    raise "Monat #{match[3]} nicht gefunden" unless months.index(match[3])
    month = months.index(match[3]) + 1
  end
  if time
    if match = /^(\d\d?):(\d\d?)/.match(time)
      hour = match[1].to_i
      minute = match[2].to_i
    end
  end
  if month and day1
    return [createDateTime(year, month, day1, hour, minute), createDateTime(year, month, day2)]
  end
  return nil
end

def parseTags(text, links)
  return nil unless text
  result = text.gsub(/<b>([^<]*)<\/b>/) { $1 }
  result = result.gsub(/<br>|<br \/>/, "\n")
  result = result.gsub(/<link ([^ >]+)[^>]*>([^<]+)<\/link>/) do |s|
    url = $1
    content = $2
    if /^\d+$/ === url
      links << "http://www.darc.de/?id=#{url}"
    else
      links << url
    end
    content
  end
  return result
end

def readFile(filename, year)
  puts "Reading #{filename}..."

  CSV.foreach(filename, :col_sep => ';', :row_sep => :auto, :encoding => 'utf-8') do |row|
    start, ende = parseDateTime(row[0], row[1], year)
    links = []
    desc = parseTags(row[3], links)
    title = desc.split("\n").first

    ov = parseTags(row[2], links)
    title += " (#{ov})" if ov

    links.uniq!

    unless links.empty?
      url = links.first
      links = "weitere Informationen:\n" + links.collect { |t| "  - #{t}" }.join("\n")
    else
      url = nil
      links = nil
    end

    desc = desc + "\n\n" + links unless links.nil?

    if start and title then
      $cal.add_event do |e|
        e.dtstart start
        if ende
          e.dtend ende
        elsif start.respond_to? :hour
          e.dtend start + 2 * 60 * 60
        end
        e.summary title
        e.url url unless url.nil?
        e.description desc
        e.sequence SEQUENCE
        now = Time.now
        e.created now
        e.lastmod now
      end
    end
  end
end

(2009..2015).each do |year|
  readFile("m21-termine#{year}.csv", year)
end

ical = $cal.encode
File.open(OUTPUT, 'w') do |file|
  file.print ical
end

puts "Output written to #{OUTPUT}."