#!/usr/bin/ruby
#
# = calendar.rb - extension class for the use of Google Calendar
# by way of the ruby GData library.
#
# Author: Christopher Kruse <christopher.kruse@clarke.edu>
#
# Liscensing for the GData API under the Apache Liscense, version 2.0.
#
#
require 'gdata/client'
require 'rubygems'
require 'builder'
require 'rexml/document'

module GData
  class Calendar < GData::Client
    def initialize
      super 'cl', 'gdata-ruby', 'www.google.com'
      @gsessionid = ""
    end
    CAL_PATH = "/calendar/feeds/default/allcalendars/full?gsessionid=#{@gsessionid}"
    def retrieve_calendar_list
    	if authenticated?
          cal_feed = get('calendar/feeds/default/allcalendars/full')
	  @gsessionid = cal_feed[0].get_fields("location")[0].split("gsessionid").last
	  cal_feed = get(cal_feed[0].get_fields("location"))
	  return cal_feed
	else puts "Not authenticated."
      end
    end
  end
end

