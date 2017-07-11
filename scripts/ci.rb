
require 'yaml'
require 'twitter-text'
TwitterExtractor = Twitter::Extractor
require 'twitter'

module Tweetcode
  class Travis
    def set_env_from_config
      cfg = YAML::load(File.read('.travis.yml'))
      cfg['env']['global'].each do |e|
        var, val = e.split('=')
        ENV[var] = val
      end
    end

    def pr?
      ENV['TRAVIS_PULL_REQUEST'] != 'false'
    end

    def branch
      (pr? ? ENV['TRAVIS_PULL_REQUEST_BRANCH'] : ENV['TRAVIS_BRANCH']) || 'HEAD'
    end

    def ci?
      ENV['CI']
    end

    def event_type?(*type)
      type.include? ENV['TRAVIS_EVENT_TYPE']
    end
  end

  class CI < Travis
    def initialize
      @mode = case
              when event_type?('push', 'pull_request') && branch != 'master'
                :test
              when ci? && branch == 'master'
                :tweet
              else
                :preview
              end
      @errors = []
    end


    def start
      begin
        send(@mode)
      rescue => e
        print_errors
        puts e.to_s
        puts e.backtrace
        fatal "FAIL"
      end
    end

    private

    def error(e)
      @errors << e
      nil
    end

    def fatal(e)
      error(e)
      print_errors
      exit(1)
    end

    def print_errors
      puts @errors
    end

    def commits_cnt
      @commits_cnt ||= run("git rev-list --count '#{commit_id}' '^master'").to_i
    end

    def commit_id
      @cid ||= run("git rev-list --no-merges -n 1 HEAD").strip
    end

    def short_commit_id
      run("git rev-parse --short=4 #{commit_id}").strip
    end

    def commit_msg
      @raw_msg ||= run("git log --format=%B -n 1 #{commit_id}")
    end

    def file
      @file ||= lambda do
        gshow = run("git show --name-only #{commit_id}").lines.reverse
        files = gshow[0..gshow.index{|l| l.match(/^\s*/)}].map(&:strip)
        verbose("Files in commit:\n#{files}\n")

        if files.length != 1
          fatal 'Commit must add only 1 new file'
        elsif !files[0].start_with?('snippets/') || !files[0].end_with?(ENV['SNIPPET_FILE_EXTENSION'] || "")
          error "Snippet file must be in 'snippets' directory and have *.#{ENV['SNIPPET_FILE_EXTENSION']||'*'} extension"
        end

        if File.read(files[0]).lines.length > (ENV['SNIPPET_MAX_LINES'].to_i || 20)
          error "Snippet can't have more than #{ENV['SNIPPET_MAX_LINES'] || 20} lines"
        end
        files[0]
      end.call
    end

    def parsed_msg
      begin
        @parsed_msg ||= YAML::load(commit_msg)
        if @parsed_msg['note'].nil? || @parsed_msg['twitter_username'].nil?
          fatal '"note" and "twitter_username" are required fields in commit message'
        end
        @parsed_msg
      rescue
        fatal("Failed to parse commit message (it must be a valid YAML, see .gitmessage reference and README)")
      end
    end

    def twitter_username
      @twitter_username ||= parsed_msg['twitter_username'].tr('@', '')
    end

    def note
      parsed_msg['note']
    end

    def source
      parsed_msg['source']
    end

    def tweet_text
      @tweet_text ||= begin
        m = [note, source ? "Source: #{source}\n" : nil,  "[#{short_commit_id}] by @#{twitter_username}"].compact.join("\n")
        urls = TwitterExtractor.extract_urls(m)
        if (urls.length > 0 ? m.length - urls.map(&:length).reduce{|a,b| a+b} + urls.length * 23 : m.length) > 140
          urls.each { |u| m.replace(u, "X" * 23) }
          error "Generated tweet has more than 140 characters (URLs replaced by 23 'X' characters): \n#{m}"
        end
        verbose("Generated tweet text:\n#{m}")
        m
      rescue => e
        fatal("FATAL ERROR: #{e.inspect}")
      end
    end

    def validate_snippet
      if cmd = (ENV['VALIDATE_SNIPPET_COMMAND'].tr('"', '').tr("'", '') rescue false)
        ENV['SNIPPET_FILE'] = file
        if !system(cmd)
          error "Snippet validation command failed:\n"
        end
      end
    end

    def make_png
      font = ENV['SNIPPET_FONT_NAME'].tr("'", '').tr('"', '') rescue 'Source Code Pro'
      font_size = ENV['SNIPPET_FONT_SIZE'] || 19
      color_scheme = ENV['SNIPPET_COLOR_SCHEME'].tr("'", '').tr('"', '') rescue 'Tomorrow-Night'
      run("#{File.join(run("npm bin").strip, 'copper')} -f='#{font}' --fontSize=#{font_size} -t=#{color_scheme} #{file}").split.last
    end

    def tweet
      png_path = make_png
      unless File.file?(png_path)
        puts("Failed to generate image:")
        puts png_path
        exit(1)
      end
      t = Twitter::REST::Client.new do |config|
        config.consumer_key        = ENV["TWITTER_CONSUMER_KEY"]
        config.consumer_secret     = ENV["TWITTER_CONSUMER_SECRET"]
        config.access_token        = ENV["TWITTER_ACCESS_TOKEN"]
        config.access_token_secret = ENV["TWITTER_ACCESS_SECRET"]
      end
      begin
        t.update_with_media(tweet_text, File.open(png_path, 'r'))
        puts("Tweet has been successfully published")
      rescue => e
        puts "Failed to publish tweet:"
        puts e.to_s
        exit(1)
      ensure
        run("rm -f #{png_path}")
      end
      exit(0)
    end

    def test
      verbose("Commits in branch: #{commits_cnt}")
      if commits_cnt != 1
        puts 'Branch must have single commit. See contribution flow'
        exit(1)
      end
      tweet_text
      validate_snippet
      if @errors.any?
        fatal("BUILD FAILED")
      end
    end

    def preview
      verbose("Commits in branch: #{commits_cnt}")
      if commits_cnt != 1
        puts 'Branch must have single commit. See contribution flow'
        exit(1)
      end
      set_env_from_config
      png_path = make_png
      run "mv #{png_path} preview.png"
      puts "Tweet text:\n\n#{tweet_text}"
      validate_snippet
      puts "\nImage: preview.png"
    end

    VERBOSE = ENV['VERBOSE'] && !['0', 'false', 'FALSE'].include?(ENV['VERBOSE'])

    # verbose prints msg if VERBOSE env var was set
    def verbose(msg)
      if VERBOSE
        puts "#{msg}"
      end
    end

    def run(cmd)
      verbose "Running `#{cmd}`"
      output = `#{cmd.strip}`
      verbose "Output:\n#{output}\n"
      output
    end
  end
end

def ci
  tc = Tweetcode::CI.new
  tc.start
end

ci()
