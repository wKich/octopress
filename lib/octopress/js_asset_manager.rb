$:.unshift File.expand_path(File.dirname(__FILE__)) # For use/testing when no gem is installed
require 'digest/md5'
require 'stitch-rb'
require 'uglifier'
require 'coffee-script'

module Octopress
  class JSAssetsManager

    attr_reader :config

    def initialize
      @js_assets_path = File.expand_path("../../javascripts", File.dirname(__FILE__))

      if Dir.exists? @js_assets_path
        unless Octopress.configuration.has_key? :js_lib
          abort "No :js_lib key in configuration. Cannot proceed.".red
        end

        # Read js dependencies from require_js.yml configuration
        @lib = Octopress.configuration[:js_lib].collect {|item| Dir.glob("#{@js_assets_path}/#{item}") }.flatten.uniq
        @modules = "#{@js_assets_path}/modules"
        @module_files = Dir[@modules+'/**/*']

        @template_path = File.expand_path("../../#{Octopress.configuration[:source]}", File.dirname(__FILE__))
        @build_path = "/javascripts/build"
      else
        @js_assets_path = false
      end
    end


    def get_fingerprint
      Digest::MD5.hexdigest(@module_files.concat(@lib).uniq.map! do |path|
        "#{File.mtime(path).to_i}"
      end.join)
    end

    def url
      if @js_assets_path
        Octopress.env == 'production' ?  "#{@build_path}/all-#{@fingerprint || get_fingerprint}.js" : "#{@build_path}/all.js"
      else
        false
      end
    end

    def compile
      if @js_assets_path
        @fingerprint = get_fingerprint

        filename = url
        file = "#{@template_path + filename}"

        if File.size?(file) && File.open(file) {|f| f.readline} =~ /#{@fingerprint}/
          false
        else
          js = Stitch::Package.new(:dependencies => @lib, :paths => @modules).compile
          js = "/* Octopress fingerprint: #{@fingerprint} */\n" + js
          js = Uglifier.new.compile js if Octopress.env == 'production'
          write_path = "#{@template_path}/#{@build_path}"

          (Dir["#{write_path}/*"]).each { |f| FileUtils.rm_rf(f) }
          FileUtils.mkdir_p write_path
          File.open(file, 'w') { |f| f.write js }

          "Javascripts compiled to #{filename}."
        end
      else
        false
      end
    rescue Exception => e
      Octopress.logger.fatal "Error reading file #{url}".red
      raise e
    end
  end
end

