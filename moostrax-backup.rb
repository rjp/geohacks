#! /usr/bin/env ruby

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

devices = mt.devices

# iterate history over each device individually
devices.each do |device|
    puts "select ts from last_fetch where device=#{device}"
    maxdate = $dbh.select_one("select max(ts) from last_fetch where device=?", device)
    p maxdate
    start = Time.parse(maxdate[0])

    while start < now do
	    puts "history from #{start} to #{start+86399}"
	    history = mt.history(device, start, start + 86399)
	    p history
	    if history.length > 0 then
	    $dbh.transaction do 
		    history.each do |point|
	# create table history (ts timestamp, latitude real, longitude real, altitude real, speed real, accuracy real, heading real, device integer);
		        $savepoint.execute(point['date'], point['latitude'], point['longitude'], point['altitude'], point['speed'], point['accuracy'], point['heading'], point['device_id'],point['battery'])
		    end
	    end
	    end
	    if history.length == 50 then # possibly full buffer
            start = Time.parse(history[-1]['date'])+1
        else
	        start = start + 86400
    	end
        $update_fetch.execute(start, device)
        sleep 5
    end
end
