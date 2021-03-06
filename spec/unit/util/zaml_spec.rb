#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/util/monkey_patches'

describe "Pure ruby yaml implementation" do
  {
  7            => "--- 7",
  3.14159      => "--- 3.14159",
  'test'       => "--- test",
  []           => "--- []",
  :symbol      => "--- !ruby/sym symbol",
  {:a => "A"}  => "--- \n  !ruby/sym a: A",
  {:a => "x\ny"} => "--- \n  !ruby/sym a: |-\n    x\n    y" 
  }.each { |o,y|
    it "should convert the #{o.class} #{o.inspect} to yaml" do
      o.to_yaml.should == y
    end
    it "should produce yaml for the #{o.class} #{o.inspect} that can be reconstituted" do
      YAML.load(o.to_yaml).should == o
    end
  }
  #
  # Can't test for equality on raw objects
  {
  Object.new                   => "--- !ruby/object {}",
  [Object.new]                 => "--- \n  - !ruby/object {}",
  {Object.new => Object.new}   => "--- \n  ? !ruby/object {}\n  : !ruby/object {}"
  }.each { |o,y|
    it "should convert the #{o.class} #{o.inspect} to yaml" do
      o.to_yaml.should == y
    end
    it "should produce yaml for the #{o.class} #{o.inspect} that can be reconstituted" do
      lambda { YAML.load(o.to_yaml) }.should_not raise_error
    end
  }

  def set_of_lines(l)
    l.split("\n").sort
  end

  it "should handle references to Array in Hash values correctly" do
    list = [1]
    data = { "one" => list, "two" => list }
    data.to_yaml.should == "--- \n  two: &id001 \n    - 1\n  one: *id001"
    expect { YAML.load(data.to_yaml).should == data }.should_not raise_error
  end

  it "should handle references to Hash in Hash values correctly" do
    hash = { 1 => 1 }
    data = { "one" => hash, "two" => hash }
    # This could still someday fail because the order change would also change which one got the back ref
    set_of_lines(data.to_yaml).should == set_of_lines("--- \n  two: &id001 \n    1: 1\n  one: *id001")
    expect { YAML.load(data.to_yaml).should == data }.should_not raise_error
  end

  it "should handle references to Scalar in Hash" do
    str = "hello"
    data = { "one" => str, "two" => str }
    set_of_lines(data.to_yaml).should == set_of_lines("--- \n  two: hello\n  one: hello")
    expect { YAML.load(data.to_yaml).should == data }.should_not raise_error
  end

  class Zaml_test_class_A
    attr_reader :false,:true
    def initialize
      @false = @true = 7
    end
  end
  it "should not blow up when magic strings are used as field names" do
    data = Zaml_test_class_A.new
    data.to_yaml.should == %Q{--- !ruby/object:Zaml_test_class_A\n  \"false\": 7\n  \"true\": 7}
    expect { 
      r = YAML.load(data.to_yaml)
      r.class.should == data.class
      r.true.should == data.true
      r.false.should == data.false
    }.should_not raise_error
  end

  it "should not blow up on back references inside arrays" do
    s = [1,2]
    data = [s,s]
    data.to_yaml.should == %Q{--- \n  - &id001 \n    - 1\n    - 2\n  - *id001}
    expect { YAML.load(data.to_yaml).should == data }.should_not raise_error
  end

end

