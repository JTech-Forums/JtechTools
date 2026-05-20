# frozen_string_literal: true

module ::DiscourseDumbcourse
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseDumbcourse
  end
end
