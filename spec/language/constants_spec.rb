require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/constants'

describe "Constant lookup rule" do
  it "finds a toplevel constant" do
    Exception.should == ::Exception
  end
  
  it "looks up the static, lexical scope in a class method" do
    ConstantSpecs::A::B::C.number.should == 47
    ConstantSpecs::A::B::C.name.should == "specs"
    ConstantSpecs::A::B::C.place.should == "boston"
  end
  
  it "looks up the static, lexical scope in an instance method" do
    ConstantSpecs::A::B::C.new.number.should == 47
    ConstantSpecs::A::B::C.new.name.should == "specs"
    ConstantSpecs::A::B::C.new.place.should == "boston"
  end
  
  it "looks up the superclass chain" do
    ConstantSpecs::D.new.number.should == 47
    ConstantSpecs::D.number.should == 47
  end
  
  it "isn't influenced by the calling scope" do
    ConstantSpecs::E.new.go.should == 8
  end
  
  it "isn't influenced by the calling scope, in modules" do
    ConstantSpecs::I.new.go.should == ::Exception
  end
  
  it "calls const_missing on the original scope" do
    ConstantSpecs::A::B::C.new.fire_missing.should == :missing!
  end  
end
