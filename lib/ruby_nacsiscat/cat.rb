#*coding:utf-8*

require 'net/http'
require 'uri'
require 'pp'
require 'logger'

class NCS_ERROR < StandardError ; end
class NCS_RESPONSE_ERROR < NCS_ERROR ; end
class NCS_AUTH_ERROR < NCS_ERROR ; end
class NCS_ARUGUMENT_ERROR < NCS_ERROR ; end

class NACSIS_CAT_MODEL
  def initialize
    @attributes = {}
  end
  
  def method_missing(name, *args)
    attribute = name.to_s
    if attribute =~ /=$/
      @attributes[attribute.chop] = args[0]
    else
      @attributes[attribute]
    end
  end
end

class Book < NACSIS_CAT_MODEL
end

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

  NACSIS_CAT_DB_NAMES = %w(BOOK RECON SERIAL)

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
      @logger.level = ($DEBUG)?(::Logger.const_get((:debug).to_s.upcase)):(::Logger.const_get((:info).to_s.upcase))
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
      res_method, res_handle, res_frame, res_catp_version, res_code, res_phrase = res_status_line.split(" ", 6)
      unless res_method == "GETHANDLE"
        logger.error "GETHANDLE method=#{res_method}"
        raise NCS_RESPONSE_ERROR
      end
      if res_code =~ /^[345]/
        logger.error "GETHANDLE code=#{res_code} phrase=#{res_phrase}"
        raise NCS_RESPONSE_ERROR
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
      res_method, res_handle, res_frame, res_catp_version, res_code, res_phrase = res_status_line.split(" ", 6)
      unless res_method == "RELEASEHANDLE"
        logger.error "RELEASEHANDLE method=#{res_method}"
        raise NCS_RESPONSE_ERROR
      end
      if res_code =~ /^[345]/
        logger.error "RELEASEHANDLE code=#{res_code} phrase=#{res_phrase}"
        raise NCS_RESPONSE_ERROR
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

    logger.debug "SEARCH DBs: #{db_name} ,Query: #{search_object_body}"

    raise NCS_ARUGUMENT_ERROR unless db_name.split(",").any? {|s| NACSIS_CAT_DB_NAMES.index(s)}

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
        res_method, res_handle, res_frame, res_catp_version, res_code, res_phrase = res_status_line.split(" ", 6)
        unless res_method == "SEARCH"
          logger.error "SEARCH method=#{res_method}"
          raise NCS_RESPONSE_ERROR
        end
        if res_code =~ /^[345]/
          logger.error "SEARCH code=#{res_code} phrase=#{res_phrase}"
          raise NCS_RESPONSE_ERROR
        end

        result_count = 0
        record_returned = 0
        next_position = 0

        #puts "++++++++"
        #puts responses
        #puts "--------"
        #pp responses

        # response-header
        if /Result-count:(.*)/ =~ responses[2]
          result_count = $1
          logger.debug "result_count=#{result_count}"
        end
        if /Number-of-records-returned:(.*)/ =~ responses[3]
          record_returned = $1
        end
        if /Next-result-set-position:(.*)/ =~ responses[4]
          next_position = $1
        end
        if result_count == 0
          logger.info "no record."
          return
        end

        # object-header
        if /Content-Length:(.*)/ =~ responses[5]
          content_length = $1
        end
        if /Encoding:(.*)/ =~ responses[6]
          encoding = $1
        end

        # object-body
        record = []
        model = []
        responses[8..-1].each do |s|
          if /^--NACSIS-CATP/ =~ s
            record.push(model) if model.count > 0

            model = []
            next
          end
          model << s
        end

        return record
      }
    rescue NCS_ERROR => ex
      logger.error "error class=#{ex.class} msg=#{ex.message}"
    ensure
      release_handle
    end
  end

  def insert
  end

  def update
  end

  def delete
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
      #logger.debug response.body
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

=begin
ui = YAML.load_file("auth.yml")
#pp ui

cat = NACSIS_CAT_Service.new(ui['user']['catp_url'], ui['user']['user_id'], ui['user']['password'])
#cat.logger.level = ::Logger.const_get((:info).to_s.upcase)

# http://www.nii.ac.jp/CAT-ILL/INFO/newcat/jissou_siyo/bbib.search.html
#search_object = "ISBNKEY=\"4797359985\""
#search_object = "FTITLEKEY=\"新潟\""
search_object = "TITLEKEY=\"新潟\""

cat.search("BOOK", "", "2", "2", 50, 200, 200, search_object)
=end
