# frozen_string_literal: true

class ProblemCheck::TranslationOverrides < ProblemCheck
  self.priority = "low"

  def call
    if !TranslationOverride.exists?(status: %i[outdated invalid_interpolation_keys])
      return no_problem
    end

    problem
  end

  private

  def translation_key
    "dashboard.outdated_translations_warning"
  end
end
