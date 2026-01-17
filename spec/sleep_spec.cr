require "./spec_helper"

describe "Shell2Batch::ShellConverter sleep command" do
  converter = Shell2Batch::ShellConverter.new

  it "converts sleep with integer seconds" do
    result = converter.convert_line("sleep 10")
    result.should eq "timeout /t 10"
  end

  it "converts sleep with seconds suffix" do
    result = converter.convert_line("sleep 10s")
    result.should eq "timeout /t 10"
  end

  it "converts sleep with minutes" do
    result = converter.convert_line("sleep 1m")
    result.should eq "timeout /t 60"
  end

  it "converts sleep with hours" do
    result = converter.convert_line("sleep 1h")
    result.should eq "timeout /t 3600"
  end

  it "converts sleep with fractional seconds" do
    result = converter.convert_line("sleep 0.5")
    result.should eq "timeout /t 0"
  end

  it "converts sleep with fractional seconds and suffix" do
    result = converter.convert_line("sleep 0.5s")
    result.should eq "timeout /t 0"
  end

  it "converts sleep with no arguments" do
    result = converter.convert_line("sleep")
    result.should eq "timeout /t 1"
  end

  it "converts sleep with invalid arguments" do
    result = converter.convert_line("sleep invalid")
    result.should eq "timeout /t 1"
  end
end
