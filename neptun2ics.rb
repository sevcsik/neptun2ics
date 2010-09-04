#!/usr/bin/ruby
# encoding: UTF-8

# neptun2ics v0.3 by sevcsik <sevcsik@gmail.com>
# orarend 'listas nyomtatasa' html konvertalasa iCalendar formatumba
# fuggosegek: rubygems, icalendar 
#   telepitesuk: # gem install icalendar

Help = <<eos
Usage: neptun2ics <input file> [output file] [options]
       options: -d --date <"YYYY-MM-DD">      first monday of the semester
                -f --format <"format">        format of the title field of events
                -w --weeks <number of weeks>  length of active part of semester in weeks
       format: available keywords: \#{name}, \#{code}, \#{location}
               for example, '\#{name} (\#{code}) @ \#{location}'
       note: some browsers like Chrome strips class attributes form saved html, 
             so the script can't find the table. Save as complete web page to avoid this.
eos

require 'rubygems'
require 'icalendar'
require 'time'
require 'getoptlong'
include Icalendar

Days = ["Hétfő", "Kedd", "Szerda", "Csütörtök", "Péntek", "Szombat", "Vasárnap"]
Freqs = ["Páratlan hét", "Páros hét", "Minden hét"]


RowPattern = /\<tr class="TimeTable_Row"\>\<td\>([^\<\>]*)(?:\<\/td\>)?\<td\>([0-9:]+)-([0-9:]+)(?:\<\/td\>)?\<td\>([^\<\>]*)(?:\<\/td\>)?\<td\>([^\<\>]*)(?:\<\/td\>)?\<td\>([^\<\>]*)(?:\<\/td\>)?\<td\>([^\<\>]*)(?:\<\/td\>)?\<\/tr\>/i

class Course
  def initialize(code, name, start_time, end_time, day, location, freq, date)
    @code = code
    @name = name
    @day = Days.index(day)
    @location = location
    @freq = Freqs.index(freq)
    
    @start_time = Time.parse(date)
    @start_time += (@day * 60 * 60 * 24 + start_time.split(':')[0].to_i * 60 * 60 + start_time.split(':')[1].to_i * 60)

    @end_time = Time.parse(date)
    @end_time += (@day * 60 * 60 * 24 + end_time.split(':')[0].to_i * 60 * 60 + end_time.split(':')[1].to_i * 60)

    if @freq == 1   # course starts on 2nd week
      @start_time += 60 * 60 * 24 * 7
      @end_time += 60 * 60 * 24 * 7
    end
  end
  attr_accessor :code, :name, :day, :location, :freq, :start_time, :end_time
end


opts = GetoptLong.new(
  ['--date',        '-d',   GetoptLong::REQUIRED_ARGUMENT],
  ['--title-format','-f',   GetoptLong::REQUIRED_ARGUMENT],
  ['--weeks',       '-w',   GetoptLong::REQUIRED_ARGUMENT]
)

date = '2010-09-06'
title_format = '#{name}'
weeks = 14

# Parse arguments

opts.each do |opt, arg|
  case opt
    when '--date'
      date = arg
    when '--title-format'
      title_format = arg
    when '--weeks'
      weeks = arg.to_i
  end
end

input_fn = ARGV[0]
output_fn = ARGV[1]

if !input_fn
  puts Help
  exit 1
end

# Load html

begin
  input = File.new(input_fn)
rescue
  puts "Can\'t open file #{input_fn} for reading"
  exit 2
end

# Find the line with the table (yes, it's in a single line)

while line = input.gets
  if line.index('TimeTable_Data')
    str = line
    break
  end
end

if !str
  puts 'Can\'t find data row in input file'
  exit 3
end

# Parse html table into Course objects

matches = str.scan(RowPattern)

courses = []
for match in matches
  courses << Course.new(match[3], match[4], match[1], match[2], match[0], match[5], match[6], date)
end

# Create calendar

cal = Calendar.new

for course in courses
  event = cal.event

  event.dtstart = DateTime.parse(course.start_time.to_s)
  event.dtend = DateTime.parse(course.end_time.to_s)

  sum = title_format.gsub('#{name}', course.name)
  sum = sum.gsub('#{location}', course.location)
  sum = sum.gsub('#{code}', course.code)
  event.summary = sum

  event.location = course.location

  if course.freq == 2     # every week
    event.recurrence_rules = ["FREQ=WEEKLY;COUNT=#{weeks}"]
  else                    # every two weeks
    event.recurrence_rules = ["FREQ=WEEKLY;INTERVAL=2;COUNT=#{(weeks/2).to_i}"]
  end
end

if output_fn
  output = File.new(output_fn, 'w')
  output.write(cal.to_ical)
else
  puts cal.to_ical
end

