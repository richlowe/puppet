require "puppet/util/plugins"

module Puppet
  module Util
    class CommandLine

      LegacyName = Hash.new{|h,k| k}.update(
        'agent'      => 'puppetd',
        'cert'       => 'puppetca',
        'doc'        => 'puppetdoc',
        'filebucket' => 'filebucket',
        'apply'      => 'puppet',
        'describe'   => 'pi',
        'queue'      => 'puppetqd',
        'resource'   => 'ralsh',
        'kick'       => 'puppetrun',
        'master'     => 'puppetmasterd'
      )

      def initialize( zero = $0, argv = ARGV, stdin = STDIN )
        @zero  = zero
        @argv  = argv.dup
        @stdin = stdin

        @subcommand_name, @args = subcommand_and_args( @zero, @argv, @stdin )
        Puppet::Plugins.on_commandline_initialization(:command_line_object => self)
      end

      attr :subcommand_name
      attr :args

      def appdir
        File.join('puppet', 'application')
      end

      def available_subcommands
        absolute_appdirs = $LOAD_PATH.collect do |x| 
          File.join(x,'puppet','application')
        end.select{ |x| File.directory?(x) }
        absolute_appdirs.inject([]) do |commands, dir|
          commands + Dir[File.join(dir, '*.rb')].map{|fn| File.basename(fn, '.rb')}
        end.uniq
      end

      def usage_message
        usage = "Usage: puppet command <space separated arguments>"
        available = "Available commands are: #{available_subcommands.sort.join(', ')}"
        [usage, available].join("\n")
      end

      def require_application(application)
        require File.join(appdir, application)
      end

      def execute
        if subcommand_name.nil?
          puts usage_message
        elsif available_subcommands.include?(subcommand_name) #subcommand
          require_application subcommand_name
          app = Puppet::Application.find(subcommand_name).new(self)
          Puppet::Plugins.on_application_initialization(:appliation_object => self)
          app.run
        else
          abort "Error: Unknown command #{subcommand_name}.\n#{usage_message}" unless execute_external_subcommand
        end
      end

      def execute_external_subcommand
        external_command = "puppet-#{subcommand_name}"

        require 'puppet/util'
        path_to_subcommand = Puppet::Util.which( external_command )
        return false unless path_to_subcommand

        system( path_to_subcommand, *args )
        true
      end

      def legacy_executable_name
        LegacyName[ subcommand_name ]
      end

      private

      def subcommand_and_args( zero, argv, stdin )
        zero = File.basename(zero, '.rb')

        if zero == 'puppet'
          case argv.first
          when nil;              [ stdin.tty? ? nil : "apply", argv] # ttys get usage info
          when "--help", "-h";         [nil,     argv] # help should give you usage, not the help for `puppet apply`
          when /^-|\.pp$|\.rb$/; ["apply", argv]
          else [ argv.first, argv[1..-1] ]
          end
        else
          [ zero, argv ]
        end
      end

    end
  end
end
