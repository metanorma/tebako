# frozen_string_literal: true

# Copyright (c) 2023 [Ribose Inc](https://www.ribose.com).
# All rights reserved.
# This file is a part of tebako
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

require_relative "tebako/version"

# Tebako - an executable packager
# Implementation of tebako error class and some support methods
module Tebako
  # Tebako error class
  class TebakoError < StandardError
    def initialize(msg = "Unspecified error", code = 255)
      @error_code = code
      super(msg)
    end
    attr_accessor :error_code
  end

  # TebakoCli helper functions
  module CliHelpers
    def b_env
      u_flags = if RbConfig::CONFIG["host_os"] =~ /darwin/
                  "-DTARGET_OS_SIMULATOR=0 -DTARGET_OS_IPHONE=0  #{ENV.fetch("CXXFLAGS", nil)}"
                else
                  ENV.fetch("CXXFLAGS", nil)
                end
      cc = ENV.fetch("CC", "gcc")
      cxx = ENV.fetch("CXX", "g++")
      @b_env ||= { "CXXFLAGS" => u_flags, "CC" => cc, "CXX" => cxx }
    end

    def cfg_options
      ruby_ver, ruby_hash = extend_ruby_version
      @cfg_options ||=
        "-DCMAKE_BUILD_TYPE=Release -DRUBY_VER:STRING='#{ruby_ver}' -DRUBY_HASH:STRING='#{ruby_hash}' " \
        "-DDEPS:STRING='#{deps}' -G '#{m_files}' -S '#{prefix}' -B '#{output}'"
    end

    # Normally dependencies are fetched and build in deps folder
    # DEPS environment variable is for certain special CI scenarios
    # and should not be used normally
    def deps
      f_deps = ENV.fetch("DEPS", nil)
      @deps ||= if f_deps.nil?
                  File.join(prefix, "deps")
                elsif File.absolute_path?(f_deps)
                  f_deps
                else
                  File.join(prefix, f_deps)
                end
    end

    def l_level
      @l_level ||= if options["log-level"].nil?
                     "error"
                   else
                     options["log-level"]
                   end
    end

    def m_files
      @m_files ||= case RbConfig::CONFIG["host_os"]
                   when /linux/, /darwin/
                     "Unix Makefiles"
                   when /msys/
                     "Ninja"
                   else
                     raise TebakoError.new "#{RbConfig::CONFIG["host_os"]} is not supported yet, exiting", 254
                   end
    end

    def output
      @output ||= File.join(prefix, "output")
    end

    def package
      @package ||= if options["output"].nil?
                     File.join(Dir.pwd, File.basename(options["entry-point"], ".*"))
                   else
                     options["output"]
                   end
    end

    PACKAGING_ERRORS = {
      101 => "'tebako setup' configure step failed",
      102 => "'tebako setup' build step failed",
      103 => "'tebako press' configure step failed",
      104 => "'tebako press' build step failed"
    }.freeze

    def packaging_error(code)
      msg = PACKAGING_ERRORS[code]
      msg = "Unknown packaging error" if msg.nil?
      raise TebakoError.new msg, code
    end

    def prefix
      @prefix ||= if options["prefix"].nil?
                    Dir.pwd
                  else
                    File.absolute_path(options["prefix"])
                  end
    end

    def press_announce
      @press_announce ||= <<~ANN
        Running tebako press at #{prefix}
           Ruby version:            '#{extend_ruby_version[0]}'
           Project root:            '#{options["root"]}'
           Application entry point: '#{options["entry-point"]}'
           Package file name:       '#{package}'
           Loging level:            '#{options["log-level"]}'
      ANN
    end

    def press_options
      @press_options ||=
        "-DROOT:STRING='#{options["root"]}' -DENTRANCE:STRING='#{options["entry-point"]}' " \
        "-DPCKG:STRING='#{package}' -DLOG_LEVEL:STRING='#{options["log-level"]}'"
    end

    RUBY_VERSIONS = {
      "2.7.7" => "e10127db691d7ff36402cfe88f418c8d025a3f1eea92044b162dd72f0b8c7b90",
      "3.0.6" => "6e6cbd490030d7910c0ff20edefab4294dfcd1046f0f8f47f78b597987ac683e",
      "3.1.4" => "a3d55879a0dfab1d7141fdf10d22a07dbf8e5cdc4415da1bde06127d5cc3c7b6",
      "3.2.2" => "96c57558871a6748de5bc9f274e93f4b5aad06cd8f37befa0e8d94e7b8a423bc"
    }.freeze

    def extend_ruby_version
      version = options["Ruby"]
      unless RUBY_VERSIONS.key?(version)
        raise TebakoError.new "Ruby version #{version} is not supported yet, exiting",
                              253
      end

      @extend_ruby_version ||= [version, RUBY_VERSIONS[version]]
    end
  end
end