require 'active_record'
require 'fileutils'
require_relative 'subtask'
require_relative 'task'

module Ripe
  class Worker < ActiveRecord::Base
    has_many :tasks, dependent: :destroy
    has_many :subtasks, through: :tasks

    def dir
      ".ripe/#{self.id}"
    end

    def sh
      "#{self.dir}/job.sh"
    end

    def stdout
      "#{self.dir}/job.stdout"
    end

    def stderr
      "#{self.dir}/job.stderr"
    end

    after_create do
      FileUtils.mkdir_p dir # if !Dir.exists? dir
    end

    before_destroy do
      FileUtils.rm_r dir # if Dir.exists? dir
    end

    def self.prepare(samples, callback, vars = {})
      vars = {wd: Dir.pwd}.merge(vars)

      samples.each_slice(vars[:worker_num]).map do |worker_samples|
        worker = Worker.create(handle: vars[:handle])

        blocks = worker_samples.map do |sample|
          task = worker.tasks.create(sample: sample)

          ## Preorder traversal of blocks -- assign incremental numbers starting from
          ## 1 to each node as it is being traversed.
          post_var_assign = lambda do |subblock|
            if subblock.blocks.length == 0
              subtask = task.subtasks.create(block: subblock.id)
              subblock.vars.merge!(log: subtask.log)
            else
              subblock.blocks.each(&post_var_assign)
            end
          end

          block = callback.call(sample)
          post_var_assign.call(block)
          block
        end

        vars = vars.merge({
          name:    worker.id,
          stdout:  worker.stdout,
          stderr:  worker.stderr,
          command: SerialBlock.new(*blocks).command,
        })

        file = File.new(worker.sh, 'w')
        file.puts LiquidBlock.new("#{PATH}/share/moab.sh", vars).command
        file.close

        worker.update({
          status:   :prepared,
          ppn:      vars[:ppn],
          queue:    vars[:queue],
          walltime: vars[:walltime],
        })
        worker
      end
    end

    def self.sync
      lists = {idle: '-i', blocked: '-b', active:  '-r'}
      lists = lists.map do |status, op|
        showq = `showq -u $(whoami) #{op} | grep $(whoami)`.split("\n")
        showq.map do |job|
          {
            moab_id:   job[/^([0-9]+) /, 1],
            remaining: job[/  ([0-9]{1,2}(\:[0-9]{2})+)  /, 1],
            status:    status,
          }
        end
      end

      # Update status
      lists = lists.inject(&:+).each do |job|
        moab_id   = job[:moab_id]
        remaining = job[:remaining]
        status    = job[:status]
        worker    = Worker.find_by(moab_id: moab_id)

        if worker
          worker.update(remaining: remaining)
          if worker.status != 'cancelled'
            checkjob = `checkjob #{moab_id}`
            worker.update({
              host:      checkjob[/Allocated Nodes:\n\[(.*):[0-9]+\]\n/, 1],
              status:    status,
            })
          end
        end
      end

      # Mark workers that were previously in active, blocked or idle as completed
      # if they cannot be found anymore.
      jobs = lists.map { |job| job[:moab_id] }
      Worker.where('status in (:statuses)',
                   :statuses => ['active', 'idle', 'blocked']).each do |worker|
        if jobs.include? worker.moab_id
          jobs.delete(worker.moab_id)
        else
          worker.update({
            remaining: '0',
            status:    :completed,
          })
        end
      end
    end

    def start!
      raise "Worker #{id} could not be started: not prepared" unless self.status == 'prepared'
      start
    end

    def start
      update(status: :idle, moab_id: `msub '#{self.sh}'`.strip)
    end

    def cancel!
      raise "Worker #{id} could not be cancelled: not started" unless ['idle', 'blocked', 'active'].include? self.status
      cancel
    end

    def cancel
      `canceljob #{self.moab_id}`
      update(status: :cancelled)
    end
  end
end