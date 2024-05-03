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

require "etc"
require "fileutils"
require "pathname"
require "rbconfig"

require_relative "cli_rubies"
require_relative "error"
require_relative "version"

# Tebako - an executable packager
# Command-line interface methods
module Tebako
  # Cli helpers
  module CliHelpers
    def b_env
      u_flags = if RbConfig::CONFIG["host_os"] =~ /darwin/
                  "-DTARGET_OS_SIMULATOR=0 -DTARGET_OS_IPHONE=0  #{ENV.fetch("CXXFLAGS", nil)}"
                else
                  ENV.fetch("CXXFLAGS", nil)
                end
      @b_env ||= { "CXXFLAGS" => u_flags }
    end

    def cfg_options
      ruby_ver, ruby_hash = extend_ruby_version
      # Cannot use 'xxx' as parameters because it does not work in Windows shells
      # So we have to use \"xxx\"
      @cfg_options ||=
        "-DCMAKE_BUILD_TYPE=Release -DRUBY_VER:STRING=\"#{ruby_ver}\" -DRUBY_HASH:STRING=\"#{ruby_hash}\" " \
        "-DDEPS:STRING=\"#{deps}\" -G \"#{m_files}\" -B \"#{output}\" -S \"#{source}\""
    end

    def deps
      @deps ||= File.join(prefix, "deps")
    end

    def fs_current
      fs_current = Dir.pwd
      if RUBY_PLATFORM =~ /msys|mingw|cygwin/
        fs_current, cygpath_res = Open3.capture2e("cygpath", "-w", fs_current)
        Tebako.packaging_error(101) unless cygpath_res.success?
        fs_current.strip!
      end
      @fs_current ||= fs_current
    end

    def l_level
      @l_level ||= if options["log-level"].nil?
                     "error"
                   else
                     options["log-level"]
                   end
    end

    # rubocop:disable Metrics/MethodLength
    def m_files
      # [TODO]
      # Ninja generates incorrect script fot tebako press target -- gets lost in a chain custom targets
      # Using makefiles has negative performance impact so it needs to be fixed
      @m_files ||= case RUBY_PLATFORM
                   when /linux/, /darwin/
                     "Unix Makefiles"
                   when /msys|mingw|cygwin/
                     "MinGW Makefiles"
                   else
                     raise Tebako::Error.new(
                       "#{RUBY_PLATFORM} is not supported yet, exiting",
                       254
                     )
                   end
    end
    # rubocop:enable Metrics/MethodLength

    def output
      @output ||= File.join(prefix, "output")
    end

    def package
      package = if options["output"].nil?
                  File.join(Dir.pwd, File.basename(options["entry-point"], ".*"))
                else
                  options["output"]
                end
      @package ||= if relative?(package)
                     File.join(fs_current, package)
                   else
                     package
                   end
    end

    def prefix
      @prefix ||= if options["prefix"].nil?
                    puts "No prefix specified, using ~/.tebako"
                    File.expand_path("~/.tebako")
                  elsif options["prefix"] == "PWD"
                    Dir.pwd
                  else
                    File.expand_path(options["prefix"])
                  end
    end

    def press_announce
      @press_announce ||= <<~ANN
        Running tebako press at #{prefix}
           Ruby version:            '#{extend_ruby_version[0]}'
           Project root:            '#{root}'
           Application entry point: '#{options["entry-point"]}'
           Package file name:       '#{package}'
           Loging level:            '#{l_level}'
      ANN
    end

    def press_options
      @press_options ||=
        "-DROOT:STRING='#{root}' -DENTRANCE:STRING='#{options["entry-point"]}' " \
        "-DPCKG:STRING='#{package}' -DLOG_LEVEL:STRING='#{options["log-level"]}' "
    end

    def relative?(path)
      Pathname.new(path).relative?
    end

    def root
      @root ||= if relative?(options["root"])
                  File.join(fs_current, options["root"])
                else
                  File.join(options["root"], "")
                end
    end

    def source
      c_path = Pathname.new(__FILE__).realpath
      @source ||= File.expand_path("../../..", c_path)
    end
  end
end
