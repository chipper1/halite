require "logger"
require "colorize"
require "file_utils"

module Halite
  # Logger feature
  class Logger < Feature
    def self.new(format : String = "common", logger : Logger::Abstract? = nil, **opts)
      return new(logger: logger) if logger
      raise UnRegisterLoggerFormatError.new("Not avaiable logger format: #{format}") unless cls = Logger[format]?

      logger = cls.new(**opts)
      new(logger: logger)
    end

    DEFAULT_LOGGER = Logger::Common.new

    getter writer : Logger::Abstract

    def initialize(**options)
      @writer = options.fetch(:logger, DEFAULT_LOGGER).as(Logger::Abstract)
    end

    def request(request)
      @writer.request(request)
      request
    end

    def response(response)
      @writer.response(response)
      response
    end

    # Logger Abstract
    abstract class Abstract
      def self.new(file : String? = nil, filemode = "a",
                   skip_request_body = false, skip_response_body = false,
                   skip_benchmark = false, colorize = true)
        io = STDOUT
        if file
          file = File.expand_path(file)
          filepath = File.dirname(file)
          FileUtils.mkdir_p(filepath) unless Dir.exists?(filepath)

          io = File.open(file, filemode)
        end
        new(skip_request_body, skip_response_body, skip_benchmark, colorize, io)
      end

      setter logger : ::Logger
      getter skip_request_body : Bool
      getter skip_response_body : Bool
      getter skip_benchmark : Bool
      getter colorize : Bool

      def initialize(@skip_request_body = false, @skip_response_body = false,
                     @skip_benchmark = false, @colorize = true, @io : IO = STDOUT)
        @logger = ::Logger.new(@io, ::Logger::DEBUG, default_formatter, "halite")
        Colorize.enabled = @colorize
      end

      forward_missing_to @logger

      abstract def request(request)
      abstract def response(response)

      def default_formatter
        ::Logger::Formatter.new do |_, datetime, _, message, io|
          io << datetime.to_s << " " << message
        end
      end
    end

    @@formats = {} of String => Abstract.class

    module Register
      def register(name : String, format : Abstract.class)
        @@formats[name] = format
      end

      def [](name : String)
        @@formats[name]
      end

      def []?(name : String)
        @@formats[name]?
      end

      def availables
        @@formats.keys
      end
    end

    extend Register

    Halite.register_feature "logger", self
  end
end

require "./loggers/*"
