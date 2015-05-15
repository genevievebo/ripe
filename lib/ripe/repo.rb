require 'active_record'
require 'fileutils'
require_relative 'block'
require_relative 'worker'
require_relative 'worker_controller'
require_relative 'worker_migration'
require_relative 'working_block'
require_relative 'library'
require_relative 'liquid_block'
require_relative 'task'
require_relative 'task_migration'

module Ripe

  ##
  # This class represents a ripe session.  It is similar to the concept of a
  # +git+ repository and is the starting point of the package.  It
  # instantiates:
  #
  # * a database that contains all worker metadata; and
  # * a controller that communicates the database with the compute cluster
  #   interface.
  #
  # @see Ripe::WorkerController
  # @see Ripe::Library

  class Repo

    REPOSITORY_PATH = '.ripe'
    DATABASE_PATH   = "#{REPOSITORY_PATH}/meta.db"
    WORKERS_PATH    = "#{REPOSITORY_PATH}/workers"

    attr_reader :controller

    ##
    # Initialize a repository

    def initialize
      @has_repository = File.exists? DATABASE_PATH
      @controller     = WorkerController.new
    end

    ##
    # Return whether the ripe repository exists
    #
    # @return [Boolean] whether the repository exists

    def has_repository?
      @has_repository
    end

    ##
    # Attach to an existing database

    def attach
      ActiveRecord::Base.establish_connection({
        adapter:  'sqlite3',
        database: DATABASE_PATH,
      })
    end

    ##
    # Attach to an existing database, and creates one if none is found.

    def attach_or_create
      @has_repository ? attach : create
    end

    ##
    # Create a database

    def create
      FileUtils.mkdir_p(REPOSITORY_PATH)
      @has_repository = true

      begin
        attach

        # Create the tables
        WorkerMigration.up
        TaskMigration.up
      rescue
        destroy
      end
    end

    ##
    # Destroy the ripe repository, including the database and the worker
    # output.

    def destroy
      FileUtils.rm(DATABASE_PATH) if File.exists? DATABASE_PATH
      FileUtils.rm(WORKERS_PATH)  if Dir.exists?  WORKERS_PATH
    end

  end

end
