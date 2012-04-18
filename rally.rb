#!/usr/bin/env ruby
require 'optparse'
require 'json'
require 'pp'

module RallyClock
  CONFIG = File.join(ENV['HOME'], '.rally.rc')
  METHODS = ['ping', 'auth', 'whoami', 'projects', 'entries', 'entry', 'commit', 'edit']
  
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
        date: "defaults to today's date",
        time: "XhXXm, time to be entered",
        code: "the project's code",
        handle: "the group's handle"
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
      
      op = OptionParser.new do |opts|
        executable_name = File.basename($PROGRAM_NAME)
        opts.banner = "Usage: #{executable_name} [command] [args]"

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

        opts.on("-f=FROM", "--from", help[:from]) do |from|
          @options[:from] = from.gsub('-','')
        end
        
        opts.on("-t=TO", "--to", help[:to]) do |to|
          @options[:to] = to.gsub('-','')
        end
        
        opts.on("-i=ID", "--id", help[:id]) do |id|
          @options[:id] = id
        end
        
        opts.on("-c=CODE", "--code", help[:code]) do |code|
          @options[:code] = code
        end
        
        opts.on("-h=HANDLE", "--handle", help[:handle]) do |handle|
          @options[:handle] = handle
        end
        
        opts.on("-k=TIME", "--time", help[:time]) do |time|
          @options[:time] = convert(time)
        end
        
        opts.on("-n=NOTE", "--note", help[:note]) do |note|
          @options[:note] = note
        end
        
        opts.on("-d=DATE", "--date", help[:date]) do |date|
          @options[:date] = date
        end
      end

      @method = @args.first
      @method ? op.parse!(@args) : op.parse!(["-h"])
    end

    def run
      if METHODS.include? @method
        send(@method)
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
      File.open(CONFIG, 'w') do |file|
        file.puts "url:#{@options[:url]}"
        file.puts "username:#{content["username"]}"
        file.puts "email:#{content["email"]}"
        file.puts "token:#{content["api_key"]}"
      end
      puts "created #{CONFIG}"
    end

    def whoami
      resp = `curl -s #{@options[:url]}/api/v1/me?t=#{@options[:token]}`
      output(resp)
    end

    def projects
      resp = `curl -s #{@options[:url]}/api/v1/me/projects?t=#{@options[:token]}`
      output(resp)
    end
    
    def entries
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

    def commit
      resp = `curl -s '#{@options[:url]}/api/v1/#{@options[:handle]}/projects/#{@options[:code]}/entries?t=#{@options[:token]}' -d "entry[time]=#{@options[:time]}&entry[note]=#{@options[:note]}#{maybe(:date)}"`
      output(resp)
    end

    def edit
      resp = `curl -s -X PUT #{@options[:url]}/api/v1/me/entries/#{@options[:id]}?t=#{@options[:token]} -d "#{maybe(:time, :date, :note)}"`
      output(resp)
    end

    def maybe(*keys)
      args = keys.map do |k|
        @options[k] ? "entry[#{k}]=#{@options[k]}" : ""
      end

      args.reject(&:empty?).join('&')
    end

    def convert(time)
      hours = time[/(\d+)h/, 1].to_i
      minutes = time[/(\d+)m/, 1].to_i
      (hours > 0 ? 60 * hours : hours) + minutes
    end

    def output(resp)
      content = JSON.parse(resp)
      if content.is_a? Hash and content['error']
        pp content['error']
      else
        pp content
      end
    end
  end
end

RallyClock::CLI.process!(ARGV)
