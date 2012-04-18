#!/usr/bin/env ruby
require 'optparse'
require 'json'
require 'pp'

module RallyClock
  CONFIG = File.join(ENV['HOME'], '.rallyclockrc')
  PROJECT_CONFIG = File.join(ENV['PWD'], '.rallyclockrc')
  METHODS = ['ping', 'auth', 'set-project', 'signup', 'whoami', 'projects', 'log', 'entry', 'create', 'edit', 'find-git-logs']
  
  class CLI
    def initialize(args)
      @args = args
    end

    def self.process!(args)
      c = new(args)
      c.parse
      c.run
    end

    def parse
      help = {
        token: "RallyClock api key",
        username: "your registered username",
        password: "your registered password",
        email: "your registered email",
        url: "base url of the RallyClock server, e.g. 'http://rallyclock.com'",
        from: "YYYY-MM-DD, returns entries starting from this date onwards. use with 'to' to filter",
        to: "YYYY-MM-DD, returns entries up 'till this date. use with 'from' to filter",
        id: "returns the given entry by id",
        note: "detail your activity for an entry",
        date: "YYYY-MM-DD, defaults to today's date",
        time: "XhXXm, time to be entered",
        code: "the project's code",
        handle: "the group's handle",
        account: "the client's account id",
        prompt: "review entries before submission to server",
        by: "your name/email as it appears on git logs"
      }

      @options = {}
      
      if File.exists? CONFIG
        File.open(CONFIG, 'r') do |file|
          file.readlines.each do |line|
            key,value = line.chomp.split(':',2)
            @options[key.intern] = value
          end
        end
      end

      if File.exists? PROJECT_CONFIG
        File.open(PROJECT_CONFIG, 'r') do |file|
          file.readlines.each do |line|
            key,value = line.chomp.split(':',2)
            @options[key.intern] = value
          end
        end
      end
      
      op = OptionParser.new do |opts|
        executable_name = File.basename($PROGRAM_NAME)
        opts.banner = (<<-USAGE)
    Usage: #{executable_name} [command] [args]
    Commands:           Required Args:
      ping
      signup            url, username, email, password
      whoami
      auth              url, username, password
      set-project       handle, code
      projects 
      log               from, to
      entry             id
      create            note, time
      edit              id
      USAGE

        opts.on("-x=TOKEN", "--token", help[:token]) do |token|
          @options[:token] = token
        end

        opts.on("-l=URL", "--url", help[:url]) do |url|
          @options[:url] = url
        end

        opts.on("-u=USERNAME", "--username", help[:username]) do |username|
          @options[:username] = username
        end
        
        opts.on("-e=EMAIL", "--email", help[:email]) do |email|
          @options[:email] = email
        end

        opts.on("-p=PASSWORD", "--password", help[:password]) do |password|
          @options[:password] = password
        end
        
        opts.on("-d=DATE", "--date", help[:date]) do |date|
          @options[:date] = date.gsub('-','')
        end

        opts.on("--from=FROM", help[:from]) do |from|
          @options[:from] = from.gsub('-','')
        end
        
        opts.on("--to=TO", help[:to]) do |to|
          @options[:to] = to.gsub('-','')
        end
        
        opts.on("-i=ID", "--id", help[:id]) do |id|
          @options[:id] = id
        end
        
        opts.on("-p=CODE", "--project", help[:code]) do |code|
          @options[:code] = code
        end
        
        opts.on("--group=HANDLE", help[:handle]) do |handle|
          @options[:handle] = handle
        end

        opts.on("--client=ACCOUNT", help[:account]) do |account|
          @options[:account] = account
        end
        
        opts.on("-t=TIME", "--time", help[:time]) do |time|
          @options[:time] = hm_to_m(time)
        end
        
        opts.on("-m=MESSAGE", "--message", help[:note]) do |note|
          @options[:note] = note
        end

        opts.on("--by=BY", help[:by]) do |by|
          @options[:by] = by
        end

        opts.on("--prompt", help[:prompt]) do |prompt|
          @options[:prompt] = true
        end
      end

      @method = @args.first
      @method && !@args.include?("-h") ? op.parse!(@args) : op.parse!(["--help"])
    end

    def run
      if METHODS.include? @method
        send(@method.gsub('-','_').to_sym)
      elsif @method != "--help"
        puts "Unknown command #{@method}."
      end
    end

    def ping
      resp = `curl -s #{@options[:url]}/api/v1/system/ping`
      puts resp
    end

    def auth
      resp = `curl -s -X POST #{@options[:url]}/api/v1/sessions -H 'X_USERNAME: #{@options[:username]}' -H 'X_PASSWORD: #{@options[:password]}'`
      content = JSON.parse(resp)
      if content["api_key"]
        File.open(CONFIG, 'w') do |file|
          file.puts "url:#{@options[:url]}"
          file.puts "username:#{content["username"]}"
          file.puts "email:#{content["email"]}"
          file.puts "token:#{content["api_key"]}"
          file.puts "handle:#{@options[:handle]}" if @options[:handle]
        end
        puts "created #{CONFIG}"
      elsif content["error"]
        puts "Server sent error: \n" + content["error"]
      else
        puts "Failed to retrieve api key, and the server sent no error message. Make sure the URL is correct."
      end
    rescue
      puts "Failed to retrieve api key, and the server sent no error message. Make sure the URL is correct."
    end

    def whoami
      resp = `curl -s #{@options[:url]}/api/v1/me?t=#{@options[:token]}`
      output(resp)
    end

    def signup
      params = "email=#{@options[:email]}&password=#{@options[:password]}&username=#{@options[:username]}"
      resp = `curl -d "#{params}" #{@options[:url]}/api/v1/users`
      output(resp)
    end

    def projects
      resp = `curl -s #{@options[:url]}/api/v1/me/projects?t=#{@options[:token]}`
      output(resp)
    end
    
    def log 
      resp = if @options[:from] and @options[:to]
               `curl -s '#{@options[:url]}/api/v1/me/entries?t=#{@options[:token]}&from=#{@options[:from]}&to=#{@options[:to]}'`
             elsif @options[:from]
               `curl -s '#{@options[:url]}/api/v1/me/entries?t=#{@options[:token]}&from=#{@options[:from]}'`
             elsif @options[:to]
               `curl -s '#{@options[:url]}/api/v1/me/entries?t=#{@options[:token]}&to=#{@options[:to]}'`
             else
               `curl -s #{@options[:url]}/api/v1/me/entries?t=#{@options[:token]}`
             end
      output(resp)
    end
    
    def entry
      resp = `curl -s #{@options[:url]}/api/v1/me/entries/#{@options[:id]}?t=#{@options[:token]}`
      output(resp)
    end

    def create
      if @options[:prompt]
        puts <<-INFO
