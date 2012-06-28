#*coding:utf-8*
require 'spec_helper'
require 'ruby_nacsiscat'
require 'logger'
require 'yaml'

describe "NacsisCat接続 " do
  before(:all) do
    @ui = YAML.load_file(File.expand_path(File.join(File.dirname(__FILE__), "auth.yml")))
  end

  it "newするとインスタンスが作られる" do
    cat = NACSIS_CAT_Service.new("url", "id", "passwd")
    cat.should_not nil
  end

  it "urlはnilではいけない" do
    cat = NACSIS_CAT_Service.new("", "", "")
    proc {
      cat.get_handle
    }.should raise_error(Errno::ECONNREFUSED)
  end

  it "不正なisbnを指定して検索したら結果は0件であること" do
    cat = NACSIS_CAT_Service.new(@ui['user']['catp_url'], @ui['user']['user_id'], @ui['user']['password'])
    search_object = "ISBNKEY=\"978\""
    r = cat.search("BOOK", "", "2", "2", 50, 200, 200, search_object)
    r.should be_nil
  end

  it "isbnを指定して検索したら結果は１件であること" do
    cat = NACSIS_CAT_Service.new(@ui['user']['catp_url'], @ui['user']['user_id'], @ui['user']['password'])
    cat.logger.level = ::Logger.const_get((:debug).to_s.upcase)
    search_object = "ISBNKEY=\"9784873114453\""
    r = cat.search("BOOK", "", "2", "2", 50, 200, 200, search_object)
    r.size.should == 1
  end

  it "titlekeyを指定して検索したら結果は１件以上であること" do
    cat = NACSIS_CAT_Service.new(@ui['user']['catp_url'], @ui['user']['user_id'], @ui['user']['password'])
    #cat.logger.level = ::Logger.const_get((:debug).to_s.upcase)
    search_object = "TITLEKEY=\"新潟\""
    r = cat.search("BOOK", "", "2", "2", 50, 200, 200, search_object)
    r.size.should be >= 1
  end

end

