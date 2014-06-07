module Jdoc
  class Link
    # @param link [JsonSchema::Schema::Link]
    def initialize(link: nil)
      @raw_link = link
    end

    # @return [String] method + path
    # @example
    #   link.endpoint #=> "GET /apps"
    def endpoint
      "#{method} #{path}"
    end

    # Responds to .sort method
    # @return [Fixnum]
    def <=>(schema)
      sort_key <=> schema.sort_key
    end

    # For #<=> method
    # @return [String]
    def sort_key
      "#{path} #{method_order_score}"
    end

    # @return [String] Description for this endpoint, defined in description property
    # @example
    #   link.description #=> "List existing apps."
    def description
      @raw_link.description
    end

    # @return [String] Href anchor for putting link in ToC
    # @example
    #   link.anchor #=> "#get-apps"
    def anchor
      "#" + endpoint.gsub(" ", "-").gsub(/[:\/]/, "").downcase
    end

    # @return [String] Markdown styled link text for endpoint
    # @example
    #   link.link_to_endpoint #=> "[GET /apps](#get-apps)"
    def link_to_endpoint
      "[#{endpoint}](#{anchor})"
    end

    # @return [String] Upper cased HTTP request method name
    # @example
    #   link.method #=> "GET"
    def method
      @method ||= @raw_link.method.to_s.upcase
    end

    # @return [String] Request path name, defined at href property
    # @note URI Template is replaced with placeholder
    # @example
    #   link.path #=> "GET /apps/:id"
    def path
      @path ||= @raw_link.href.gsub(/{(.+)}/) do |matched|
        ":" + CGI.unescape($1).gsub(/[()]/, "").split("/").last
      end
    end

    # @return [String, nil] Example request body in JSON format
    def request_body
      MultiJson.encode(RequestBodyGenerator.call(schema), pretty: true) + "\n"
    end

    def has_request_body?
      ["PATCH", "POST", "PUT"].include?(method)
    end

    private

    # @return [JsonSchema::Schema] Schema for this link, specified by targetSchema or parent schema
    def schema
      @raw_link.target_schema || @raw_link.parent
    end

    # @return [Fixnum] Order score, used to sort links by preferred method order
    def method_order_score
      case method
      when "GET"
        1
      when "POST"
        2
      when "PUT"
        3
      when "PATCH"
        4
      when "DELETE"
        5
      else
        6
      end
    end

    class RequestBodyGenerator
      # Generates example request body from given schema
      # @note Not includes properties that have readOnly property
      # @return [Hash]
      # @example
      #   Jdoc::Link::RequestBodyGenerator(schema) #=> { "name" => "example", "description" => "foo bar." }
      def self.call(schema)
        schema.properties.inject({}) do |result, (key, value)|
          if value.data["readOnly"]
            result
          else
            result.merge(
              key => case
              when !value.properties.empty?
                call(value)
              when !value.data["example"].nil?
                value.data["example"]
              when value.type.include?("null")
                nil
              else
                raise ExampleNotFound, "No example found for #{schema.pointer}/#{key}"
              end
            )
          end
        end
      end
    end
  end
end
