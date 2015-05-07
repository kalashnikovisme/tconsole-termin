# -*- coding: utf-8 -*-
require 'minitest'
require 'ansi/code'

module TConsole
  # Turn-like reporter that reads like a spec.
  #
  # Based upon
  # https://github.com/kern/minitest-reporters/blob/master/lib%2Fminitest%2Freporters%2Fbase_reporter.rb and spec_reporter
  class BaseReporter < Minitest::StatisticsReporter
    attr_accessor :tests

    def initialize(options={})
      super($stdout, options)
      self.tests = []
    end

    def add_defaults(defaults)
      self.options = defaults.merge(options)
    end

    # called by our own before hooks
    def before_test(test)
      last_test = tests.last
      if last_test.class != test.class
        after_suite(last_test.class) if last_test
        before_suite(test.class)
      end
    end

    def record(test)
      super
      tests << test
    end

    # called by our own after hooks
    def after_test(test)
    end

    def report
      super
      after_suite(tests.last.class)
    end

    protected

    def after_suite(test)
    end

    def before_suite(test)
    end

    def result(test)
      if test.error?
        :error
      elsif test.skipped?
        :skip
      elsif test.failure
        :fail
      else
        :pass
      end
    end

    def print_colored_status(test)
      if test.passed?
        print(green { pad_mark( result(test).to_s.upcase ) })
      elsif test.skipped?
        print(yellow { pad_mark( result(test).to_s.upcase ) })
      else
        print(red { pad_mark( result(test).to_s.upcase ) })
      end
    end

    def total_time
      super || Time.now - start_time
    end

    def total_count
      options[:total_count]
    end

    def filter_backtrace(backtrace)
      Minitest.filter_backtrace(backtrace)
    end

    def puts(*args)
      io.puts(*args)
    end

    def print(*args)
      io.print(*args)
    end

    def print_info(e, name=true)
      e.message.each_line { |line| print_with_info_padding(line) }

      trace = filter_backtrace(e.backtrace)
      trace.each { |line| print_with_info_padding(line) }
    end
  end

  module RelativePosition
    TEST_PADDING = 2
    TEST_SIZE = 63
    MARK_SIZE = 5
    INFO_PADDING = 8

    private

    def print_with_info_padding(line)
      puts pad(line, INFO_PADDING)
    end

    def pad(str, size = INFO_PADDING)
      ' ' * size + str
    end

    def pad_mark(str)
      "%#{MARK_SIZE}s" % str
    end

    def pad_test(str)
      pad("%-#{TEST_SIZE}s" % str, TEST_PADDING)
    end
  end

  class MinitestReporter < BaseReporter
    include ANSI::Code
    include RelativePosition
    attr_accessor :tc_results
    attr_accessor :current_element_id

    def initialize(*args)
      @current_element_id = 0
      @tc_results = TConsole::TestResult.new
      super
    end

    def start # not used
      #super
    end

    def ready
      #super
      self.start_time = Time.now
    end

    def report
      super
      puts('Finished in %.5fs' % total_time)
      res_str = '%d tests, ' % [count]
      res_str += '%d assertions, ' % assertions
      passed = count - (failures + errors + skips)
      res_str += green { '%d passed, ' } % passed
      color = failures.zero? && errors.zero? ? :green : :red
      res_str += send(color) { '%d failures, %d errors, ' } % [failures, errors]
      res_str += yellow { '%d skips' } % skips
      puts(res_str)
      if failures == 0 && errors == 0
        puts
        puts(green { "All tests passed! You are good!" })
      end
      puts
    end

    def record(test)
      super
      # TODO хорошо бы избавиться от @current_element_id
      str = "#{::Termin::ANSIColor.magenta(@current_element_id)} #{colored_string(test.name, test)}"
      print pad_test(str)
      print_colored_status(test)
      print(" (%.2fs)" % test.time)
      print()
      puts
      if !test.skipped? && test.failure
        @tc_results.failures << @current_element_id
        print_info(test.failure)
        puts
      end
    end

    protected

    def colored_string(str, test)
      if test.passed?
        ::Termin::ANSIColor.green(str)
      elsif test.skipped?
        ::Termin::ANSIColor.yellow(str)
      else
        ::Termin::ANSIColor.red(str)
      end
    end

    def before_suite(suite)
      puts suite
    end

    def after_suite(suite)
      puts
    end
  end
end
