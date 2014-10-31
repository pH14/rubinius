require File.expand_path('../../../spec_helper', __FILE__)
require File.expand_path('../fixtures/classes', __FILE__)

describe "Secure context" do
	it "hooks no return value" do
		x = SecureContextSpecs::TestObject.new
		x.secure_context = SecureContextSpecs::SecureContext.new

		x.secure_context.define_singleton_method(:after_returns_nothing) do |obj, arg|
			obj.should == x
			return "returned string"
		end

		x.returns_nothing.should == "returned string"
	end

	it "hooks single return value" do
		x = SecureContextSpecs::TestObject.new
		x.secure_context = SecureContextSpecs::SecureContext.new

		x.secure_context.define_singleton_method(:after_returns_one_value) do |obj, arg|
			arg.should == 10
			return "returned string"
		end

		x.returns_one_value.should == "returned string"
	end

	it "hooks multiple return values and returns one" do
		x = SecureContextSpecs::TestObject.new
		x.secure_context = SecureContextSpecs::SecureContext.new

		x.secure_context.define_singleton_method(:after_returns_many_values) do |obj, *arg|
			arg.should == [10, "hello", 20, "world", 30]
			return "returned string"
		end

		x.returns_many_values.should == "returned string"
	end

	it "hooks multiple return values and returns many" do
		x = SecureContextSpecs::TestObject.new
		x.secure_context = SecureContextSpecs::SecureContext.new

		x.secure_context.define_singleton_method(:after_returns_many_values) do |obj, *arg|
			arg.should == [10, "hello", 20, "world", 30]
			return "returned string", 10
		end

		x.returns_many_values.should == ["returned string", 10]
	end
end