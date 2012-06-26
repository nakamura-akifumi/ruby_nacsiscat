#*coding:utf-8*
require 'spec_helper'
require 'ruby_nacsiscat'

describe "NacsisCat " do
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


end

