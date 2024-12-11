# frozen_string_literal: true

# Copyright (c) 2023-2024 [Ribose Inc](https://www.ribose.com).
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

require_relative "error"

# Tebako - an executable packager
module Tebako
  # Ruby version checks
  class RubyVersion
    RUBY_VERSIONS = {
      "2.7.8" => "c2dab63cbc8f2a05526108ad419efa63a67ed4074dbbcf9fc2b1ca664cb45ba0",
      "3.0.7" => "2a3411977f2850431136b0fab8ad53af09fb74df2ee2f4fb7f11b378fe034388",
      "3.1.6" => "0d0dafb859e76763432571a3109d1537d976266be3083445651dc68deed25c22",
      "3.2.4" => "c72b3c5c30482dca18b0f868c9075f3f47d8168eaf626d4e682ce5b59c858692",
      "3.2.5" => "ef0610b498f60fb5cfd77b51adb3c10f4ca8ed9a17cb87c61e5bea314ac34a16",
      "3.3.3" => "83c05b2177ee9c335b631b29b8c077b4770166d02fa527f3a9f6a40d13f3cce2",
      "3.3.4" => "fe6a30f97d54e029768f2ddf4923699c416cdbc3a6e96db3e2d5716c7db96a34",
      "3.3.5" => "3781a3504222c2f26cb4b9eb9c1a12dbf4944d366ce24a9ff8cf99ecbce75196"
    }.freeze

    MIN_RUBY_VERSION_WINDOWS = "3.1.6"
    DEFAULT_RUBY_VERSION = "3.2.5"

    # rub_ver version = options["Ruby"].nil? ? DEFAULT_RUBY_VERSION : options["Ruby"]
    def initialize(ruby_version)
      @ruby_version = ruby_version.nil? ? DEFAULT_RUBY_VERSION : ruby_version

      version_check_format
      version_check
      version_check_msys
    end

    attr_reader :ruby_version

    def ruby3x?
      @ruby3x ||= @ruby_version[0] == "3"
    end

    def ruby31?
      @ruby31 ||= ruby3x? && @ruby_version[2].to_i >= 1
    end

    def ruby32?
      @ruby32 ||= ruby3x? && @ruby_version[2].to_i >= 2
    end

    def ruby32only?
      @ruby32only ||= ruby3x? && @ruby_version[2] == "2"
    end

    def ruby33?
      @ruby33 ||= ruby3x? && @ruby_version[2].to_i >= 3
    end

    def api_version
      @api_version ||= "#{@ruby_version.split(".")[0..1].join(".")}.0"
    end

    def lib_version
      @lib_version ||= "#{@ruby_version.split(".")[0..1].join}0"
    end

    def version_check
      return if RUBY_VERSIONS.key?(@ruby_version)

      raise Tebako::Error.new(
        "Ruby version #{@ruby_version} is not supported",
        110
      )
    end

    def version_check_format
      return if @ruby_version =~ /^\d+\.\d+\.\d+$/

      raise Tebako::Error.new("Invalid Ruby version format '#{@ruby_version}'. Expected format: x.y.z", 109)
    end

    def version_check_msys
      if Gem::Version.new(@ruby_version) < Gem::Version.new(MIN_RUBY_VERSION_WINDOWS) &&
         RUBY_PLATFORM =~ /msys|mingw|cygwin/
        raise Tebako::Error.new("Ruby version #{@ruby_version} is not supported on Windows", 111)
      end
    end

    def extend_ruby_version
      @extend_ruby_version ||= [@ruby_version, RUBY_VERSIONS[@ruby_version]]
    end
  end
end
