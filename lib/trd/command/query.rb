
module TRD
module Command

  def query
    op = cmd_opt 'query', :sql

    op.banner << "\noptions:\n"

    db_name = nil
    op.on('-d', '--database DB_NAME', 'use the database') {|s|
      db_name = s
    }

    wait = false
    op.on('-w', '--wait', 'wait for finishing the job', TrueClass) {|b|
      wait = b
    }

    sql = op.cmd_parse

    conf = cmd_config
    api = cmd_api(conf)

    if db_name
      find_database(api, db_name)
    end

    job = api.query(sql, db_name)

    $stderr.puts "Job #{job.job_id} is started."
    $stderr.puts "Use '#{$prog} job #{job.job_id}' to show the status."
    $stderr.puts "See #{job.url} to see the progress."

    if wait && !job.finished?
      wait_job(job)
      puts "Status     : #{job.status}"
      puts "Result     :"
      puts cmd_render_table(job.result, :max_width=>10000)
    end
  end

  def show_jobs
    op = cmd_opt 'show-jobs', :max?, :from?
    max, from = op.cmd_parse

    max = (max || 20).to_i
    from = (from || 0).to_i

    conf = cmd_config
    api = cmd_api(conf)

    jobs = api.jobs(from, from+max-1)

    rows = []
    jobs.each {|job|
      start = job.start_at
      finish = job.end_at
      if start
        if !finish
          finish = Time.now.utc
        end
        e = finish.to_i - start.to_i
        elapsed = ''
        if e > 3600
          elapsed << "#{e/3600}h "
          e %= 3600
          elapsed << "% 2dm " % (e/60)
          e %= 60
          elapsed << "% 2dsec" % e
        elsif e > 60
          elapsed << "% 2dm " % (e/60)
          e %= 60
          elapsed << "% 2dsec" % e
        else
          elapsed << "% 2dsec" % e
        end
      else
        elapsed = ''
      end
      elapsed = "% 10s" % elapsed  # right aligned

      rows << {:JobID => job.job_id, :Status => job.status, :Query => job.query.to_s, :Start => start, :Elapsed => elapsed}
    }

    puts cmd_render_table(rows, :fields => [:JobID, :Status, :Start, :Elapsed, :Query])
  end

  def job
    op = cmd_opt 'job', :job_id

    op.banner << "\noptions:\n"

    verbose = nil
    op.on('-v', '--verbose', 'show logs', TrueClass) {|b|
      verbose = b
    }

    wait = false
    op.on('-w', '--wait', 'wait for finishing the job', TrueClass) {|b|
      wait = b
    }

    job_id = op.cmd_parse

    conf = cmd_config
    api = cmd_api(conf)

    job = api.job(job_id)

    puts "JobID      : #{job.job_id}"
    puts "URL        : #{job.url}"
    puts "Status     : #{job.status}"
    puts "Query      : #{job.query}"

    if wait && !job.finished?
      wait_job(job)
      puts "Result     :"
      puts cmd_render_table(job.result, :max_width=>10000)

    else
      if job.finished?
        puts "Result     :"
        puts cmd_render_table(job.result, :max_width=>10000)
      end

      if verbose
        puts ""
        puts "cmdout:"
        job.debug['cmdout'].to_s.split("\n").each {|line|
          puts "  "+line
        }
        puts ""
        puts "stderr:"
        job.debug['stderr'].to_s.split("\n").each {|line|
          puts "  "+line
        }
      end
    end

    $stderr.puts "Use '-v' option to show detailed messages." unless verbose
  end

  private
  def wait_job(job)
    $stderr.puts "running..."

    cmdout_lines = 0
    stderr_lines = 0

    until job.finished?
      sleep 2

      job.update_status!

      cmdout = job.debug['cmdout'].to_s.split("\n")[cmdout_lines..-1] || []
      stderr = job.debug['stderr'].to_s.split("\n")[stderr_lines..-1] || []
      (cmdout + stderr).each {|line|
        puts "  "+line
      }
      cmdout_lines += cmdout.size
      stderr_lines += stderr.size
    end
  end
end
end

