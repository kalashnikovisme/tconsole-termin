# -*- coding: utf-8 -*-
require 'minitest'
module TConsole
  class MiniTestHandler
    attr_accessor :interrupted

    def initialize(config)
      @reporter = ::TConsole::MinitestReporter.new
      @reporter.tc_results.suite_counts = config.cached_suite_counts
      @reporter.tc_results.elements = config.cached_elements
      @interrupted = false
    end

    def match_and_run(match_patterns, config)

      suites = Minitest::Runnable.runnables

      @reporter.ready
      suites.each do |suite|
        suite_id = @reporter.tc_results.elements[suite.to_s]

        suite_printed = false
        suite.methods_matching(/^test/).map do |method|
          if @interrupted
            return @reporter.tc_results
          end

          id = @reporter.tc_results.add_element(suite, method)

          unless match_patterns.nil?
            match = match_patterns.find do |pattern|
              pattern == suite.to_s ||
                pattern == "#{suite.to_s}##{method.to_s}" ||
                pattern == suite_id.to_s ||
                pattern == id
            end
          end

          if !suite_printed && (match_patterns.nil? || match_patterns.empty? || !match.nil?)
            print(::Termin::ANSIColor.cyan, suite, ::Termin::ANSIColor.reset,
                  ::Termin::ANSIColor.magenta, " #{suite_id} \n")
            suite_printed = true
          end

          if match_patterns.nil? || match_patterns.empty? || !match.nil?
            @reporter.current_element_id = id
            # TODO мб понтово свой метод run в минитест захуярить,
            # который список suites принимать будет
            Minitest::Runnable.run_one_method(suite, method, @reporter)
          end
        end

        if suite_printed
          puts
        end
      end

      [@reporter.tc_results, @reporter]
    end

    # Preloads our element cache for autocompletion. Assumes tests are already loaded
    def self.preload_elements
      patch_minitest
      results = TConsole::TestResult.new
      suites = Minitest::Runnable.runnables
      suites.each do |suite|
        suite.methods_matching(/^test/).map do |method|
          id = results.add_element(suite, method)
        end
      end

      results
    end

    # We're basically breaking Minitest autorun here, since we want to manually run our
    # tests and Rails relies on autorun
    # A big reason for the need for this is that we're trying to work in the Rake environment
    # rather than rebuilding all of the code in Rake just to get test prep happening
    # correctly.
    def self.patch_minitest
      Minitest.class_eval do
        class << self
          alias_method :old_run, :run
          def run(args = [])
          end
        end
      end
    end
  end
end

# Make sure that output is only colored when it should be
Termin::ANSIColor::coloring = STDOUT.isatty
