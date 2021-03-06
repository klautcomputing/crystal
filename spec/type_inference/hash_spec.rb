require 'spec_helper'

describe 'Type inference: hash' do
  it "types empty hash literal of int to double" do
    assert_type(%q(require "prelude"; {} of Int32 => Float64)) { hash_of(int32, float64) }
  end

  it "types non-empty hash literal of int to double" do
    assert_type(%q(require "prelude"; {1 => 1.5})) { hash_of(int32, float64) }
  end

  it "types non-empty typed hash literal of int to double" do
    assert_type(%q(require "prelude"; {1 => 1.5} of Int32 => Float64)) { hash_of(int32, float64) }
  end
end
