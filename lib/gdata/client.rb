#!/usr/bin/ruby
#
# = gdata.rb: Ruby bindings for the Google Data API, for use in 
# stand-alone programs.
#
# Authors: 
# Dion Almaer
# Steve Jenson
# Christopher Kruse <christopher.kruse@clarke.edu>
#
#
# Liscensing for the GData API under the Apache Liscense, version 2.0.
# 
# == Overview
#
# This library provides the basic communication framework for the Google
# Data (GData) API.  The library wraps around the HTTP and XML data that is
# passed between the client and the Google servers.
#
# == Example
#
# require 'gdata'
#
# sample = GData::Client.new('service_name', 'version_information', 'service_url')
# sample.authenticate('username@gmail.com','password')
# sample.get('/samplefeed')
#

require 'net/https'
require 'uri'

module GData

  class CAPTCHAException < StandardError
    attr_reader :token, :url
    def intitialize(captcha_token,captcha_url)
      # Take the captcha token and url - it can be passed along to run the
      # Captcha challenge in whatever means necessary.
      @token = captcha_token
      @url = captcha_url
    end
  end

  class Client
    # URI's that might make this a little easier to handle:
    CLIENTLOGIN_URI = URI.parse('https://www.google.com/accounts/ClientLogin')
    AUTHSUB_URI = URI.parse('https://www.google.com/accounts/AuthSubRequest')
    # It is best to be able to remember what program you're using, so you can
    # check later.
    attr_reader :service, :source, :url, :authenticated
     
    # Creates a new instance of the Client class, which prepares the connection
    # to the service.
    def initialize(service, source, url)
      @service = service
      @source = source
      @url = Net::HTTP.new(url, 80)
      # Put out any debug messages to stderr, so we can see if anything goes
      # awry.
      @url.set_debug_output $stderr
      @authenticated = false
    end

    # Authenticate the user through the Google ClientLogin Authentication
    # interface.  
	# TODO: add a variable to either be 'clientLogin' or 'AuthSub' for the 
	# type of authentication method
    def authenticate(email, passwd)
      req = Net::HTTP::Post.new(CLIENTLOGIN_URI.path)
      req.set_form_data(
  	{'Email' => email,
  	 'Passwd' => passwd,
	 'source' => @source,
	 'service' => @service })
      authsend = Net::HTTP.new(CLIENTLOGIN_URI.host, CLIENTLOGIN_URI.port)
      # Enable SSL encryption to send over HTTPS.
      authsend.use_ssl = true if CLIENTLOGIN_URI.scheme == "https"
      response = authsend.start {|send| send.request(req) }
      # Retrieve the Auth string from the response, so we can check to see what
      # kind of result we've received. 
      response_data = Hash.new
      array = response.body.split(/=|\n/)
      array.each_index{|elem| response_data[array[elem]] = array[elem+1] if elem%2 == 0}
      case response
      # If we don't receive a 200 OK message, check to see if we've received
      # a Captcha request.  If not, then throw an error.
      when Net::HTTPSuccess
	@headers = {
	  'Authorization' => "GoogleLogin auth=#{response_data["Auth"]}",
	  'Content-Type' => 'application/atom+xml'
        }
	@authenticated = true
      when Net::HTTPForbidden
	# Check to see whether or not we've received a Captcha challenge, and
	# raise the CAPTCHAException if we have.
	if response_data['Error'] == 'CaptchaRequired'
	  raise CAPTCHAException.new(response_data['CaptchaToken'],response_data['CaptchaUrl'])
	else
	  response.error!
	end
      else
	response.error!
      end
    end
    
    # TODO: An AuthSub-style authentication procedure will be set up here,
    # for all you naughty little rails programmers. :)
    
    def authenticated?
      @authenticated
    end

    # Sends an HTTP GET request to the url specified in the instantiation of
    # the class.
    def get(path)
      response, data = @url.get(path, @headers)
    end
    alias request get # for compatibility purposes.
    # Sends an HTTP POST request to the url specified in the instantiation of
    # the class.
    def post(path, entry)
      @url.post(path,entry,@headers)
    end
    # Sends an HTTP PUT request to... you get the idea.
    # It contains the 'X-HTTP-Method-Override' line because there are times
    # that firewalls don't play nice with the HTTP PUT request.
    def put(path,entry)
      h = @headers.clone
      h['X-HTTP-Method-Override'] = 'PUT'
      @url.put(path,entry,h)
    end
    # Sends an HTTP DELETE request
    # 'X-HTTP-Method-Override' exists for the same reason as above.
    def delete(path)
      h=@headers.clone
      h['X-HTTP-Method-Override'] = 'DELETE'
      @url.delete(path,h)
    end
  end
end
