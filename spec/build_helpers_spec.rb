# frozen_string_literal: true

# Copyright (c) 2024 [Ribose Inc](https://www.ribose.com).
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

require "open3"
require "tebako/build_helpers"

# rubocop:disable Metrics/BlockLength

RSpec.describe Tebako::BuildHelpers do
  describe ".ncores" do
    context "when on macOS" do
      before do
        stub_const("RUBY_PLATFORM", "darwin")
        allow(Open3).to receive(:capture2e).with("sysctl", "-n", "hw.ncpu").and_return(["4", double(exitstatus: 0)])
      end

      it "returns the number of cores" do
        expect(described_class.ncores).to eq(4)
      end
    end

    context "when on Linux" do
      before do
        stub_const("RUBY_PLATFORM", "linux")
        allow(Open3).to receive(:capture2e).with("nproc", "--all").and_return(["8", double(exitstatus: 0)])
      end

      it "returns the number of cores" do
        expect(described_class.ncores).to eq(8)
      end
    end

    context "when the command fails" do
      before do
        allow(Open3).to receive(:capture2e).and_return(["", double(exitstatus: 1)])
      end

      it "returns 4 as a default value" do
        expect(described_class.ncores).to eq(4)
      end
    end
  end

  describe ".run_with_capture" do
    let(:args) { %w[echo hello] }

    context "when the command succeeds" do
      before do
        allow(Open3).to receive(:capture2e).with(*args).and_return(["hello", double(exitstatus: 0)])
      end

      it "prints the command" do
        expect { described_class.run_with_capture(args) }.to output("   ... @ echo hello\n").to_stdout
      end

      it "returns the command output" do
        expect(described_class.run_with_capture(args)).to eq("hello")
      end
    end

    context "when the command fails" do
      before do
        allow(Open3).to receive(:capture2e).with(*args).and_return(["error", double(exitstatus: 1)])
      end

      it "raises an error" do
        expect { described_class.run_with_capture(args) }.to raise_error(Tebako::Error, /Failed to run echo hello/)
      end
    end
  end

  describe ".run_with_capture" do
    let(:args) { %w[echo hello] }

    context "when the command runs successfully" do
      before do
        allow(Open3).to receive(:capture2e).with(*args).and_return(["hello", double(exitstatus: 0)])
      end

      it "runs the command" do
        expect { described_class.run_with_capture(args) }.not_to raise_error
        expect(Open3).to have_received(:capture2e).with(*args)
      end
    end

    context "when the command fails" do
      before do
        allow(Open3).to receive(:capture2e).with(*args).and_return(["error", double(exitstatus: 1)])
        allow($stdout).to receive(:puts)
      end

      it "prints the error output" do
        expect { described_class.run_with_capture(args) }.to raise_error(Tebako::Error, /Failed to run echo hello/)
        expect(Open3).to have_received(:capture2e).with(*args)
        expect($stdout).to have_received(:puts)
      end
    end
  end

  describe "#with_env" do
    let(:build_helper) { described_class }

    before do
      ENV["TEST_ENV_VAR1"] = "original_value1"
      ENV["TEST_ENV_VAR2"] = "original_value2"
    end

    after do
      ENV.delete("TEST_ENV_VAR1")
      ENV.delete("TEST_ENV_VAR2")
      ENV.delete("NEW_ENV")
    end
    it "temporarily sets environment variables" do
      build_helper.with_env("TEST_ENV_VAR" => "temporary_value") do
        expect(ENV.fetch("TEST_ENV_VAR", nil)).to eq("temporary_value")
      end
    end

    it "restores original environment variables after block execution" do
      original_value = ENV.fetch("TEST_ENV_VAR", nil)
      build_helper.with_env("TEST_ENV_VAR" => "temporary_value") do
        # Inside the block, the environment variable should be set to the temporary value
        expect(ENV.fetch("TEST_ENV_VAR", nil)).to eq("temporary_value")
      end
      # Outside the block, the environment variable should be restored to its original value
      expect(ENV.fetch("TEST_ENV_VAR", nil)).to eq(original_value)
    end

    it "handles environment variables that were not originally set" do
      build_helper.with_env("NEW_ENV_VAR" => "new_value") do
        expect(ENV.fetch("NEW_ENV_VAR", nil)).to eq("new_value")
      end
      # Ensure the environment variable is unset after the block
      expect(ENV.fetch("NEW_ENV_VAR", nil)).to be_nil
    end

    it "restores multiple environment variables correctly" do
      original_value1 = ENV.fetch("TEST_ENV_VAR1", nil)
      original_value2 = ENV.fetch("TEST_ENV_VAR2", nil)
      build_helper.with_env("TEST_ENV_VAR1" => "value1", "TEST_ENV_VAR2" => "value2") do
        expect(ENV.fetch("TEST_ENV_VAR1", nil)).to eq("value1")
        expect(ENV.fetch("TEST_ENV_VAR2", nil)).to eq("value2")
      end
      expect(ENV.fetch("TEST_ENV_VAR1", nil)).to eq(original_value1)
      expect(ENV.fetch("TEST_ENV_VAR2", nil)).to eq(original_value2)
    end
  end
end

# rubocop:enable Metrics/BlockLength
