# frozen_string_literal: true

# Admin dashboard problem check: shows the last Telegram delivery failure from
# the past 24 hours with a hint keyed on Telegram's error text.
class ProblemCheck::DisteleplusTelegram < ProblemCheck
  self.priority = "low"

  def call
    return no_problem unless SiteSetting.disteleplus_enabled

    error = DiscourseDisteleplus::Health.last_error
    return no_problem if error.nil?

    # override_data is what core interpolates into the message; details only
    # travel with the notice.
    data = {
      description: CGI.escapeHTML(error["description"].to_s),
      hint:
        I18n.t(
          "disteleplus.telegram_error_hints.#{DiscourseDisteleplus::Health.error_key_for(error["description"])}",
        ),
      at: error["at"],
    }
    problem(
      override_key: "dashboard.problem.disteleplus_telegram",
      override_data: data,
      details: data,
    )
  end
end
