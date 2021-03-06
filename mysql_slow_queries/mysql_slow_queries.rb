require "time"
require "digest/md5"

# MySQL Slow Queries Monitoring plug in for scout.
# Created by Robin "Evil Trout" Ward for Forumwarz, based heavily on the Rails Request
# Monitoring Plugin.
#
# See: http://blog.forumwarz.com/2008/5/27/monitor-slow-mysql-queries-with-scout
#

class ScoutMysqlSlow < Scout::Plugin
  needs "elif"
  
  def build_report
    log_file_path = option("mysql_slow_log").to_s.strip
    if log_file_path.empty?
      return error( "A path to the MySQL Slow Query log file wasn't provided.",
                    "The full path to the slow queries log must be provided. Learn more about enabling the slow queries log here: http://dev.mysql.com/doc/refman/5.1/en/slow-query-log.html" )
    end

    slow_query_count = 0
    slow_queries = []
    sql = []
    last_run = memory(:last_run) || Time.now
    current_time = Time.now
    Elif.foreach(log_file_path) do |line|
      if line =~ /^# Query_time: (\d+) .+$/
        query_time = $1.to_i
        slow_queries << {:time => query_time, :sql => sql.reverse}
        sql = []
      elsif line =~ /^\# Time: (.*)$/
        t = Time.parse($1) {|y| y < 100 ? y + 2000 : y}
        
        t2 = last_run
        if t < t2
          break
        else
          slow_queries.each do |sq|
            slow_query_count +=1
            # calculate importance
            importance = 0
            importance += 1 if sq[:time] > 3
            importance += 1 if sq[:time] > 10
            importance += 1 if sq[:time] > 30
            parsed_sql = sq[:sql].join
            hint(:title => "#{sq[:time]} sec Query: #{parsed_sql[0..80]}...",
                 :additional_info => sq[:sql],
                 :token => Digest::MD5.hexdigest("slow_query_#{parsed_sql.size > 250 ? parsed_sql[0..250] + '...' : parsed_sql}"),
                 :importance=> importance,
                 :tag_list=>'slow')
          end
        end
        
      elsif line !~ /^\#/
        sql << line
      end
    end  

    elapsed_seconds = current_time - last_run
    logger.info "Current Time: #{current_time}"
    logger.info "Last run: #{last_run}"
    logger.info "Elapsed: #{elapsed_seconds}"
    elapsed_seconds = 1 if elapsed_seconds < 1
    logger.info "Elapsed after min: #{elapsed_seconds}"
    logger.info "count: #{slow_query_count}"
    # calculate per-second
    report(:slow_queries => slow_query_count/(elapsed_seconds/60.to_f))
    
    remember(:last_run,Time.now)
  end
end
