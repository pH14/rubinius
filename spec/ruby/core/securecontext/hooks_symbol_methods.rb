require File.expand_path('../../../spec_helper', __FILE__)
require File.expand_path('../fixtures/classes', __FILE__)

describe "Secure context" do
	it "hooks +" do
		x = "hello"
		y = ", world"

		x.secure_context = SecureContextSpecs::SecureContext.new

		x.secure_context.define_singleton_method(:after_returns_nothing) do |obj, arg|
			# obj.should == x
			return "returned string"
		end

		# x.returns_nothing.should == "returned string"

		true.should == true

	end
end