#!/usr/bin/env ruby
#
#

require "json"
require "pp"
require_relative "usbhidcodes"

# The main parse method is mostly borrowed from a tweet by @JEG2
class StrictTsv
  attr_reader :filepath
  def initialize(filepath)
    @filepath = filepath
  end

  def parse
    open(filepath) do |f|
      headers = f.gets.strip.split("\t")
      f.each do |line|
        fields = Hash[headers.zip(line.split("\t"))]
        yield fields
      end
    end
  end

  def parse_to_arrays
    open(filepath) do |f|
      headers = f.gets.strip.split("\t")
      f.each do |line|
        yield line.split("\t")[0,5]
      end
    end
  end
end

# Space - 1 1
# -> (first number is the TAP bit value (bit 0-> thumb))
#     "1":
#     {
#       "hid":getHid("Space"),
#       "unicode":"\\u0045\\u006E\\u0074\\u0065\\u0072",
#       "description":"",
#       "modifiers":0,
#       "hold":false
#     },
#
# $ 4	Ralt	1234	s
# ->
#     "15":
#     {
#       "hid":getHid("4"),
#       "unicode":"\\u00..",
#       "description":"",
#       "modifiers":4,
#       "hold":false
#     },
#

module TapConfig
  extend self

  # return a string formatted as \\u0004\\u0051...
  # one \\u.... for each character in the input string.
  def get_unicode_rep(input_str)
    input_str.chars.map do |c|
      "\\u%4.4x" % c.ord
    end.join()
  end

  # returns a string with the matching hid in decimal
  def get_hid(raw_us_sequence)
#    puts raw_us_sequence
#    "%2d" % USB_HID.key(raw_us_sequence)
    USB_HID.key(raw_us_sequence)
  end

  def get_modifier_value(mod_array)
    if mod_array.nil? || mod_array.empty?
      return 0
    end

    sum = 0
    mod_array = [mod_array] if mod_array.is_a?(String)
    mod_array.each do |mod|
      sum += HID_name_2_dec[mod.downcase]
    end
    sum
  end

  def get_tap_number(finger_str)
    sum = 0
    finger_str.chars.each do |f|
      sum += 2**(f.to_i-1)
    end
    sum
  end

  def create_one_combo(desired_output, raw_us_sequence, mod_array)
    {
        "hid" => TapConfig.get_hid(raw_us_sequence),
        "unicode" => TapConfig.get_unicode_rep(desired_output),
        "description" => "",
        "modifiers" => get_modifier_value(mod_array),
        "hold" => false
    }
  end

  #     "15":
  #     {
  #       "hid":getHid("4"),
  #       "unicode":"\\u00..",
  #       "description":"",
  #       "modifiers":4,
  #       "hold":false
  #     },
  #
  def create_tap_config(input)
    tap_config = {}
    tap_mode = ""
    input.each do |item|
      # item is [Swe Layout,	US Layout,	Modifier,	Tap fingering,	Tap mode]

      # The below is terrible, rewrite this...
      next if item[3].nil? || item[3].empty? || item[3] == "\n"
      next if item[4].nil? || item[4].empty? || item[4] == "\n"
      item[4] = item[4].chomp
      tap_modes = {
          "1" => "singleTap",
          "2" => "doubleTap",
          "3" => "tripleTap",
          "s" => "shift",
          "w" => "switch",
      }
      tap_mode = tap_modes[item[4].downcase]
#      puts "-#{item[4].downcase}- -> tap_mode: #{tap_mode}"
      tap_config[tap_mode] ||= {}
      tap_config[tap_mode][get_tap_number(item[3])] = create_one_combo(*item[0,3])
    end

    # add meta info
    tap_config["layoutId"] = "JMGX6oAZKsODGAEX"
    tap_config["mapStoreVersion"] = 1
    tap_config["layoutVersion"] = 1
    tap_config["layoutName"] = "Easy"
    tap_config["description"] = "test map"
    tap_config
  end
end


if __FILE__ == $PROGRAM_NAME

  input = []
  tsv = StrictTsv.new("egen_easy.csv")
  tsv.parse_to_arrays do |row|
    input << row
  end

  c = TapConfig.create_tap_config(input)
#  pp c
  puts c.to_json.chomp
  # json = File.read("sample.json")
  # tapConfig = JSON.parse(json)
  # pp tapConfig["doubleTap"]

end