About to create time entry with
--
time:       #{@options[:time]}m
message:    #{@options[:note]}
group:      #{@options[:handle]}
client:     #{@options[:account]}
project:    #{@options[:code]}
--

enter 'y' to confirm:
        INFO
        prompt = $stdin.gets.chomp
        unless prompt =~ /y/
          puts "aborted"
          return
        end
      end
      resp = `curl -s '#{@options[:url]}/api/v1/#{@options[:handle]}/clients/#{@options[:account]}/projects/#{@options[:code]}/entries?t=#{@options[:token]}' -d "entry[time]=#{@options[:time]}&entry[note]=#{@options[:note]}&#{maybe(:date)}"`
      output(resp, ['id'], "created time entry with")
    end

    def edit
      resp = `curl -s -X PUT #{@options[:url]}/api/v1/me/entries/#{@options[:id]}?t=#{@options[:token]} -d "#{maybe(:time, :date, :note)}"`
      output(resp)
    end

    def find_git_logs
      # get all logs
      logs = `git log`.split(/commit [a-z0-9]*$/)

      # filter
      me   = @options[:by]
      time = @options[:date] ? Time.new(*@options[:date].split("-")) : Time.now
      logs.select!{|l| l =~ /#{me || '.'}/ && l =~ /#{time.strftime("%b %d")}/ }

      # let user edit results
      if logs.empty?
        puts "No commits found."
      else
        # open a vim window with all the commits
        temp_path = "/tmp/git-logs-#{Process.pid}"
        File.open(temp_path, 'w') {|f| f.puts logs }
        system "#{ENV['EDITOR']} #{temp_path}"
        message = File.read(temp_path)
        system "rm #{temp_path}"

        # for now, just print
        puts "*********************************\n"
        puts message.chomp
        puts "\n*********************************"
      end 
    end

    def maybe(*keys)
      args = keys.map do |k|
        @options[k] ? "entry[#{k}]=#{@options[k]}" : ""
      end

      args.reject(&:empty?).join('&')
    end

    def hm_to_m(hm)
      hours = hm[/(\d+)h/, 1].to_i
      minutes = hm[/(\d+)m/, 1].to_i
      (hours > 0 ? 60 * hours : hours) + minutes
    end

    def m_to_hm(m)
      hours = m.to_i / 60
      minutes = m.to_i % 60
      "#{hours}h#{minutes}m"
    end

    def output(resp, cols=[], msg=nil)
      content = JSON.parse(resp)
      if content.is_a? Hash and content['error']
        pp content['error']
      else
        puts msg if msg
        if content.is_a?(Array) && content.first.is_a?(Hash)
          puts "\n--\n\n"
          puts format_array_of_hashes(content, cols)
        else
          puts format_hash(content, cols)
        end
      end
    rescue => e
      puts e.message + " : '" + resp + "'"
    end

    def format_array_of_hashes(array, cols_for_hash=[])
      array.map! do |a|
        format_hash(a, cols_for_hash) << "\n\n--\n\n"
      end
    end

    def format_hash(hash, cols=[])
      lines = {}
      hash.each do |key, val|
        val = m_to_hm(val) if key == 'time'
        lines[key] = "%-15s : %s" % [key, val]
      end
      sorted_lines = lines.values
      if cols.any?
        sorted_lines = []
        cols.each do |col|
          sorted_lines << lines[col]
        end
      end

      return sorted_lines.join("\n")
    end

  end
end

RallyClock::CLI.process!(ARGV)
