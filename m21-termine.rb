# encoding: utf-8

require 'csv'
require 'bundler/setup'
require 'vpim'

OUTPUT = "m21-termine.ics"
INPUT = "m21-termine%YEAR%.csv"
YEARS = 2009..2015
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

def parseMonth(month)
  months = ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember']
  raise "Monat #{match[2]} nicht gefunden" unless months.index(month)
  months.index(month) + 1
end

def parseDateTime(date, time, year)
  date.strip! if date
  time.strip! if time

  month1 = nil
  month2 = nil
  day1 = nil
  day2 = nil
  hour = nil
  minute = 0

  if match = /^(\d\d?)\.\s+([A-ZÄÖÜ][a-zäöü]+)\s+bis\s+(\d\d?)\.\s+([A-ZÄÖÜ][a-zäöü]+)$/.match(date)
    day1 = match[1].to_i
    month1 = parseMonth(match[2])
    day2 = match[3].to_i
    month2 = parseMonth(match[4])
  elsif match = /^(\d\d?)\.\s+bis\s+(\d\d?)\.\s+([A-ZÄÖÜ][a-zäöü]+)$/.match(date)
    day1 = match[1].to_i
    day2 = match[2].to_i
    month1 = parseMonth(match[3])
  elsif match = /^(\d\d?)\.\s+([A-ZÄÖÜ][a-zäöü]+)$/.match(date)
    day1 = match[1].to_i
    month1 = parseMonth(match[2])
  end
  if time
    if match = /^(\d\d?):(\d\d?)/.match(time)
      hour = match[1].to_i
      minute = match[2].to_i
    end
  end
  if month1 and day1
    month2 = month1 if day2 and not month2
    return [createDateTime(year, month1, day1, hour, minute), createDateTime(year, month2, day2)]
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
          if ende.respond_to? :hour
            e.dtend ende
          else
            e.dtend ende + 1
          end
        elsif start.respond_to? :hour
          e.dtend start + 2 * 60 * 60
        else
          e.dtend start + 1
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

YEARS.each do |year|
  filename = INPUT.gsub('%YEAR%', year.to_s)
  readFile(filename, year)
end

ical = $cal.encode
File.open(OUTPUT, 'w') do |file|
  file.print ical
end

puts "Output written to #{OUTPUT}."