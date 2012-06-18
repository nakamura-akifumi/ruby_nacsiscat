#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'pp'
require 'logger'
require 'yaml'

class NCS_ERROR < StandardError ; end
class NCS_AUTH_ERROR < StandardError ; end

class NACSIS_CAT_Service
  PLUGIN_VERSION = "0.1"
  AGENT_NAME = "NACSIS_CAT Plugin #{PLUGIN_VERSION} (Ruby/#{RUBY_VERSION})"
  CATP_VERSION = 'CATP/1.1'
  SCHEMA_VERSION = "2"
  HandleAny = "0123456789"
  FrameAny = "000"
  RequestcodeAny = "000"
  REQUEST_PHRASE = "REQUEST"

  CRLF = "\n"
  ENCODING_STR = "Encoding:UTF8"
  SCHEMA_VERSION_STR = "Schema-version: #{SCHEMA_VERSION}"

  NACSIS_CAT_DB = 'BOOK'

  EDIT_TYPES = %w(0 1 2 9)

  attr_reader :handle_id
  attr_reader :cat_url, :user_id, :password
  attr_reader :support_methods 

  attr_accessor :logger

  def initialize(cat_url, user_id, password)
    @cat_url = cat_url
    @user_id = user_id
    @password = password

    logger.debug "cat_url: #{cat_url} user_id=#{user_id}"
  end

  def logger 
    @logger ||= begin
      #@logger = ::Logger.new(self.class.logger_log_file)
      #@logger.level = ::Logger.const_get((self.class.logger_level || :debug).to_s.upcase)
      @logger = ::Logger.new(STDOUT)
      @logger.level = ::Logger.const_get((:debug).to_s.upcase)
      @logger.datetime_format = "%Y-%m-%d %H:%M:%S"
      @logger
    end
  end

  def get_handle
    raise NCS_AUTH_ERROR unless @user_id || @password

    frame_value = ""

    post_request_line = request_line("GETHANDLE")
    post_authentication_info = authentication_info(@user_id, @password)
    post_request_header = post_authentication_info
    post_content_length = "Content-Length: 0"
    post_object_header = [post_content_length, ENCODING_STR, SCHEMA_VERSION_STR].join(CRLF)
    
    post_object = [post_request_line, post_request_header, post_object_header].join(CRLF)

    post(post_object) {|http, response|
      responses = response.body.split(CRLF)    
      res_status_line = responses[0]
      res_method, res_handle, res_frame, res_catp_version, res_code, res_phrase = res_status_line.split(" ")
      unless res_method == "GETHANDLE"
        logger.error "GETHANDLE method=#{res_method}"
        raise NCS_ERROR
      end
      if res_code =~ /^[345]/
        logger.error "GETHANDLE code=#{res_code} phrase=#{res_phrase}"
        raise NCS_ERROR
      end

      @support_methods = responses[1]

      @handle_id = res_handle
      frame_value = res_frame

      logger.info "GetHandle HandleId=#{@handle_id} FrameValue=#{frame_value}"
    }

    return @handle_id, frame_value 
  end

  def release_handle
    logger.info "ReleaseHandle HandleId=#{@handle_id}"
    return unless @handle_id

    post_request_line = "RELEASEHANDLE #{@handle_id} #{FrameAny} #{CATP_VERSION} #{RequestcodeAny} REQUEST"
    post_content_length = "Content-Length: 0"
    post_object_header = [post_content_length, ENCODING_STR, SCHEMA_VERSION_STR].join(CRLF)
    post_object = [post_request_line, post_object_header].join(CRLF)

    post(post_object) {|http, response|
      responses = response.body.split(CRLF)    
      res_status_line = responses[0]
      res_method, res_handle, res_frame, res_catp_version, res_code, res_phrase = res_status_line.split(" ")
      unless res_method == "RELEASEHANDLE"
        logger.error "RELEASEHANDLE method=#{res_method}"
        raise NCS_ERROR
      end
      if res_code =~ /^[345]/
        logger.error "RELEASEHANDLE code=#{res_code} phrase=#{res_phrase}"
        raise NCS_ERROR
      end
    }
    @handle_id = nil

    logger.debug "ReleaseHandle Success"
  end

  def release_frame
  end

  def search(db_name, frame_value, small_set_element_names, medium_set_element_set_names,
             upper_bound, lower_bound, medium_set_present_number,
             search_object_body)

    logger.debug "SEARCH Query: #{search_object_body}"
=begin
    Request = Request-Line　　　
    　　　　　[Request-Header]
    　　　　　Object-Header
    　　　　　CRLF
    　　　　　[Object-Body]
=end

    begin 
      handle, frame_value = get_handle
      logger.debug "SEARCH handle=#{handle} frame=#{frame_value}"

      # see: http://www.nii.ac.jp/CAT-ILL/INFO/newcat/jissou_siyo/jissou.html#edit-type
      post_request_line = "SEARCH #{@handle_id} #{frame_value} #{CATP_VERSION} #{RequestcodeAny} REQUEST"
      post_request_header = ["Database-names: #{db_name}",
        "Small-set-element-set-names: #{small_set_element_names}",
        "Medium-set-element-set-names: #{medium_set_element_set_names}",
        "Small-set-upper-bound: #{upper_bound}",
        "Large-set-lower-bound: #{lower_bound}",
        "Medium-set-present-number: #{medium_set_present_number}"]

      post_object_header = ["Content-Length: #{search_object_body.length}", ENCODING_STR]
      post_object_body = search_object_body
      post_object = [post_request_line, post_request_header, post_object_header, "", post_object_body, ""].join(CRLF)
     
      post(post_object) {|http, response|
        responses = response.body.split(CRLF)    
        res_status_line = responses[0]
        res_method, res_handle, res_frame, res_catp_version, res_code, *res_phrase = res_status_line.split(" ")
        unless res_method == "SEARCH"
          logger.error "SEARCH method=#{res_method}"
          raise NCS_ERROR
        end
        if res_code =~ /^[345]/
          logger.error "SEARCH code=#{res_code} phrase=#{res_phrase.join(' ')}"
          raise NCS_ERROR
        end

      }
    rescue => ex
      logger.error "error class=#{ex.class} msg=#{ex.message}"
    ensure
      release_handle
    end
  end

  private
  def post(body)
    unless block_given?
      logger.error "no block"
      raise
    end

    uri = URI.parse(@cat_url)
    Net::HTTP.start(uri.host, uri.port){|http|
      header = {
        "user-agent" => AGENT_NAME
      }
      response = http.post(uri.path, body, header)
      logger.debug response.body
      yield http, response
    }
  end

  protected
  def request_line(method, handle = HandleAny, frame = FrameAny, request_code = RequestcodeAny, request_phrase = REQUEST_PHRASE)
    "#{method} #{handle} #{frame} #{CATP_VERSION} #{request_code} #{request_phrase}"
  end

  def authentication_info(userid, password)
    "Authenticate: #{userid},#{password}"
  end

end

ui = YAML.load_file("auth.yml")
#pp ui

cat = NACSIS_CAT_Service.new(ui['user']['catp_url'], ui['user']['user_id'], ui['user']['password'])
search_object = "ISBNKEY=\"9784798023809\""

cat.search("BOOK", "", "2", "2", 50, 200, 200, search_object)

#cat.get_handle
#cat.release_handle

