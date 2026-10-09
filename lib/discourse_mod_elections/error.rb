# frozen_string_literal: true

module DiscourseModElections
  # A rule said no. `reason` keys the message under mod_elections.errors;
  # `details` fills it in.
  class Error < StandardError
    attr_reader :reason, :details

    def initialize(reason, **details)
      @reason = reason
      @details = details
      super(reason.to_s)
    end
  end
end
