require 'spec_helper'

require 'net/ber'
require 'net/ldap'

describe "BER encoding of" do
  
  RSpec::Matchers.define :properly_encode_and_decode do 
    match do |given|
      given.to_ber.read_ber.should == given
    end
  end
   
  context "arrays" do
    it "should properly encode/decode []" do
      [].should properly_encode_and_decode
    end 
    it "should properly encode/decode [1,2,3]" do
      ary = [1,2,3]
      encoded_ary = ary.map { |el| el.to_ber }.to_ber
      
      encoded_ary.read_ber.should == ary
    end 
  end
  context "booleans" do
    it "should encode true" do
      true.to_ber.should == "\x01\x01\x01"
    end
    it "should encode false" do
      false.to_ber.should == "\x01\x01\x00"
    end
  end
  context "numbers" do
    # Sample based
    {
      0           => raw_string("\x02\x01\x00"),
      1           => raw_string("\x02\x01\x01"),
      127         => raw_string("\x02\x01\x7F"),
      128         => raw_string("\x02\x01\x80"),
      255         => raw_string("\x02\x01\xFF"),
      256         => raw_string("\x02\x02\x01\x00"),
      65535       => raw_string("\x02\x02\xFF\xFF"),
      65536       => raw_string("\x02\x03\x01\x00\x00"),
      16_777_215  => raw_string("\x02\x03\xFF\xFF\xFF"),
      0x01000000  => raw_string("\x02\x04\x01\x00\x00\x00"),
      0x3FFFFFFF  => raw_string("\x02\x04\x3F\xFF\xFF\xFF"),
      0x4FFFFFFF  => raw_string("\x02\x04\x4F\xFF\xFF\xFF"),

      # Some odd samples...
      5           => raw_string("\002\001\005"),
      500         => raw_string("\002\002\001\364"),
      50_000      => raw_string("\x02\x02\xC3P"),
      5_000_000_000  => raw_string("\002\005\001*\005\362\000")
    }.each do |number, expected_encoding|
      it "should encode #{number} as #{expected_encoding.inspect}" do
        number.to_ber.should == expected_encoding
      end
    end

    # Round-trip encoding: This is mostly to be sure to cover Bignums well.
    context "when decoding with #read_ber" do
      it "should correctly handle powers of two" do
        100.times do |p|
          n = 2 << p
          
          n.should properly_encode_and_decode
        end
      end 
      it "should correctly handle powers of ten" do
        100.times do |p|
          n = 5 * 10**p
          
          n.should properly_encode_and_decode
        end
      end 
    end
  end
  if "Ruby 1.9".respond_to?(:encoding)
    context "strings" do
      it "should properly encode UTF-8 strings" do
        "\u00e5".force_encoding("UTF-8").to_ber.should ==
          raw_string("\x04\x02\xC3\xA5")
      end
      it "should properly encode strings encodable as UTF-8" do
        "teststring".encode("US-ASCII").to_ber.should == "\x04\nteststring"
      end
			it "should properly encode binary data strings using to_ber_bin" do
				# This is used for searching for GUIDs in Active Directory
				["6a31b4a12aa27a41aca9603f27dd5116"].pack("H*").to_ber_bin.should == 
					raw_string("\x04\x10" + "j1\xB4\xA1*\xA2zA\xAC\xA9`?'\xDDQ\x16")
			end
      it "should not fail on strings that can not be converted to UTF-8" do
        error = Encoding::UndefinedConversionError
        lambda {"\x81".to_ber }.should_not raise_exception(error)
      end
    end
  end
end

describe "BER decoding of" do
  context "numbers" do
    it "should decode #{"\002\001\006".inspect} (6)" do
      "\002\001\006".read_ber(Net::LDAP::AsnSyntax).should == 6
    end
    it "should decode #{"\004\007testing".inspect} ('testing')" do
      "\004\007testing".read_ber(Net::LDAP::AsnSyntax).should == 'testing'
    end
    it "should decode an ldap bind request" do
      "0$\002\001\001`\037\002\001\003\004\rAdministrator\200\vad_is_bogus".
        read_ber(Net::LDAP::AsnSyntax).should ==
          [1, [3, "Administrator", "ad_is_bogus"]]
    end 
  end
end

describe Net::BER::BerIdentifiedString do
  describe "initialize" do
    subject { Net::BER::BerIdentifiedString.new(data) }

    context "binary data" do
      let(:data) { ["6a31b4a12aa27a41aca9603f27dd5116"].pack("H*").force_encoding("ASCII-8BIT") }

      its(:valid_encoding?) { should be_true }
      specify { subject.encoding.name.should == "ASCII-8BIT" }
    end

    context "ascii data in UTF-8" do
      let(:data) { "some text".force_encoding("UTF-8") }

      its(:valid_encoding?) { should be_true }
      specify { subject.encoding.name.should == "UTF-8" }
    end

    context "UTF-8 data in UTF-8" do
      let(:data) { ["e4b8ad"].pack("H*").force_encoding("UTF-8") }
      
      its(:valid_encoding?) { should be_true }
      specify { subject.encoding.name.should == "UTF-8" }
    end
  end
end
