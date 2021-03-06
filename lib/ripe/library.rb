module Ripe

  ##
  # This singleton class represents a library containing all the components
  # accessible to ripe (tasks and workflows) based on what is contained in the
  # +RIPELIB+ environment variable.

  module Library

    class << self

      ##
      # Provide a list of search paths
      #
      # @return [List] Return the list of search paths

      def paths
        # Prepend the working directory to the list of paths so that the
        # working directory is always looked in first.
        "#{Dir.pwd}/#{Repo::REPOSITORY_PATH}:#{ENV['RIPELIB']}".split(/:/)
      end

      ##
      # Search throughout the library for a task or workflow component by the
      # name of +handle+.  When there is more than one match, give precendence to
      # component whose path is declared first.
      #
      # @param comp [Symbol] Type of component: either +:workflow+ or
      #   +:task+.
      # @param filename [String] Filename of component
      # @return [String, nil] Full path of the component if found, and +nil+
      #   otherwise.
 
      def find(comp, filename)
        search = paths.map do |path|
          file = "#{path}/#{comp}s/#{filename}"
          (File.exists? file) ? file : nil
        end

        search.compact.first
      end

    end

  end

end
