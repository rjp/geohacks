#! /usr/bin/env ruby

# sqlite schema for moostrax-backup.rb
# CREATE TABLE history (ts timestamp, latitude real, longitude real, altitude real, speed real, accuracy real, heading real, device integer, battery real);
# CREATE TABLE last_fetch (ts timestamp, device integer);

require 'rubygems'
require 'moostrax'
require 'time'
require 'dbi'

# easier than loading them from json/whatnot
require '~/.apikeys.rb'

$dbh = DBI.connect('DBI:sqlite3:/home/rjp/.moostrax.db', '', '')
$dbh['AutoCommit'] = false
$savepoint = $dbh.prepare("insert into history values (?,?,?,?,?,?,?,?,?)")
$update_fetch = $dbh.prepare("update last_fetch set ts=? where device=?")

mt = MoosTrax.new($apikeys[:moostrax])

now = Time.now
# this is silly, why can't I just set the hour/min/sec to 00?
midnight = Time.parse(now.strftime('%Y-%m-%d 00:00:00'))

devices = mt.devices

# iterate history over each device individually
devices.each do |device|
    puts "select ts from last_fetch where device=#{device}"
    maxdate = $dbh.select_one("select max(ts) from last_fetch where device=?", device)
    p maxdate
    start = Time.parse(maxdate[0])

    while start < midnight do # never start fetching today's records
        day_from = start
        # never cross today's boundary
        day_to = [start + 86399, midnight].max
        loop do
		    puts "D#{device} from #{day_from} to #{day_to} (#{now})"
		    history = mt.history(device, day_from, day_to)
    p history
		    if history.length > 0 then
			    $dbh.transaction do
				    history.each do |point|
				        $savepoint.execute(point['date'], point['latitude'], point['longitude'], point['altitude'], point['speed'], point['accuracy'], point['heading'], point['device_id'],point['battery'])
				    end
	            end
	            day_to = Time.parse(history[-1]['date'])-1
            else
                break
		    end
            sleep 5
        end
        start = start + 86400
        $update_fetch.execute(start, device)
        sleep 5
    end
end
